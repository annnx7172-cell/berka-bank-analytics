/* 00_setup.sas: paths and libraries for the Berka project */
%let root = %sysget(HOME)/BERKA;

libname raw  "&root/raw_lib";    /* RAW:  data as it arrives */
libname stg  "&root/stg_lib";    /* STG:  cleaned            */
libname mart "&root/mart_lib";   /* MART: analysis tables    */