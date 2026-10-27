/* 03_dq.sas: data-quality checks on the STG layer -> DQ_LOG and REJECTS */
%include "%sysget(HOME)/BERKA/code/00_setup.sas";
options fmtsearch=(stg work);

data stg.dq_log;
  length check_id $8 table_name $20 description $90 severity $5 status $5
         rows_failed rows_total pct_failed run_ts 8;
  format pct_failed 8.2 run_ts datetime20.;
  stop;
run;

data stg.rejects;
  length check_id $8 table_name $20 row_key $40 reason $90;
  stop;
run;

/* q must return two columns: row_key (text) and reason (text) */
%macro chk(id=, tbl=, sev=, desc=, q=);
  %local nfail ntot;
  proc sql noprint;
    create table work._f as &q;
    select count(*) into :nfail trimmed from work._f;
    select count(*) into :ntot  trimmed from &tbl;
  quit;

  data work._row;
    if 0 then set stg.dq_log;
    check_id = "&id"; table_name = "&tbl"; description = "&desc";
    severity = "&sev";
    rows_failed = &nfail; rows_total = &ntot;
    pct_failed = 100 * rows_failed / rows_total;
    status = ifc(rows_failed = 0, 'PASS', severity);
    run_ts = datetime();
  run;
  proc append base=stg.dq_log data=work._row force; run;

  data work._rej;
    if 0 then set stg.rejects;
    set work._f(obs=1000);
    check_id = "&id"; table_name = "&tbl";
  run;
  proc append base=stg.rejects data=work._rej force; run;
%mend chk;

/* ---------- account ---------- */
%chk(id=C01, tbl=stg.account, sev=ERROR, desc=Duplicate account_id,
  q=%str(select put(account_id,best.) as row_key, 'duplicate account_id' as reason
         from stg.account group by account_id having count(*) > 1));

%chk(id=C02, tbl=stg.account, sev=ERROR, desc=district_id not in district,
  q=%str(select put(account_id,best.) as row_key, 'unknown district' as reason
         from stg.account where district_id not in (select district_id from stg.district)));

%chk(id=C08, tbl=stg.account, sev=ERROR, desc=Account has no OWNER disposition,
  q=%str(select put(account_id,best.) as row_key, 'no owner' as reason
         from stg.account
         where account_id not in (select account_id from stg.disp where type = 'OWNER')));

/* ---------- client ---------- */
%chk(id=C03, tbl=stg.client, sev=ERROR, desc=Duplicate client_id,
  q=%str(select put(client_id,best.) as row_key, 'duplicate client_id' as reason
         from stg.client group by client_id having count(*) > 1));

%chk(id=C04, tbl=stg.client, sev=ERROR, desc=district_id not in district,
  q=%str(select put(client_id,best.) as row_key, 'unknown district' as reason
         from stg.client where district_id not in (select district_id from stg.district)));

%chk(id=C05, tbl=stg.client, sev=WARN, desc=Birth date missing or client under 18,
  q=%str(select put(client_id,best.) as row_key, 'missing birth date or age < 18' as reason
         from stg.client where birth_date is null or age < 18));

/* ---------- disp ---------- */
%chk(id=C06, tbl=stg.disp, sev=ERROR, desc=client_id not in client,
  q=%str(select put(disp_id,best.) as row_key, 'unknown client' as reason
         from stg.disp where client_id not in (select client_id from stg.client)));

%chk(id=C07, tbl=stg.disp, sev=ERROR, desc=account_id not in account,
  q=%str(select put(disp_id,best.) as row_key, 'unknown account' as reason
         from stg.disp where account_id not in (select account_id from stg.account)));

/* ---------- loan ---------- */
%chk(id=C09, tbl=stg.loan, sev=ERROR, desc=account_id not in account,
  q=%str(select put(loan_id,best.) as row_key, 'unknown account' as reason
         from stg.loan where account_id not in (select account_id from stg.account)));

%chk(id=C10, tbl=stg.loan, sev=WARN, desc=Loan dated before account opened,
  q=%str(select put(l.loan_id,best.) as row_key, 'loan before account opened' as reason
         from stg.loan l inner join stg.account a on l.account_id = a.account_id
         where l.loan_date < a.account_date));

%chk(id=C11, tbl=stg.loan, sev=WARN, desc=payments x duration differs from amount by over 5 pct,
  q=%str(select put(loan_id,best.) as row_key, 'payments x duration mismatch' as reason
         from stg.loan where abs(payments * duration - amount) > 0.05 * amount));

/* ---------- card ---------- */
%chk(id=C12, tbl=stg.card, sev=ERROR, desc=disp_id not in disp,
  q=%str(select put(card_id,best.) as row_key, 'unknown disposition' as reason
         from stg.card where disp_id not in (select disp_id from stg.disp)));

/* ---------- order ---------- */
%chk(id=C13, tbl=stg.order, sev=ERROR, desc=account_id not in account,
  q=%str(select put(order_id,best.) as row_key, 'unknown account' as reason
         from stg.order where account_id not in (select account_id from stg.account)));

/* ---------- trans ---------- */
%chk(id=C14, tbl=stg.trans, sev=ERROR, desc=Duplicate trans_id,
  q=%str(select put(trans_id,best.) as row_key, 'duplicate trans_id' as reason
         from stg.trans group by trans_id having count(*) > 1));

%chk(id=C15, tbl=stg.trans, sev=ERROR, desc=account_id not in account,
  q=%str(select put(trans_id,best.) as row_key, 'unknown account' as reason
         from stg.trans where account_id not in (select account_id from stg.account)));

%chk(id=C16, tbl=stg.trans, sev=WARN, desc=Transaction dated before account opened,
  q=%str(select put(t.trans_id,best.) as row_key, 'transaction before account opened' as reason
         from stg.trans t inner join stg.account a on t.account_id = a.account_id
         where t.trans_date < a.account_date));

%chk(id=C17, tbl=stg.trans, sev=WARN, desc=Negative balance,
  q=%str(select put(trans_id,best.) as row_key, 'balance < 0' as reason
         from stg.trans where balance < 0));

%chk(id=C18, tbl=stg.trans, sev=WARN, desc=Amount zero or negative,
  q=%str(select put(trans_id,best.) as row_key, 'amount <= 0' as reason
         from stg.trans where amount <= 0));

/* ---------- district ---------- */
%chk(id=C19, tbl=stg.district, sev=WARN, desc=Missing unemployment_95 or crimes_95,
  q=%str(select put(district_id,best.) as row_key, 'missing 1995 value' as reason
         from stg.district where unemployment_95 is null or crimes_95 is null));

/* ---------- report ---------- */
title "DQ_LOG";
proc print data=stg.dq_log noobs;
  var check_id table_name description severity rows_failed rows_total pct_failed status;
run;

title "Checks by status";
proc freq data=stg.dq_log; tables status / nocum; run;

title "Sample of REJECTS (first 20)";
proc print data=stg.rejects(obs=20) noobs; run;
title;