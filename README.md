# 검색 질의어 분석 대시보드

검색 질의어를 의도(대분류·세부의도)로 분류하고, 주차별로 누적해 보여주는 정적 대시보드입니다.
별도 서버 없이 동작합니다.

## 배포 주소
- GitHub Pages: https://ssoyeooon.github.io/search/
- Vercel: https://dashboard-six-lyart-89.vercel.app/ (GitHub 연동 자동 배포)

## 구성
- `index.html` — 대시보드 본체(검색어 의도 분류 + 자동완성 후보/엔티티 추출). 루트 `/`로 바로 열림
- `styles.css` — 디자인
- `dashboard.js` — 분류 로직 + 사전 데이터(@@DICT@@: `의도분류_사전.xlsx`에서 자동 생성)
- `ui-events.js` — UI 이벤트 바인딩(엔티티 로드 이후 실행)
- `entity-logic.js` — 엔티티 추출 엔진
- `dashboard-data.json` — (선택) 공유 누적 데이터. 없으면 빈 상태로 시작.

## 데이터 공유 방법 (정적 호스팅)
1. 대시보드 > **검색어 의도 분류** 메뉴에서 엑셀/CSV 업로드 → 주차별로 자동 누적
2. 대시보드 우상단 **데이터 내보내기** → `dashboard-data.json` 다운로드
3. 받은 `dashboard-data.json`을 이 저장소(HTML과 같은 위치)에 커밋/푸시
4. 이후 접속자는 모두 같은 누적 결과를 확인

> 참고: 원본 검색 데이터(`*.xlsx`)는 민감 정보이므로 저장소에 올리지 않습니다(`.gitignore`).
