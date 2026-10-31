/* 05_tests.sas: hypothesis tests + CSV export */
%include "%sysget(HOME)/BERKA/code/00_setup.sas";

/* ---------- chi-square: is default related to region, gender, age band? ---------- */
title "Chi-square: default vs region";
proc freq data=mart.loan_summary;
  tables region * default_flag / chisq expected nocol nopercent;
run;

title "Chi-square: default vs gender";
proc freq data=mart.loan_summary;
  tables gender * default_flag / chisq nocol nopercent;
run;

title "Chi-square: default vs age band";
proc freq data=mart.loan_summary;
  tables age_band * default_flag / chisq nocol nopercent;
run;

/* ---------- t-test: do defaulters differ in amount, age, duration? ---------- */
title "t-test: defaulters (1) vs others (0)";
proc ttest data=mart.loan_summary;
  class default_flag;
  var amount age_at_loan duration;
run;
title;

/* ---------- export the three summary tables ---------- */
data work.monthly_out;
  set mart.monthly_summary;
  format month_start yymmdd10.;
run;

data work.loan_out;
  set mart.loan_summary;
  format loan_date yymmdd10.;
run;

data work.district_out;
  set mart.district_summary;
  format default_rate best12.;
run;

proc export data=work.monthly_out  outfile="&root/Export/monthly_summary.csv"
            dbms=csv replace; run;
proc export data=work.loan_out     outfile="&root/Export/loan_summary.csv"
            dbms=csv replace; run;
proc export data=work.district_out outfile="&root/Export/district_summary.csv"
            dbms=csv replace; run;