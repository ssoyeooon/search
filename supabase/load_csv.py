# -*- coding: utf-8 -*-
r"""queries/intent_queries.csv 를 Supabase 의 intent_queries 테이블에 적재한다.

psql 이 없어도 되도록 psycopg2 로 COPY FROM STDIN 을 쓴다(= psql 의 \copy 와 같은 경로,
INSERT 보다 훨씬 빠르다). 62만 행에 보통 1~2분.

접속 문자열(안에 DB 비밀번호가 들어 있다)은 아래 순서로 찾는다:

  1. queries/db_url.txt 파일          <- 있으면 이걸 쓴다
  2. SUPABASE_DB_URL 환경변수
  3. 직접 입력받기 (화면에 안 보임)

1번은 이 스크립트를 남이 대신 실행해 줄 때를 위한 것이다. 비밀번호를 채팅이나
명령줄에 노출하지 않고 파일로만 건넨다. queries/ 는 .gitignore 로 막혀 있어
커밋되지 않는다. 적재가 끝나면 이 파일은 지운다(--keep-url 을 주면 남긴다).

이 스크립트는 접속 문자열을 어떤 경우에도 화면에 출력하지 않는다. 연결 실패
메시지에 섞여 나올 수 있으므로 예외 문구에서도 지운다.

실행:
    .venv\Scripts\python.exe dashboard\supabase\load_csv.py

먼저 migrations/0001_intent_queries.sql 을 SQL Editor 에서 실행해 두어야 한다.
"""
import getpass
import os
import re
import sys

import psycopg2

HERE = os.path.dirname(os.path.abspath(__file__))
CSV = os.path.join(os.path.dirname(HERE), "queries", "intent_queries.csv")
URL_FILE = os.path.join(os.path.dirname(HERE), "queries", "db_url.txt")


def scrub(text, dsn):
    """예외 문구 등에서 접속 문자열/비밀번호를 지운다."""
    s = str(text)
    if dsn:
        s = s.replace(dsn, "<접속 문자열>")
        m = re.search(r"://[^:/@]+:([^@]+)@", dsn)
        if m and m.group(1):
            s = s.replace(m.group(1), "<비밀번호>")
    return s


def read_dsn():
    """파일 -> 환경변수 -> 직접 입력 순으로 접속 문자열을 얻는다."""
    if os.path.exists(URL_FILE):
        with open(URL_FILE, encoding="utf-8-sig") as f:
            dsn = f.read().strip()
        if dsn and not dsn.startswith("#"):
            print("접속 문자열: %s 에서 읽음" % os.path.basename(URL_FILE))
            return dsn, True
    env = os.environ.get("SUPABASE_DB_URL")
    if env:
        print("접속 문자열: 환경변수 SUPABASE_DB_URL 에서 읽음")
        return env.strip(), False
    print("Supabase 대시보드 상단 Connect > Session pooler 의 URI 를 붙여넣으세요.")
    print("  [YOUR-PASSWORD] 는 대괄호까지 통째로 실제 비밀번호로 바꿔야 합니다.")
    print("  (입력 내용은 화면에 보이지 않습니다)")
    return getpass.getpass("접속 문자열: ").strip(), False


def check_dsn(dsn):
    if not dsn.startswith("postgres"):
        return "postgresql://... 로 시작해야 합니다."
    if "[" in dsn or "]" in dsn:
        return ("대괄호가 남아 있습니다. [YOUR-PASSWORD] 는 대괄호까지 지우고 "
                "실제 비밀번호만 넣어야 합니다 (:[비밀번호]@ 가 아니라 :비밀번호@).")
    if "YOUR-PASSWORD" in dsn.upper():
        return "비밀번호 자리표시자가 그대로입니다."
    if not re.search(r"://[^:/@]+:[^@]+@", dsn):
        return "비밀번호가 없습니다. postgresql://사용자:비밀번호@호스트... 형태여야 합니다."
    return None

COLS = ("month, query, main_intent, sub_intent, n, first_seen, last_seen, "
        "dev_pc, dev_mobile, dev_tablet, dev_bot, dev_unknown")


def main():
    if not os.path.exists(CSV):
        print("[오류] 적재할 CSV 가 없습니다: %s" % CSV)
        print("       먼저 대시보드_재생성.bat 을 실행하세요.")
        sys.exit(1)

    size_mb = os.path.getsize(CSV) / 1048576
    print("적재할 파일: %s (%.1f MB)" % (CSV, size_mb))
    print()

    dsn, from_file = read_dsn()
    problem = check_dsn(dsn)
    if problem:
        print("[오류] %s" % problem)
        sys.exit(1)

    print("\n연결 중...", flush=True)
    try:
        conn = psycopg2.connect(dsn)
    except Exception as e:
        # 예외 문구에 접속 문자열이 섞여 나올 수 있다 - 지우고 출력한다.
        print("[오류] 연결 실패: %s" % scrub(e, dsn))
        sys.exit(1)

    try:
        with conn, conn.cursor() as cur:
            cur.execute("select count(*) from public.intent_queries")
            before = cur.fetchone()[0]
            if before:
                print("[주의] 이미 %s행이 들어 있습니다." % format(before, ","))
                if input("      비우고 다시 넣을까요? (y/N) ").strip().lower() != "y":
                    print("중단했습니다.")
                    return
                cur.execute("truncate public.intent_queries")
                print("      비웠습니다.")

            print("적재 중... (62만 행, 1~2분 걸립니다)", flush=True)
            with open(CSV, "r", encoding="utf-8", newline="") as f:
                cur.copy_expert(
                    "copy public.intent_queries (%s) from stdin with (format csv, header true)" % COLS,
                    f,
                )
            cur.execute("select count(*), coalesce(sum(n), 0) from public.intent_queries")
            rows, total = cur.fetchone()

        print()
        print("[완료] 행 %s개 · 검색 %s건" % (format(rows, ","), format(total, ",")))
        print("       대시보드_재생성 로그의 숫자와 같아야 합니다.")
    except Exception as e:
        print("[오류] 적재 실패: %s" % scrub(e, dsn))
        sys.exit(1)
    finally:
        conn.close()
        # 파일로 건네받았으면 쓰고 나서 지운다 - 비밀번호를 디스크에 남기지 않는다.
        if from_file and "--keep-url" not in sys.argv and os.path.exists(URL_FILE):
            os.remove(URL_FILE)
            print("       %s 는 삭제했습니다." % os.path.basename(URL_FILE))


if __name__ == "__main__":
    main()
