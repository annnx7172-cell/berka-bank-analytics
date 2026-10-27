/* 05_model.sas: loan default model (B, D = default; A, C = no default) */
%include "%sysget(HOME)/BERKA/code/00_setup.sas";

/* ---------- features + 70/30 split, stratified on the outcome ---------- */
data work.lb;
  set mart.loan_base;
  had_negative = (n_negative_before > 0);   /* overdrawn before the loan */
run;

proc sort data=work.lb; by is_default; run;

proc surveyselect data=work.lb out=work.split outall
                  samprate=0.7 seed=1998 method=srs;
  strata is_default;
run;

data work.train work.test;
  set work.split;
  if selected then output work.train; else output work.test;
run;

proc sql;
  title "Split sizes and default counts";
  select 'train' as part, count(*) as loans, sum(is_default) as defaults from work.train
  union all
  select 'test', count(*), sum(is_default) from work.test;
quit;

/* ---------- fit on train (Firth handles the separation) ---------- */
ods output CLOddsPL=work.odds ParameterEstimates=work.params Association=work.assoc_train;
proc logistic data=work.train outmodel=work.m1;
  model is_default(event='1') =
        had_negative amount duration payment_to_salary age_at_loan avg_monthly_credits
        / firth clodds=pl;
run;

/* ---------- score the test set with the stored model ---------- */
proc logistic inmodel=work.m1;
  score data=work.test out=work.scored_test;
run;

/* ---------- AUC on the held-out test set ---------- */
ods output ROCAssociation=work.auc_test;
proc logistic data=work.scored_test;
  model is_default(event='1') = P_1 / nofit;
  roc 'Test' pred=P_1;
run;

/* ---------- default rate by risk quintile (test) ---------- */
proc rank data=work.scored_test out=work.quint groups=5;
  var P_1;
  ranks risk_group;
run;

proc sql;
  title "Test set: actual default rate by predicted-risk quintile (4 = highest risk)";
  select risk_group, count(*) as loans, sum(is_default) as defaults,
         mean(is_default) as actual_default_rate format=percent8.1
  from work.quint group by risk_group order by risk_group;
quit;

/* ---------- score every loan for Tableau ---------- */
proc logistic inmodel=work.m1;
  score data=work.split out=mart.loan_scored(rename=(P_1=pd_default));
run;

data mart.loan_scored;
  set mart.loan_scored;
  dataset = ifc(selected, 'train', 'test');
  drop selected P_0 F_is_default I_is_default;
run;

title "Final model: odds ratios (Firth, profile-likelihood CI)";
proc print data=work.odds noobs; run;
title "AUC: train and test";
proc print data=work.assoc_train noobs; run;
proc print data=work.auc_test noobs; run;
title;