Extreme computing or efficient sums for many columns ( 5 million rows and 40 columns )

  Sum down columns and output one observatiom with 40 sums

  Benchmarks (not scientific - your mileage may vary)

   Seconds   In Memory (no input/output - wps was batch - SAS interactive(cacheing possible)

 1.  0.22      WPS/Ppro R or SAS/IML/R (pure in memory matrix as input - not a dataframe)
 2.  0.58      SAS IML
 3.  0.64      WPS IML

               With input/output ( basically no difference )

 4.  3.45      SAS Summary
 5.  3.45      WPS Summary

 6.  4.61      WPS SQL  (passthru to exadate or teradata very fast?)
 7.  5.51      SAS SQL  (passthru to exadate or teradata very fast?)

 9.  9.42      WPS datastep
 8. 10.17      SAS datastep

 Harder to multi-thread columns than rows, especially without a class or group variable.

INPUT
=====

    5 million rows and 40 columns (all values are 1)

    Middle Observation(2500000 ) of bin - Total Obs 5,000,000

        COLUMS          Sample
     -- NUMERIC --      Value

    BIN1        N8       1    all values in all observations are `
    BIN2        N8       1
    BIN3        N8       1
    -----       --       -
    -----       --       -
    BIN37       N8       1
    BIN38       N8       1
    BIN39       N8       1


  EXAMPLE OUTPUT
                         Column
    -- NUMERIC --        Sums

   COLSUM1      N8       5000000
   COLSUM2      N8       5000000
   COLSUM3      N8       5000000
    -----       --       -
    -----       --       -
   COLSUM38     N8       5000000
   COLSUM39     N8       5000000
   COLSUM40     N8       5000000


MAKE DATA
=========

   * INPUT FOR R - much faster to input flatfile of binary floats;
  filename bin "d:/bin/binmat.bin" lrecl=32000 recfm=f;
  data _null_;
    retain one 1;
    file bin ;
     do i=1 to 200000000;
      put one rb8. @ ;
      output;
    end;
  run;quit;

  * input for SAS and WPS;
  data bin(keep=bin: compress=binary);
    array bin[40] bin1-bin40 (40*1);
     do i=1 to 5000000;
        output;
    end;
    stop;
  run;quit;



PROCESS (All the code)
======================

 1.  0.22      WPS/Ppro R or SAS/IML/R
 =====================================

    %utl_submit_r64('
    read.from <- file("d:/bin/binmat.bin", "rb");
    floats <- readBin(read.from, n=200000000, "double");
    floats <- matrix(floats, nrow=5000000,ncol=40);
    system.time(colsum<-colSums(floats));
    str(colsum);
    ');

    /* log
       user  system elapsed
       0.22    0.00    0.22
       num [1:40] 5e+06 5e+06 5e+06 5e+06 5e+06 5e+06 5e+06 5e+06 5e+06 5e+06
    */

 2.  0.58      SAS IML
 =====================

    Proc iml;
    use bin ;
    read all into bin ;
    t0 = time();
    ColSum = bin[,+];
    tElapsed = time()-t0;
    print tElapsed;
    quit;

    /*
     TELAPSED
    0.5810001
    */

  3.  0.66      WPS IML
  =====================

    %utl_submit_wps64('
    libname sd1 "d:/sd1";
    options set=R_HOME "C:/Program Files/R/R-3.3.1";
    libname wrk "%sysfunc(pathname(work))";
    Proc iml;
    use wrk.bin ;
    read all into bin ;
    t0 = time();
    ColSum = bin[,+];
    tElapsed = time()-t0;
    print tElapsed;
    quit;
    run;quit;
   ');

   /*
    tElapsed
    0.6389999
   */


  4.  3.45      SAS Summary
  ==========================

   proc summary data=bin;
     var bin:;
     output out=want_summary(drop=_type_ _freq_) sum=/autoname;
   run;quit;

   /*
   NOTE: There were 5000000 observations read from the data set WORK.BIN.
   NOTE: The data set WORK.WANT_SUMMARY has 1 observations and 40 variables.
   NOTE: PROCEDURE SUMMARY used (Total process time):
         real time           3.50 seconds
         user cpu time       16.41 seconds
         system cpu time     0.45 seconds
         memory              8936.81k
         OS Memory           32496.00k
         Timestamp           02/11/2018 04:26:58 PM
         Step Count                        168  Switch Count  0
   */


  5.  3.90      WPS Summary (not exactly fair because I coverted SAS dataset to WPS dataset cacheing)
  ====================================================================================================

     %utl_submit_wps64('
     libname wrk sas7bdat "%sysfunc(pathname(work))";
     data binwps;
       set wrk.bin;
     run;quit;
     proc summary data=binwps;
     var bin:;
     output out=want_summary(drop=_type_ _freq_) sum=/autoname;
     run;quit;
     ');

     /*
     6         proc summary data=binwps;
     7         var bin:;
     8         output out=want_summary(drop=_type_ _freq_) sum=/autoname;
     9         run;
     NOTE: 5000000 observations were read from "WORK.binwps"
     NOTE: Data set "WORK.want_summary" has 1 observation(s) and 40 variable(s)
     NOTE: Procedure summary step took :
           real time : 3.453
           cpu time  : 3.307
     */


  6.  4.61      WPS SQL (not exactly fair because I coverted SAS dataset to WPS dataset cacheing)
  ===============================================================================================

    %utl_submit_wps64('
    libname wrk sas7bdat "%sysfunc(pathname(work))";
     data binwps;
       set wrk.bin;
    run;quit;
    proc sql;
      create
        table wrk.want as
      select
        %array(bins,values=1-40)
        %do_over(bins,phrase=sum(bin?) as bin?,between=comma)
      from
        binwps
    ;quit;
    run;quit;
    ');

    /*
    NOTE: Data set "WRK.want" has 1 observation(s) and 40 variable(s)
    11        quit;
    NOTE: Procedure sql step took :
          real time : 4.610
          cpu time  : 4.524
    */

  7.  5.36      SAS SQL
  =====================

    %utlnopts; * turn off all that macro generated code;
    %let beg %sysfunc(time());
    proc sql;
      create
        table want as
      select
        %array(bins,values=1-40)
        %do_over(bins,phrase=sum(bin?) as bin?,between=comma)
      from
        bin
    ;quit;
    %put %sysevalf(%sysfunc(time()) - &beg);
    %utlopts; * turn macro generation on;


  8.  9.42      WPS datastep
  ===========================

    %utl_submit_wps64('
    libname wrk sas7bdat "%sysfunc(pathname(work))";
    data wrk.want_wps_datastep;
      set wrk.bin;
      array bins[40]  bin1-bin40;
      array binsums[40]  binsum1-binsum40;
      %array(bins,values=1-40);
      %do_over(bins,phrase=%str(colsum?+bin?;));
      keep colsum:;
    run;quit;
    ');

    NOTE: 5000000 observations were read from "WRK.bin"
    NOTE: Data set "WORK.binwps" has 5000000 observation(s) and 40 variable(s)
    NOTE: The data step took :
      real time : 9.421
      cpu time  : 6.754


  9.  10.17      SAS datastep
  ==========================


    %let beg %sysfunc(time());
    data want;
      set bin;
      array bins[40]  bin1-bin40;
      array binsums[40] binsum1-binsum40;
      %array(bins,values=1-40);
      %do_over(bins,phrase=%str(colsum?+bin?;));
      keep colsum:;
    run;quit;
    %put %sysevalf(%sysfunc(time()) - &beg);

    NOTE: There were 5000000 observations read from the data set WORK.BIN.
    NOTE: The data set WORK.WANT has 5000000 observations and 40 variables.
    NOTE: DATA statement used (Total process time):
          real time           10.17 seconds
          user cpu time       4.05 seconds
          system cpu time     3.22 seconds
          memory              4569.00k
          OS Memory           29532.00k
          Timestamp           02/11/2018 07:07:12 PM
          Step Count                        260  Switch Count  1





