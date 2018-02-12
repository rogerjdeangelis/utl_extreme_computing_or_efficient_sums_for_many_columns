Extreme computing or efficient sums for many columns ( 5 million rows and 40 columns )

Thanks to Paul
Datastep is now the fastest non in memory solution.
(see Pauls comments on end of message)

I ran these benchmarks on my Laptop  E6420 I7 with 8gb, 2 240gb SSDs (not Raid 0). SAS 9.4M2 64bit

CORRECTIONS
===========

   My datasteps wrote 5,000,000 observations. Now outputs just one with 40 totals using Pauls algorithm
   Also I did not need the first array statement in the datastep solutions
   I also added keep bin_sum: to Pauls solution so that only 40 variables where output instead of 80

   I think it is hard to multi-thread column sums.

github
https://goo.gl/iHrDSA
https://github.com/rogerjdeangelis/utl_extreme_computing_or_efficient_sums_for_many_columns

  Sum down columns and output one observatiom with 40 sums

  Benchmarks (not scientific - your mileage may vary)

   Seconds   In Memory (no input/output - wps was batch - SAS interactive(cacheing possible)

 1.  0.22      WPS/Ppro R or SAS/IML/R (pure in memory matrix as input - not a dataframe)
 2.  0.58      SAS IML
 3.  0.64      WPS IML

               With input/output ( basically no difference )

 4   3.12      SAS datastep Paul Dorfman
 5   4.17      WPS datastep Paul Dorfman

 6.  3.45      SAS Summary
 7.  3.45      WPS Summary

 8.  4.61      WPS SQL  (passthru to exadate or teradata very fast?)
 9.  5.51      SAS SQL  (passthru to exadate or teradata very fast?)


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


  4.  2.95  Pauls SAS datastep (no perm array - my array ends up shifting data around - data not contig?)

    %macro sum ;
      %do i = 1 %to 40 ;
        bin_sum&i + bin&i ;
      %end ;
    %mend ;
    data want_wps_datapaul;
      do until (z) ;
        set bin end = z ;
        %sum
      end ;
      keep bin_sum:;
      output ;
    run ;quit;

    NOTE: There were 5000000 observations read from the data set WORK.BIN.
    NOTE: The data set WORK.WANT_WPS_DATAPAUL has 1 observations and 40 variables.
    NOTE: DATA statement used (Total process time):
          real time           2.95 seconds
          cpu time            2.94 seconds

  5.  4.17  Pauls WPS datastep (no perm array - my array ends up shifting data around - data not contig?)

    %utl_submit_wps64('
    libname wrk sas7bdat "%sysfunc(pathname(work))";
    %macro sum ;
      %do i = 1 %to 40 ;
        bin_sum&i + bin&i ;
      %end ;
    %mend ;
    data wrk.want_wps_datastep;
      do until (z) ;
        set wrk.bin end = z ;
        %sum
      end ;
      keep bin_sum:;
      output ;
    run ;quit;
    ');

    NOTE: There were 5000000 observations read from the data set WORK.BIN.
    NOTE: The data set WORK.WANT_DS has 1 observations and 40 variables.
    NOTE: DATA statement used (Total process time):
          real time           3.12 seconds
          cpu time            3.13 seconds


  6.  3.45      SAS Summary
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


  7.  3.90      WPS Summary (not exactly fair because I coverted SAS dataset to WPS dataset cacheing)
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


  8.  4.61      WPS SQL (not exactly fair because I coverted SAS dataset to WPS dataset cacheing)
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

  9.  5.36      SAS SQL
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


*                  _
 _ __   __ _ _   _| |
| '_ \ / _` | | | | |
| |_) | (_| | |_| | |
| .__/ \__,_|\__,_|_|
|_|
;


I've tested on the same machine under 9.3 and 9.4 (have no access to WPS and/or IML),
and the results are all over the place.
With 9.3, SUMMARY is (all in seconds) 7.33 vs
DATA step at 5.63. With 9.4, SUMMARY is 3.63 vs DATA step at 5.24. However, I've
also found that if you unroll the DO loop into separately compiled SUM statements, for example, via:

%utl_submit_wps64('
libname wrk sas7bdat "%sysfunc(pathname(work))";
%macro sum ;
  %do i = 1 %to 40 ;
    bin_sum&i + bin&i ;
  %end ;
%mend ;
data wrk.want_wps_datastep;
  do until (z) ;
    set wrk.bin end = z ;
    %sum
  end ;
  output ;
run ;quit;
');

NOTE: There were 5000000 observations read from the data set WORK.BIN.
NOTE: The data set WORK.WANT_DS has 1 observations and 40 variables.
NOTE: DATA statement used (Total process time):
      real time           3.12 seconds
      cpu time            3.13 seconds


then the DATA step comes on top in both 9.3 and 9.4 at 3.31 and 3.00, respectively,
even with the SUMMARY multi-threading. This is easy to explain - the unrolling obviates
the need to recompute the array addresses at run time for each observation, and the
time needed to compile mere 40 SUM statements is totally inconsequential. (I recall
resorting to the same trick for the same rea
son using macros in PL/I - and practically the same syntax - good 40 years ago.)

Why the rest of the test results are so scattered across the methods and versions, I have no explanation.

%macro sum ;
  %do i = 1 %to 40 ;
    bin_sum&i + bin&i ;
  %end ;
%mend ;
data want_ds (keep = bin_sum:) ;
  do until (z) ;
    set bin end = z ;
    %sum
  end ;
  output ;
run ;






