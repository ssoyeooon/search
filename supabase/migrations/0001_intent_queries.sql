-- 검색어 의도 분류 DB 조회용 스키마
--
-- 한 행 = (월, 질의어, 대분류, 세부의도). 원본 4,061,558행을 질의어 단위로 접은 것.
-- 월을 행에 남겨두면 SQL에서 기간 필터(WHERE month)와 질의어 단위 조회(GROUP BY query)가
-- 둘 다 나온다. 적재는 dashboard/queries/intent_queries.csv (build_dashboard_data.py 산출).
--
-- 보안: 이 테이블에는 사용자 검색어 원문이 들어 있다. 대시보드 저장소는 PUBLIC이고
-- GitHub Pages로 서빙되므로, 원문은 저장소에 두지 않고 여기(인증 뒤)에만 둔다.
-- RLS로 authenticated SELECT만 허용하고, INSERT/UPDATE/DELETE 정책은 만들지 않는다
-- (= 적재는 service_role 로만 가능).

create extension if not exists pg_trgm;

create table if not exists public.intent_queries (
  id          bigint generated always as identity primary key,
  month       text     not null,          -- 'YYYY-MM'
  query       text     not null,
  main_intent text     not null,
  sub_intent  text     not null,
  n           integer  not null,          -- 그 달의 검색 건수
  first_seen  date     not null,
  last_seen   date     not null,
  -- 기기별 건수. '대표 기기'를 미리 굳히지 않는 이유: 여러 달을 합치면 답이 달라진다
  -- (1월 PC 우세 + 2월 모바일 우세). 대표 기기는 조회 시점에 SUM 후 결정한다.
  dev_pc      integer  not null default 0,
  dev_mobile  integer  not null default 0,
  dev_tablet  integer  not null default 0,
  dev_bot     integer  not null default 0,
  dev_unknown integer  not null default 0,
  unique (month, query, main_intent, sub_intent)
);

create index if not exists idx_iq_month on public.intent_queries (month);
create index if not exists idx_iq_main  on public.intent_queries (main_intent);
create index if not exists idx_iq_sub   on public.intent_queries (sub_intent);
create index if not exists idx_iq_n     on public.intent_queries (n desc);
-- ILIKE '%검색어%' 는 앞이 열려 있어 B-tree 를 못 쓴다. trigram GIN 이 있어야
-- 62만 행에서 부분 일치 검색이 실용 속도로 돈다.
create index if not exists idx_iq_query_trgm
  on public.intent_queries using gin (query gin_trgm_ops);

alter table public.intent_queries enable row level security;

drop policy if exists "authenticated can read intent_queries" on public.intent_queries;
create policy "authenticated can read intent_queries"
  on public.intent_queries for select to authenticated using (true);


-- 조회 RPC.
--
-- PostgREST 로는 GROUP BY 를 못 하는데, 질의어 단위 조회는 기간 내 여러 달을 합쳐야 하므로
-- 필터 -> 집계 -> 정렬 -> 페이징을 전부 서버에서 끝낸다. total_count 를 같이 돌려주므로
-- 페이저가 별도 count 쿼리를 안 쳐도 된다.
--
-- security invoker = 호출자 권한으로 실행 -> 위 RLS 가 그대로 적용된다(비로그인은 0행).
create or replace function public.search_intent_queries(
  p_month_from text    default null,
  p_month_to   text    default null,
  p_search     text    default null,
  p_main       text    default null,
  p_sub        text    default null,
  p_sort       text    default 'n',
  p_desc       boolean default true,
  p_limit      integer default 50,
  p_offset     integer default 0
)
returns table (
  query       text,
  main_intent text,
  sub_intent  text,
  n           bigint,
  first_seen  date,
  last_seen   date,
  dev_pc      bigint,
  dev_mobile  bigint,
  dev_tablet  bigint,
  dev_bot     bigint,
  dev_unknown bigint,
  total_count bigint
)
language sql
stable
security invoker
set search_path = public
as $$
  with f as (
    select *
      from public.intent_queries q
     where (p_month_from is null or q.month >= p_month_from)
       and (p_month_to   is null or q.month <= p_month_to)
       and (p_main       is null or q.main_intent = p_main)
       and (p_sub        is null or q.sub_intent  = p_sub)
       and (p_search     is null or p_search = ''
            or q.query ilike '%' || replace(replace(p_search, '%', '\%'), '_', '\_') || '%')
  ),
  g as (
    select f.query,
           f.main_intent,
           f.sub_intent,
           sum(f.n)::bigint           as n,
           min(f.first_seen)          as first_seen,
           max(f.last_seen)           as last_seen,
           sum(f.dev_pc)::bigint      as dev_pc,
           sum(f.dev_mobile)::bigint  as dev_mobile,
           sum(f.dev_tablet)::bigint  as dev_tablet,
           sum(f.dev_bot)::bigint     as dev_bot,
           sum(f.dev_unknown)::bigint as dev_unknown
      from f
     group by f.query, f.main_intent, f.sub_intent
  )
  select g.*, count(*) over()::bigint as total_count
    from g
   order by
     case when p_sort = 'n'     and     p_desc then g.n          end desc nulls last,
     case when p_sort = 'n'     and not p_desc then g.n          end asc  nulls last,
     case when p_sort = 'query' and     p_desc then g.query      end desc,
     case when p_sort = 'query' and not p_desc then g.query      end asc,
     case when p_sort = 'last'  and     p_desc then g.last_seen  end desc,
     case when p_sort = 'last'  and not p_desc then g.last_seen  end asc,
     g.n desc, g.query asc          -- 동점 시 순서 고정(페이징 중복/누락 방지)
   limit  greatest(1, least(coalesce(p_limit, 50), 500))
  offset greatest(0, coalesce(p_offset, 0));
$$;

revoke all on function public.search_intent_queries from public, anon;
grant execute on function public.search_intent_queries to authenticated;


-- 필터 드롭다운 채우기 + 적재 여부 확인용. 라벨/건수만 나가고 질의어 원문은 안 나간다.
create or replace function public.intent_queries_facets()
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'months', (select coalesce(jsonb_agg(m order by m), '[]'::jsonb)
                 from (select distinct month as m from public.intent_queries) t),
    'mains',  (select coalesce(jsonb_agg(x order by x), '[]'::jsonb)
                 from (select distinct main_intent as x from public.intent_queries) t),
    'subs',   (select coalesce(jsonb_agg(jsonb_build_array(sub_intent, main_intent)
                                         order by sub_intent), '[]'::jsonb)
                 from (select distinct sub_intent, main_intent from public.intent_queries) t),
    'rows',   (select count(*) from public.intent_queries),
    'total',  (select coalesce(sum(n), 0) from public.intent_queries)
  );
$$;

revoke all on function public.intent_queries_facets from public, anon;
grant execute on function public.intent_queries_facets to authenticated;
