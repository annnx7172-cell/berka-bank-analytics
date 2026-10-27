/* 02_clean.sas: build the STG layer from RAW */
%include "%sysget(HOME)/BERKA/code/00_setup.sas";

%let refdate = '31DEC1998'd;   /* end of the data: ages are as of this date */
options fmtsearch=(stg work);

/* ---------- English labels ---------- */
proc format library=stg;
  value $freq
    'POPLATEK MESICNE'    = 'Monthly issuance'
    'POPLATEK TYDNE'      = 'Weekly issuance'
    'POPLATEK PO OBRATU'  = 'Issuance after transaction'
    other = 'Unmapped';
  value $ttype
    'PRIJEM' = 'Credit'
    'VYDAJ'  = 'Withdrawal'
    'VYBER'  = 'Withdrawal (cash)'
    other = 'Unmapped';
  value $toper
    'VYBER KARTOU'    = 'Credit card withdrawal'
    'VKLAD'           = 'Credit in cash'
    'PREVOD Z UCTU'   = 'Collection from another bank'
    'VYBER'           = 'Withdrawal in cash'
    'PREVOD NA UCET'  = 'Remittance to another bank'
    ' '               = 'Not recorded'
    other = 'Unmapped';
  value $ksym
    'POJISTNE'   = 'Insurance payment'
    'SLUZBY'     = 'Payment for statement'
    'UROK'       = 'Interest credited'
    'SANKC. UROK'= 'Sanction interest'
    'SIPO'       = 'Household'
    'DUCHOD'     = 'Old-age pension'
    'UVER'       = 'Loan payment'
    'LEASING'    = 'Leasing'
    ' '          = 'None'
    other = 'Unmapped';
  value $lstat
    'A' = 'Finished, paid'
    'B' = 'Finished, not paid'
    'C' = 'Running, OK'
    'D' = 'Running, in debt'
    other = 'Unmapped';
  value $dtype
    'OWNER'     = 'Owner'
    'DISPONENT' = 'Disponent'
    other = 'Unmapped';
run;

/* ---------- account ---------- */
data stg.account;
  set raw.account(rename=(date=date_c));
  account_date = input(date_c, yymmdd6.);
  frequency_en = put(frequency, $freq.);
  format account_date date9.;
  drop date_c;
run;

/* ---------- client: gender + age from birth_number ---------- */
data stg.client;
  set raw.client;
  yy = input(substr(birth_number,1,2), 2.);
  mm = input(substr(birth_number,3,2), 2.);
  dd = input(substr(birth_number,5,2), 2.);
  gender = ifc(mm > 12, 'F', 'M');         /* women have 50 added to the month */
  if mm > 12 then mm = mm - 50;
  birth_date = mdy(mm, dd, 1900 + yy);
  age = floor(yrdif(birth_date, &refdate, 'AGE'));
  format birth_date date9.;
  drop yy mm dd;
run;

/* ---------- disp ---------- */
data stg.disp;
  set raw.disp;
  disp_type_en = put(type, $dtype.);
run;

/* ---------- card ---------- */
data stg.card;
  set raw.card;
  issued_date = input(substr(issued,1,6), yymmdd6.);
  format issued_date date9.;
  drop issued;
run;

/* ---------- district: descriptive names; '?' becomes missing ---------- */
data stg.district;
  set raw.district;
  district_id          = A1;
  district_name        = A2;
  region               = A3;
  population           = A4;
  n_towns_lt_500       = A5;
  n_towns_500_1999     = A6;
  n_towns_2000_9999    = A7;
  n_towns_gt_10000     = A8;
  n_cities             = A9;
  pct_urban            = A10;
  avg_salary           = A11;
  unemployment_95      = input(A12, ?? 8.);
  unemployment_96      = A13;
  entrepreneurs_per_1k = A14;
  crimes_95            = input(A15, ?? 8.);
  crimes_96            = A16;
  keep district_id district_name region population n_towns_lt_500
       n_towns_500_1999 n_towns_2000_9999 n_towns_gt_10000 n_cities
       pct_urban avg_salary unemployment_95 unemployment_96
       entrepreneurs_per_1k crimes_95 crimes_96;
run;

/* ---------- loan ---------- */
data stg.loan;
  set raw.loan(rename=(date=date_c));
  loan_date = input(date_c, yymmdd6.);
  status_en = put(status, $lstat.);
  is_default = (status in ('B','D'));
  format loan_date date9.;
  drop date_c;
run;

/* ---------- order ---------- */
data stg.order;
  set raw.order;
  k_symbol_en = put(k_symbol, $ksym.);
run;

/* ---------- trans ---------- */
data stg.trans;
  set raw.trans(rename=(date=date_c));
  trans_date    = input(date_c, yymmdd6.);
  type_en       = put(type, $ttype.);
  operation_en  = put(operation, $toper.);
  k_symbol_en   = put(k_symbol, $ksym.);
  signed_amount = ifn(type = 'PRIJEM', amount, -amount);
  format trans_date date9.;
  drop date_c;
run;

/* ---------- checks ---------- */
proc sql;
  title "Row counts (must equal RAW)";
  select memname, nobs from dictionary.tables
  where libname='STG' and memtype='DATA' order by memname;

  title "Dataset date range (confirms the 31DEC1998 reference date)";
  select min(trans_date) as first_trans format=date9.,
         max(trans_date) as last_trans  format=date9. from stg.trans;

  title "Gender split and age range";
  select gender, count(*) as clients, min(age) as min_age, max(age) as max_age
  from stg.client group by gender;

  title "Unmapped label codes (should return no rows)";
  select 'trans type' as field, type as code, count(*) as n from stg.trans where type_en=
  union all
  select 'trans operation', operation, count(*) from stg.trans where operation_en='Unmapp
  union all
  select 'trans k_symbol', k_symbol, count(*) from stg.trans where k_symbol_en='Unmapped'
quit;
title;