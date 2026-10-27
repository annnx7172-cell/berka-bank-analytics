
/* 01_import.sas: load the 8 raw files into the RAW library, as they arrive */
%include "%sysget(HOME)/BERKA/code/00_setup.sas";

%let rawdir = &root/raw;

data raw.account;
  infile "&rawdir/account.asc" dsd dlm=';' firstobs=2 truncover termstr=crlf;
  length account_id district_id 8 frequency $20 date $6;
  input account_id district_id frequency date;
run;

data raw.card;
  infile "&rawdir/card.asc" dsd dlm=';' firstobs=2 truncover termstr=crlf;
  length card_id disp_id 8 type $10 issued $20;
  input card_id disp_id type issued;
run;

data raw.client;
  infile "&rawdir/client.asc" dsd dlm=';' firstobs=2 truncover termstr=crlf;
  length client_id 8 birth_number $6 district_id 8;
  input client_id birth_number district_id;
run;

data raw.disp;
  infile "&rawdir/disp.asc" dsd dlm=';' firstobs=2 truncover termstr=crlf;
  length disp_id client_id account_id 8 type $10;
  input disp_id client_id account_id type;
run;

data raw.district;
  infile "&rawdir/district.asc" dsd dlm=';' firstobs=2 truncover termstr=crlf;
  length A1 8 A2 $30 A3 $30 A4-A11 8 A12 $10 A13 A14 8 A15 $10 A16 8;
  input A1-A16;
run;

data raw.loan;
  infile "&rawdir/loan.asc" dsd dlm=';' firstobs=2 truncover termstr=crlf;
  length loan_id account_id 8 date $6 amount duration payments 8 status $1;
  input loan_id account_id date amount duration payments status;
run;

data raw.order;
  infile "&rawdir/order.asc" dsd dlm=';' firstobs=2 truncover termstr=crlf;
  length order_id account_id 8 bank_to $2 account_to $10 amount 8 k_symbol $20;
  input order_id account_id bank_to account_to amount k_symbol;
run;

data raw.trans;
  infile "&rawdir/trans.asc" dsd dlm=';' firstobs=2 truncover termstr=crlf;
  length trans_id account_id 8 date $6 type $10 operation $20
         amount balance 8 k_symbol $20 bank $2 account $10;
  input trans_id account_id date type operation amount balance
        k_symbol bank account;
run;

/* row-count check */
proc sql;
  select memname, nobs
  from dictionary.tables
  where libname = 'RAW'
  order by memname;
quit;