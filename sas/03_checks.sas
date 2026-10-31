/* 03_checks.sas: five data-quality checks on the cleaned (STG) tables */
%include "%sysget(HOME)/BERKA/code/00_setup.sas";

proc sql;

  /* ---------- Check 1: row counts, RAW vs STG ---------- */
  title "Check 1: row counts, RAW vs STG (rows_equal should be 1)";
  select r.memname as table_name, r.nobs as raw_rows, s.nobs as stg_rows,
         (r.nobs = s.nobs) as rows_equal
  from (select memname, nobs from dictionary.tables
        where libname = 'RAW' and memtype = 'DATA') as r
       inner join
       (select memname, nobs from dictionary.tables
        where libname = 'STG' and memtype = 'DATA') as s
       on r.memname = s.memname
  order by r.memname;

  /* ---------- Check 2: missing values ---------- */
  title "Check 2: missing values in columns that could matter";
  select 'trans.bank' as column_name, sum(missing(bank)) as n_missing, count(*) as n_rows from stg.trans
  union all
  select 'trans.account',  sum(missing(account)),  count(*) from stg.trans
  union all
  select 'trans.k_symbol', sum(missing(k_symbol)), count(*) from stg.trans
  union all
  select 'trans.operation', sum(missing(operation)), count(*) from stg.trans
  union all
  select 'trans.balance',  sum(missing(balance)),  count(*) from stg.trans
  union all
  select 'client.birth_date', sum(missing(birth_date)), count(*) from stg.client
  union all
  select 'district.unemployment_95', sum(missing(unemployment_95)), count(*) from stg.district
  union all
  select 'district.crimes_95', sum(missing(crimes_95)), count(*) from stg.district;

  /* ---------- Check 3: duplicate keys ---------- */
  title "Check 3: duplicate primary keys (should all be 0)";
  select 'account' as table_name, count(*) - count(distinct account_id) as duplicates from stg.account
  union all
  select 'client',   count(*) - count(distinct client_id)   from stg.client
  union all
  select 'disp',     count(*) - count(distinct disp_id)     from stg.disp
  union all
  select 'loan',     count(*) - count(distinct loan_id)     from stg.loan
  union all
  select 'card',     count(*) - count(distinct card_id)     from stg.card
  union all
  select 'order',    count(*) - count(distinct order_id)    from stg.order
  union all
  select 'district', count(*) - count(distinct district_id) from stg.district
  union all
  select 'trans',    count(*) - count(distinct trans_id)    from stg.trans;

  /* ---------- Check 4: orphan keys (child rows with no parent) ---------- */
  title "Check 4: orphan keys (should all be 0)";
  select 'account -> district' as relationship, count(*) as orphans from stg.account
    where district_id not in (select district_id from stg.district)
  union all
  select 'client -> district', count(*) from stg.client
    where district_id not in (select district_id from stg.district)
  union all
  select 'disp -> client', count(*) from stg.disp
    where client_id not in (select client_id from stg.client)
  union all
  select 'disp -> account', count(*) from stg.disp
    where account_id not in (select account_id from stg.account)
  union all
  select 'loan -> account', count(*) from stg.loan
    where account_id not in (select account_id from stg.account)
  union all
  select 'card -> disp', count(*) from stg.card
    where disp_id not in (select disp_id from stg.disp)
  union all
  select 'order -> account', count(*) from stg.order
    where account_id not in (select account_id from stg.account)
  union all
  select 'trans -> account', count(*) from stg.trans
    where account_id not in (select account_id from stg.account);

  /* ---------- Check 5: date ranges (expect 1993-1998) ---------- */
  title "Check 5: date ranges";
  select 'account.account_date' as column_name,
         min(account_date) as first format=date9., max(account_date) as last format=date9.
         from stg.account
  union all
  select 'loan.loan_date', min(loan_date), max(loan_date) from stg.loan
  union all
  select 'card.issued_date', min(issued_date), max(issued_date) from stg.card
  union all
  select 'trans.trans_date', min(trans_date), max(trans_date) from stg.trans
  union all
  select 'client.birth_date', min(birth_date), max(birth_date) from stg.client

quit;
title;