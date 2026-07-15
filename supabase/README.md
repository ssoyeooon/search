# 데이터 조회 (Supabase) 설정

'데이터 조회' 메뉴는 검색어 원문을 다루므로 **사내 로그인 뒤**에서만 동작한다.
이 저장소는 PUBLIC 이고 GitHub Pages 로 서빙되므로, 질의어 원문은 저장소에 두지 않고
Supabase 에만 둔다. 설정 전에는 조회 메뉴가 '설정 필요' 안내만 띄우고, 대시보드의
나머지 기능은 그대로 동작한다.

## 왜 이 구조인가

- `dashboard-data.json` (공개) — 집계 숫자만. 검색어 원문 없음. 지금까지와 동일.
- `intent_queries` (Supabase, 인증 뒤) — 질의어 원문. 62만 행.
- `anon` 키는 저장소에 있어도 된다. 브라우저로 나가라고 만든 공개 키이고,
  실제 통제는 Postgres RLS 가 한다. 비로그인 상태로는 0행이 나온다.
- **`service_role` 키는 저장소·브라우저 어디에도 두지 않는다.** RLS 를 통째로 우회한다.
  적재는 로컬에서만 한다.

---

## 1. 프로젝트 생성

1. https://supabase.com/dashboard → **New project**
2. 이름 `intent-search`, 리전 **Northeast Asia (Seoul)** 권장
3. DB 비밀번호는 안전한 곳에 보관 (3단계 적재에 쓴다)

무료 티어 500MB 안에 들어간다 (62만 행 + 인덱스 ≈ 70~110MB).

## 2. 스키마 생성

Supabase 대시보드 → **SQL Editor** → `migrations/0001_intent_queries.sql` 내용을
통째로 붙여넣고 실행.

테이블 + trigram 인덱스 + RLS + 조회 RPC 두 개가 만들어진다.

## 3. 데이터 적재

먼저 CSV 를 만든다 (원본 전량 재분류 — 몇 분 걸린다):

```
대시보드_재생성.bat
```

→ `dashboard/queries/intent_queries.csv` 생성 (검색어 원문 포함, `.gitignore` 로 커밋 차단됨)

Supabase 대시보드의 CSV Import 는 62만 행에서 느리고 잘 끊긴다. `psql` 로 넣는다.
연결 문자열은 Project Settings → Database → Connection string → URI 에서 복사.

```bash
psql "postgresql://postgres.[ref]:[비밀번호]@aws-0-ap-northeast-2.pooler.supabase.com:5432/postgres" \
  -c "\copy public.intent_queries (month, query, main_intent, sub_intent, n, first_seen, last_seen, dev_pc, dev_mobile, dev_tablet, dev_bot, dev_unknown) FROM 'queries/intent_queries.csv' WITH (FORMAT csv, HEADER true)"
```

> 비밀번호를 셸 히스토리에 남기지 않으려면 `PGPASSWORD` 환경변수를 쓰거나
> `~/.pgpass` 를 사용할 것.

재적재(사전이 바뀌어 재분류한 경우)는 비우고 다시 넣는다:

```sql
truncate public.intent_queries;
```

## 4. 계정 만들기

Supabase 대시보드 → **Authentication** → **Users** → **Add user**

- 이메일: `사번@megastudyedu.com` (예: `20220532@megastudyedu.com`)
- 비밀번호 지정, **Auto Confirm User** 체크

로그인 화면에는 사번만 입력한다. `supabase-config.js` 의 `emailDomain` 이 이메일로 바꿔준다.
가입 화면은 없다 — 계정은 여기서만 만든다.

## 5. 대시보드에 연결

Project Settings → **API** 에서 두 값을 복사해 `dashboard/supabase-config.js` 에 넣는다:

```js
window.SUPABASE_CONFIG = {
  url: "https://[ref].supabase.co",
  anonKey: "eyJhbGciOi...",          // anon public (service_role 아님!)
  emailDomain: "megastudyedu.com",
};
```

커밋하고 배포하면 끝. `?report=1` 보고용 모드에서는 조회 메뉴가 숨겨진다.

## 확인

- 로그아웃 상태에서 조회 → 로그인 화면이 떠야 한다
- 브라우저 콘솔에서 anon 키로 직접 긁어봐도 0행이어야 한다 (RLS 동작 확인):
  ```js
  const c = window.supabase.createClient(SUPABASE_CONFIG.url, SUPABASE_CONFIG.anonKey);
  await c.from("intent_queries").select("*").limit(5);   // -> data: []
  ```
