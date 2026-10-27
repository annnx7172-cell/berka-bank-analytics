%include "%sysget(HOME)/BERKA/code/00_setup.sas";
options fmtsearch=(stg work);

/* ============ 1. account_month: account x month ============ */
data work.t;
  set stg.trans(keep=account_id trans_id trans_date type amount balance signed_amount);
  month_start = intnx('month', trans_date, 0, 'b');
  format month_start date9.;
run;

proc sort data=work.t; by account_id trans_date trans_id; run;

data mart.account_month(keep=account_id month_start n_trans credits debits
                              net_flow end_balance min_balance n_negative);
  set work.t;
  by account_id month_start;
  retain n_trans credits debits net_flow min_balance n_negative;
  if first.month_start then do;
    n_trans = 0; credits = 0; debits = 0; net_flow = 0;
    min_balance = balance; n_negative = 0;
  end;
  n_trans + 1;
  if type = 'PRIJEM' then credits + amount; else debits + amount;
  net_flow + signed_amount;
  min_balance = min(min_balance, balance);
  if balance < 0 then n_negative + 1;
  if last.month_start then do;
    end_balance = balance;     /* balance after the month's last transaction */
    output;
  end;
  format month_start date9.;
run;

/* ============ 2. bank_month: one row per month ============ */
data work.months;
  do i = 0 to 71;
    month_start = intnx('month', '01JAN1993'd, i, 'b');
    output;
  end;
  format month_start date9.;
  drop i;
run;

proc sql;
  create table work.agg as
  select month_start,
         count(distinct account_id) as n_active_accounts,
         sum(n_trans)  as n_trans,
         sum(credits)  as total_credits,
         sum(debits)   as total_debits,
         sum(net_flow) as net_flow,
         mean(end_balance) as avg_end_balance
  from mart.account_month
  group by month_start;

  create table work.opened as
  select intnx('month', account_date, 0, 'b') as month_start format=date9.,
         count(*) as n_opened
  from stg.account
  group by 1;

  create table work.bm as
  select m.month_start,
         coalesce(a.n_active_accounts, 0) as n_active_accounts,
         coalesce(a.n_trans, 0)        as n_trans,
         coalesce(a.total_credits, 0)  as total_credits,
         coalesce(a.total_debits, 0)   as total_debits,
         coalesce(a.net_flow, 0)       as net_flow,
         a.avg_end_balance,
         coalesce(o.n_opened, 0)       as n_opened
  from work.months m
       left join work.agg a    on m.month_start = a.month_start
       left join work.opened o on m.month_start = o.month_start
  order by m.month_start;
quit;

data mart.bank_month;
  set work.bm;
  n_accounts_open + n_opened;       /* running count of accounts opened */
  avg_credits_per_account = total_credits / n_accounts_open;
  avg_debits_per_account  = total_debits  / n_accounts_open;
  avg_net_per_account     = net_flow      / n_accounts_open;
  avg_trans_per_account   = n_trans       / n_accounts_open;
  format avg_: comma12.2 total_credits total_debits net_flow comma15.2;
run;

/* ============ 3. loan_base: one row per loan ============ */
proc sql;
  create table work.owner as
  select account_id, min(client_id) as client_id
  from stg.disp where type = 'OWNER' group by account_id;

  /* behaviour strictly BEFORE the loan date */
  create table work.beh as
  select l.loan_id,
         count(t.trans_id) as n_trans_before,
         sum(case when t.type = 'PRIJEM' then t.amount else 0 end) as credits_before,
         sum(case when t.type ne 'PRIJEM' and t.trans_id is not null
                  then t.amount else 0 end) as debits_before,
         mean(t.balance) as avg_balance_before,
         min(t.balance)  as min_balance_before,
         sum(t.balance < 0) as n_negative_before
  from stg.loan l
       left join stg.trans t
         on l.account_id = t.account_id and t.trans_date < l.loan_date
  group by l.loan_id;

  create table mart.loan_base as
  select l.loan_id, l.account_id, l.loan_date, l.amount, l.duration, l.payments,
         l.status, l.status_en, l.is_default,
         a.account_date,
         intck('month', a.account_date, l.loan_date) as months_history,
         c.gender,
         floor(yrdif(c.birth_date, l.loan_date, 'AGE')) as age_at_loan,
         d.district_name, d.region, d.population, d.pct_urban, d.avg_salary,
         d.unemployment_96, d.crimes_96,
         d.crimes_96 / d.population as crime_rate_96,
         l.payments / d.avg_salary as payment_to_salary,
         b.n_trans_before, b.credits_before, b.debits_before,
         b.avg_balance_before, b.min_balance_before, b.n_negative_before,
         b.credits_before / max(calculated months_history, 1) as avg_monthly_credits
  from stg.loan l
       inner join stg.account a on l.account_id = a.account_id
       left join work.owner o   on l.account_id = o.account_id
       left join stg.client c   on o.client_id = c.client_id
       left join stg.district d on a.district_id = d.district_id
       left join work.beh b     on l.loan_id = b.loan_id;
quit;

/* ============ 4. client_profile: one row per client ============ */
proc sql;
  create table work.cl_acc as
  select client_id, count(distinct account_id) as n_accounts,
         max(type = 'OWNER') as is_owner
  from stg.disp group by client_id;

  create table work.cl_card as
  select dp.client_id, count(*) as n_cards
  from stg.card cd inner join stg.disp dp on cd.disp_id = dp.disp_id
  group by dp.client_id;

  create table mart.client_profile as
  select c.client_id, c.gender, c.birth_date, c.age,
         case when c.age < 18 then 'Under 18'
              when c.age < 30 then '18-29'
              when c.age < 45 then '30-44'
              when c.age < 60 then '45-59'
              else '60+' end as age_band,
         (c.age < 18) as is_minor,
         c.district_id, d.district_name, d.region,
         coalesce(a.n_accounts, 0) as n_accounts,
         coalesce(a.is_owner, 0)   as is_owner,
         coalesce(k.n_cards, 0)    as n_cards
  from stg.client c
       left join stg.district d on c.district_id = d.district_id
       left join work.cl_acc a  on c.client_id = a.client_id
       left join work.cl_card k on c.client_id = k.client_id;
quit;

/* ============ checks ============ */
proc sql;
  title "MART row counts";
  select memname, nobs from dictionary.tables
  where libname = 'MART' and memtype = 'DATA' order by memname;
  title "Loan default rate";
  select status, count(*) as loans, mean(is_default) as default_rate format=percent8.1
  from mart.loan_base group by status;
  title "Loan_base: rows with missing features";
  select count(*) as loans,
         nmiss(gender) as no_owner, nmiss(avg_salary) as no_district,
         nmiss(avg_balance_before) as no_history
  from mart.loan_base;
quit;
title "bank_month sample";
proc print data=mart.bank_month(obs=6) noobs; run;
title;