// Supabase 접속 설정 — '데이터 조회' 화면 전용.
//
// anon 키는 저장소에 두어도 되는 키다. 브라우저로 나가라고 설계된 공개 키이고,
// 실제 접근 통제는 Postgres RLS 가 한다(supabase/migrations/0001_intent_queries.sql:
// authenticated 만 SELECT). 비로그인 상태로 이 키를 써도 0행이 나온다.
//
// !! service_role 키는 절대 여기 두지 말 것 — RLS 를 통째로 우회한다.
//    적재는 로컬에서 psql/CLI 로만 한다.
//
// 값이 비어 있으면 조회 메뉴는 '미설정' 안내만 띄우고, 나머지 대시보드는 그대로 동작한다.
window.SUPABASE_CONFIG = {
  url: "https://tyqkzxpxpasgqvyujqsi.supabase.co",
  anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR5cWt6eHB4cGFzZ3F2eXVqcXNpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQwOTM3NTUsImV4cCI6MjA5OTY2OTc1NX0.vLBkWv7q-VbShj6R5YChtq3-I3HTRiWivuyOAwV65XY",

  // 사번 로그인 파사드: 20220532 -> 20220532@megastudyedu.com 로 변환해 로그인한다.
  // 화면에는 사번만 보이고 이메일은 노출하지 않는다.
  emailDomain: "megastudyedu.com",
};
