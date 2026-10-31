/* 04_summary.sas: summary tables with PROC SQL (joins, GROUP BY, CASE WHEN) */
%include "%sysget(HOME)/BERKA/code/00_setup.sas";

proc sql;

  /* ---------- monthly_summary: one row per month ---------- */
  create table work.agg as
  select intnx('month', trans_date, 0, 'b') as month_start format=date9.,
         count(*)                           as n_transactions,
         count(distinct account_id)         as n_active_accounts,
         sum(case when type = 'PRIJEM' then amount else 0 end) as total_credits,
         sum(case when type ne 'PRIJEM' then amount else 0 end) as total_debits,
         sum(signed_amount)                 as net_flow,
         mean(balance)                      as avg_balance
  from stg.trans
  group by 1;

  /* accounts open at the end of each month */
  create table work.acct_cum as
  select m.month_start, count(a.account_id) as n_accounts_open
  from work.agg m
       left join stg.account a
         on a.account_date <= intnx('month', m.month_start, 0, 'e')
  group by m.month_start;

  create table mart.monthly_summary as
  select a.month_start,
         year(a.month_start)  as calendar_year,
         month(a.month_start) as calendar_month,
         a.n_transactions, a.n_active_accounts, a.total_credits,
         a.total_debits, a.net_flow, a.avg_balance,
         c.n_accounts_open,
         a.n_transactions / c.n_accounts_open as transactions_per_account
  from work.agg a
       inner join work.acct_cum c on a.month_start = c.month_start
  order by a.month_start;

  /* ---------- loan_summary: one row per loan ---------- */
  create table mart.loan_summary as
  select l.loan_id, l.account_id, l.loan_date format=date9.,
         l.amount, l.duration, l.payments, l.status, l.status_en,
         case when l.status in ('B', 'D') then 1 else 0 end as default_flag,
         c.gender,
         floor(yrdif(c.birth_date, l.loan_date, 'AGE')) as age_at_loan,
         case when calculated age_at_loan < 30 then 'Under 30'
              when calculated age_at_loan < 45 then '30-44'
              when calculated age_at_loan < 60 then '45-59'
              else '60+' end as age_band,
         d.district_id, d.district_name, d.region
  from stg.loan l
       inner join stg.account a  on l.account_id = a.account_id
       inner join stg.disp dp    on l.account_id = dp.account_id and dp.type = 'OWNER'
       inner join stg.client c   on dp.client_id = c.client_id
       inner join stg.district d on a.district_id = d.district_id;

  /* ---------- district_summary: one row per district ---------- */
  create table mart.district_summary as
  select d.district_id, d.district_name, d.region, d.population,
         d.avg_salary, d.unemployment_96,
         coalesce(a.n_accounts, 0) as n_accounts,
         coalesce(l.n_loans, 0)    as n_loans,
         coalesce(l.n_defaults, 0) as n_defaults,
         case when coalesce(l.n_loans, 0) > 0
              then l.n_defaults / l.n_loans else . end as default_rate format=percent8.1,
         l.avg_loan_amount
  from stg.district d
       left join (select district_id, count(*) as n_accounts
                  from stg.account group by district_id) a
         on d.district_id = a.district_id
       left join (select district_id, count(*) as n_loans,
                         sum(default_flag) as n_defaults,
                         mean(amount) as avg_loan_amount
                  from mart.loan_summary group by district_id) l
         on d.district_id = l.district_id;

  /* ---------- checks ---------- */
  title "Row counts of the summary tables";
  select 'monthly_summary' as table_name, count(*) as n_rows from mart.monthly_summary
  union all
  select 'loan_summary',     count(*) from mart.loan_summary
  union all
  select 'district_summary', count(*) from mart.district_summary;

  title "Totals must reconcile: loans 682, defaults 76, accounts 4500";
  select sum(n_loans) as loans, sum(n_defaults) as defaults, sum(n_accounts) as accounts
  from mart.district_summary;

  title "Default rate by region";
  select region, sum(n_loans) as loans, sum(n_defaults) as defaults,
         sum(n_defaults) / sum(n_loans) as default_rate format=percent8.1
  from mart.district_summary
  group by region
  order by default_rate desc;

  title "First 6 months of monthly_summary";
  select * from mart.monthly_summary(obs=6);

quit;
title;