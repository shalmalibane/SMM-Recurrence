/*Name: Shalmali Bane*/
/*Date started: January 16, 2019*/
/*Date last modified: May, 2020*/
/*File used to run: OSHPD SMM Recurrance analysis */
/*Description: This script creates an analytic dataset to examine SMM*/
/*                  recurrance in 2nd pregnancy*/
/*            Appends datasets (years 1997-2012), gets rid of unnecessary*/
/*                records, does initial cleaning*/
/*                Only keeps women whose first two pregnancies are in California*/
/*                and are singleton live births*/
/*File used to run: OSHPD SMM Recurrance analysis */
/*Final dataset created:04.30.2020*/ 

 
/*Sections:*/
/*1. Read in and clean Birth Records*/
/*1a. Read in files for 1997-2012, keeping only birth records*/
/*1b. combine dataset years*/
/*1c. fix the parity variable*/
/*1d. Look at linkage status, only keep records that have linkage betweem vital records and maternal discharge records*/
/*1e. only keep births with gestational age 20-45 weeks*/
/*1f. only keep live births*/
/*1g. define multiple births and include keep only singleton*/
/*1h. identify the first and second births, only keep moms who have both left in the cohort*/
/*1i. Create permanent cleanded datasets*/

/*2. Define Variables and analyze SMM between pregnancies*/
/*2a. define SMM in first pregnancy*/
/*2b. rename all first birth SMM variables to make them distinct*/
/*2c. Maternal Characteristics at first birth*//*Read in maternal characteristics*/
/*2d. Define new levels of maternal characteristics for race, education, insurance, age at delivery*/
/*2e. Define formats for maternal characteristics*/

/*3. define SMM in second pregnancy*/

/*4. combine SMM information for first and second pregnancy*/
/*4a. define SMM no transfusion*/
/*4b. Assess frequncies of specific indicators in first birth and second birth SMM and keep only indicatiors with 15 under both*/
/*4c. get the frequencies of SMM in second birth (SMM) by smm status in first birth (first_smm) and selected indicators*/
/*4d. get the relative risk of smm at second birth by smm status in first birth, and indicators*/

/*5. Merge maternal characteristics with SMM data*/
/*5a. calculate descriptive statistics for maternal characteristics*/

/*6. Get adjusted relative risks for SMM*/
/*6a. get adjusted relative risks for SMM and indicators (age, race, payer type and education level, maternal comorbidities)*/

/*7. Sensitivity for recurrence rate over time*/
/*7a. Make 3 datasets for each cohort of 5 year internals*/
/*7b. Run main analysis for overall SMM including transfusion*/

libname ssb 'D:\UserData\sbane\1. SMM recurrence';
libname OSHPD /*readin in OSHPD data*/

/*1. Read in and clean Birth Records*/
/*1a. Read in files for 1997-2011, keeping only birth records*/

%macro readall;
%do x=1997 %to 2012;
data a&x. (keep = _brthid _losM caesar caesar05 _brthidhst typebth bthorder bthdate estgest
      gest probl_1 paymsold prevlbl prevlbd _year mage admdateM  disdateM disstat95M
      parity mrace msporig racem_c1 diagM00-diagM24 PROCM00-PROCM20 precare meduc
      meduc06 _twinwght _linkedb fdeath icd10d  _twinb _twinm _twini _losM probl_2 ceb);
      set oshpd.sc_lb&x. (where=(_input='B'));
run;
%end;
%mend;
%readall;

/*1b. combine dataset years*/
data all;
	set a1997-a2012;
run;

proc freq data=all; table parity bthorder ceb; run;

/*1c. fix the parity variable*/

proc sort data = all; by _brthidhst bthdate ceb; run;
 
data first_birth (keep = _brthidhst first_par);
      set all;
      by _brthidhst bthdate;
      if first._brthidhst;
      first_par = ceb;
run;

proc freq data=first_birth; table first_par; run;
 
data all_count (keep = _brthidhst _brthid count ceb);
      set all;
      by _brthidhst bthdate;
      count + 1;
      if first._brthidhst then count = 1;
run;

proc sort data = all_count; by _brthidhst; run;
proc sort data = first_birth; by _brthidhst; run;
 
data new_par;
      merge all_count first_birth;
      by _brthidhst;
run;
 
data new_par (keep = _brthid new_parity match);
      set new_par;
      new_parity = first_par - 1 + count;
      if new_parity = ceb then match = 1; else match = 0;
run;
 
proc freq data=new_par; table match; run;

proc sort data = all; by _brthid; run;
proc sort data = new_par; by _brthid; run;
 
data all2;
      merge all new_par;
      by _brthid;
run;
/*1d. Look at linkage status, only keep records that have linkage betweem vital records and maternal discharge records*/
proc freq data=all2;
table _linkedb;
run;

/*New dataset with Y (all) and M (vital+mother) statis linkage*/
data all3 drop;
 set all2;
 if _linkedb in ('Y', 'M') then output all3;
 else output drop;
run;

/*1e. only keep births with gestational age 20-45 weeks*/
data all4;
set all3;
	if estgest^=. then gestation= estgest*1;
	else gestation=gest/7;
/*Switch a number to numerical by multipling by 1*/
drop estgest gest;
run;

proc univariate data=all4;
	var gestation;
	histogram gestation;
run;

data all5 lt_20 gt_45 miss;
 set all4; 
 if 20 <= gestation <=45 then output all5;
 else if 0 <= gestation <20 then output lt_20;
 else if gestation > 45 then output gt_45;
 else output miss;
run;

/*1f. only keep live and stillbirth (drop missing)*/

data all6 drop; 
set all5;
 if fdeath=. then output drop;
 else output all6;
 run;

/*1g. define multiple births and include keep only singleton*/

data all7;
set all6;
if  _twinB='Y' or _twinM='Y' or _twinI='Y' then twin=1;
else twin=0;
run;

proc freq data=all7; table twin; run;

data all8 drop;
set all7;
if twin=1 then output drop;
else output all8;
run;

/*1h. identify the first and second births or stillbirths, only keep moms who have both left in the cohort*/
data first second;
set all8;
if new_parity=1 then output first;
if new_parity=2 then output second;
run;

proc sort data=first out=mom1 (keep=_brthidhst)nodupkey ; by _brthidhst; run;
proc sort data=second out=mom2 (keep=_brthidhst)nodupkey ; by _brthidhst; run;

data mom12;
	merge mom1 (in=a) mom2 (in=b);
	by _brthidhst;
	if a and b;
run;

proc sort data=mom12; by _brthidhst; run;
proc sort data=first; by _brthidhst; run;
proc sort data=second; by _brthidhst; run;

data first12;
	merge mom12 (in=a) first;	
	by _brthidhst;
	if a;
run;

data second12;
	merge mom12 (in=a) second;	
	by _brthidhst;
	if a;
run;

/*1i. Create permanent cleaned datasets*/
data ssb.first12;
set first12;
run;

data ssb.second12;
set second12;
run;


data ssb.second12;
set second12;
run;

/*2. Define Variables*/
/*2a. define SMM in first pregnancy*/
/*Read in SMMI macro*/
data firstbirth;
set ssb.first12;
	  %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\SMMI.sas";
run;

proc contents data=firstbirth; run;

/*2b. rename all first birth SMM variables to make them distinct*/
data firstbirth2;
set firstbirth (keep=_brthidhst MS_: SMM smm3c bthdate);
firstbthdate = bthdate;
firstsmm = smm;
firstsmm3c = smm3c;
first_afe = MS_AFE;
first_ami = MS_AMI;
first_aneurysm = MS_ANEURYSM;
first_ards = MS_ARDS ;
first_arf = MS_ARF; 
first_ate = MS_ATE ; 
first_cavf = MS_CAVF;  
first_conversion = MS_CONVERSION ;
first_dic = MS_DIC ;
first_eclampsia = MS_ECLAMPSIA;
first_hfds = MS_HFDS ;
first_hysterectomy = MS_HYSTERECTOMY ;
first_pcd = MS_PCD;
first_peahf = MS_PEAHF;
first_sac = MS_SAC;
first_sepsis = MS_SEPSIS ;
first_shock = MS_SHOCK;
first_sickle = MS_SICKLE ;
first_tracheostomy = MS_TRACHEOSTOMY; 
first_transfusion = MS_TRANSFUSION ;
first_ventilation = MS_VENTILATION;
drop MS_: smm smm3c bthdate;
run;

/* define SMM in second pregnancy*/
data secondbirth (keep = _brthidhst SMM SMM3C MS:);
	set ssb.second12;
	  %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Documentation\Constructed\SMMI.sas";
run;

/*rename all second birth SMM variables to make them distinct*/
data secondbirth2;
set secondbirth (keep=_brthidhst MS_: SMM smm3c);
secondbthdate = bthdate;
secondsmm = smm;
secondsmm3c = smm3c;
second_afe = MS_AFE;
second_ami = MS_AMI;
second_aneurysm = MS_ANEURYSM;
second_ards = MS_ARDS ;
second_arf = MS_ARF; 
second_ate = MS_ATE ; 
second_cavf = MS_CAVF;  
second_conversion = MS_CONVERSION ;
second_dic = MS_DIC ;
second_eclampsia = MS_ECLAMPSIA;
second_hfds = MS_HFDS ;
second_hysterectomy = MS_HYSTERECTOMY ;
second_pcd = MS_PCD;
second_peahf = MS_PEAHF;
second_sac = MS_SAC;
second_sepsis = MS_SEPSIS ;
second_shock = MS_SHOCK;
second_sickle = MS_SICKLE ;
second_tracheostomy = MS_TRACHEOSTOMY; 
second_transfusion = MS_TRANSFUSION ;
second_ventilation = MS_VENTILATION;
drop MS_: smm smm3c bthdate;
run;

/*combine SMM information for first and second pregnancy*/
proc sort data=secondbirth2; by _brthidhst; run;
proc sort data=firstbirth2; by _brthidhst; run;

Data cohort;
Merge secondbirth2 firstbirth2;
by _brthidhst;
run;

proc freq data = cohort; table firstsmm*secondsmm; run;

data cohort2;
	set cohort;
	if first_afe = 1 and second_afe = 1 then same_afe = 1;
	if first_ami = 1 and second_ami = 1 then same_ami = 1;
	if first_aneurysm = 1 and second_aneurysm = 1 then same_ANEURYSM = 1;
	if first_ards = 1 and second_ards = 1 then same_ARDS = 1;
	if first_arf = 1 and second_arf = 1 then same_ARF = 1; 
	if first_ate = 1 and second_ate = 1 then same_ATE = 1; 
	if first_cavf = 1 and second_cavf = 1 then same_CAVF = 1;  	
	if first_conversion = 1 and second_conversion = 1 then same_CONVERSION = 1;
	if first_dic = 1 and second_dic = 1 then same_DIC = 1;
	if first_eclampsia = 1 and second_eclampsia = 1 then same_ECLAMPSIA = 1;
	if first_hfds = 1 and second_hfds = 1 then same_HFDS = 1 ;
	if first_hysterectomy = 1 and second_hysterectomy = 1 then same_HYSTERECTOMY = 1;
	if first_pcd = 1 and second_pcd = 1 then same_PCD = 1;
	if first_peahf = 1 and second_peahf = 1 then same_PEAHF = 1;
	if first_sac = 1 and second_sac = 1 then same_SAC = 1;
	if first_sepsis = 1 and second_sepsis = 1 then same_SEPSIS = 1;
	if first_shock = 1 and second_shock = 1 then same_SHOCK = 1;
	if first_sickle = 1 and second_sickle = 1 then same_SICKLE = 1;
	if first_tracheostomy = 1 and second_tracheostomy then same_TRACHEOSTOMY = 1; 	
	if first_transfusion = 1 and second_transfusion = 1 then same_TRANSFUSION = 1;
	if first_ventilation = 1 and second_ventilation = 1 then same_VENTILATION = 1;
run;;

data cohort3;
	set cohort2;
	if firstsmm = 1 and secondsmm = 1 then do;
		if same_afe = 1 or same_ami = 1 or same_ANEURYSM = 1 or same_ARDS = 1 or same_ARF = 1 or same_ATE = 1 or same_CAVF = 1 or 
		same_CONVERSION = 1 or same_DIC = 1 or same_ECLAMPSIA = 1 or same_HFDS = 1 or same_HYSTERECTOMY = 1 or same_PCD = 1 or 
		same_PEAHF = 1 or same_SAC = 1 or same_SEPSIS = 1 or same_SHOCK = 1 or same_SICKLE = 1 or same_TRACHEOSTOMY = 1 or 
		same_TRANSFUSION = 1 or same_VENTILATION = 1 then same_smm = 1;
		else same_smm = 0;
	end;
run;

proc freq data = cohort3; table same_smm; run;

/*2c. Maternal Characteristics at first birth*/
/*Read in maternal characteristics*/
data mat_cat;
	set ssb.first12;
	  %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\HYPERTENSION.sas";
      %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\DIABETES.sas";
      %INC "D:\Projects\Carmichael-Lee-Data\OSHPDConstructed\MRACE7C.sas";
      %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\MEDUC6C.sas";
      %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\INSURANCE.sas";
run;

proc contents data=mat_cat; run;

/*2d. Define new levels of maternal characteristics for race, education, insurance, age at delivery*/
data mat_cat1;
set mat_cat;
select (mrace7c);
	when ('1') mrace5c=1;  
	when ('2') mrace5c=2; 
	when ('5') mrace5c=3;  
	when ('3') mrace5c=4; 
	when ('4') mrace5c=4;
	when ('6') mrace5c=5; 
	when ('7') mrace5c=5;
	when (.) mrace5c=5;
end;
select (delpayer);
	when ('1') delpayer3c = 2;
	when ('2') delpayer3c = 1;
	when ('3') delpayer3c = 3;
	when ('4') delpayer3c = 3;
	when (.) delpayer3c = 3;
end;
select (meduc6c);
	when ('1') meduc4c = 1;
	when ('2') meduc4c = 1;
	when ('3') meduc4c = 2;
	when ('4') meduc4c = 3;
	when ('5') meduc4c = 3;
	when (.) meduc4c = 4;
end;
if mage=. then mage_cat=4;
else if mage < 20 then mage_cat = 1;
else if 30 > mage >= 20 then mage_cat = 2;
else if 40 > mage >= 30 then mage_cat = 3;
else if mage >= 40 then mage_cat = 4;
run; 

data ssb.mat_cat;
set mat_cat1;
run; 
 
proc freq data= ssb.mat_cat; 
tables mrace7c*mrace5c delpayer*delpayer3c meduc6c*meduc4c mage*mage_cat prehyp predia/ nopercent nocol norow list missing; 
run; 

/*2e. Define formats for maternal characteristics*/
proc format;
      value mrace5c
      1="Non-Hispanic White"
      2="Non-Hispanic Black"
      3="Hispanic"
      4="Asian/Pacific Islander"
      5="Other/Missing"
      ;
      value meduc4c
      1="High school or less"
      2="Some college"
      3="Completed college"
      4="Missing"
	  ;
      value delpayer3c
      1="Government"
      2="Private"
      3="Other/Missing"
      ;
	  value mage_cat
	  1="<20"
	  2="20-<30"
	  3="30-<40"
	  4="=>40 or missing"
	  ;
	  value prehyp
	  0="No"
	  1="Yes"
	  ;
	  value predia
	  0="No"
	  1="Yes"
	  ;
run;

proc freq data= ssb.mat_cat;
table mage_cat*smm;
run;


/*3. define SMM in second pregnancy*/
data secondbirth (keep = _brthidhst SMM SMM3C);
	set ssb.second12;
	  %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Documentation\Constructed\SMMI.sas";
run;

/*4. combine SMM information for first and second pregnancy*/
proc sort data=secondbirth; by _brthidhst; run;
proc sort data=firstbirth2; by _brthidhst; run;

Data ssb.second_birth2;
Merge secondbirth firstbirth2;
by _brthidhst;
run;

/*4a. define SMM no transfusion*/
data ssb.second_birth3;
set ssb.second_birth2;
if firstSMM3C > 1 then first_SMMnotrans = 1;
else first_SMMnotrans = 0;
if SMM3C > 1 then SMMnotrans = 1;
else SMMnotrans = 0;
run;

proc freq data = ssb.second_birth3;
table first_SMMnotrans*SMMnotrans;
run;

/*4b. Assess frequncies of specific indicators in first birth and second birth SMM and keep only indicatiors with 15 under both*/
proc freq data=ssb.second_birth3;
tables (first_afe first_ami first_aneurysm first_ards first_arf first_ate first_cavf first_conversion first_dic first_eclampsia 
first_hfds first_hysterectomy first_pcd first_peahf first_sac first_sepsis first_shock first_sickle first_tracheostomy first_transfusion
first_ventilation)*smm /nocol nopercent; 
run;

/*4c. get the frequencies of SMM in second birth (SMM) by smm status in first birth (first_smm) and selected indicators*/
/*SMM*/
proc freq data=ssb.second_birth3; 
table firstsmm*smm/ nocol nopercent; 
run;

/*SMM no transfusion*/
proc freq data=ssb.second_birth3; 
table first_smmnotrans*smmnotrans/ nocol nopercent; 
run;

/*Blood transfusions*/
proc freq data=ssb.second_birth3;  
table first_transfusion*smm/ nocol nopercent; 
run;

/*DIC*/
proc freq data=ssb.second_birth3; 
table first_DIC*smm/ nocol nopercent; 
run;

/*peahf*/
proc freq data=ssb.second_birth3; 
table first_peahf*smm/ nocol nopercent; 
run;

/*eclampsia*/
proc freq data=ssb.second_birth3; 
table first_eclampsia*smm/ nocol nopercent; 
run;

/*Sickle cell*/
proc freq data=ssb.second_birth3; 
table first_sickle*smm/ nocol nopercent; 
run;

/*4d. get the relative risk of smm at second birth by smm status in first birth, and indicators*/
/*SMM*/
proc genmod data = ssb.second_birth3 desc;
	model smm = firstsmm/dist=poisson link=log;
    estimate 'SMM at First Birth' firstsmm 1 -1/exp;
run;

/*SMM no trans*/
proc genmod data = ssb.second_birth3 desc;
      model smmnotrans = first_smmnotrans/dist=poisson link=log;
      estimate 'SMM at First Birth, no transfusion' first_smmnotrans 1 -1/exp;
run;

/*Transfusion*/
proc genmod data = ssb.second_birth3 desc;
      model smm = first_transfusion /dist=poisson link=log;
      estimate 'SMM Indicator at First Birth - transfusion' first_transfusion 1 -1/exp;
run;

/*DIC*/
proc genmod data = ssb.second_birth3 desc;
      model smm = first_DIC /dist=poisson link=log;
      estimate 'SMM Indicator at First Birth - DIC' first_DIC 1 -1/exp;
run;

/*peahf*/
proc genmod data = ssb.second_birth3 desc;
      model smm = first_peahf /dist=poisson link=log;
      estimate 'SMM Indicator at First Birth - peahf' first_peahf 1 -1/exp;
run;

/*eclampsia*/
proc genmod data = ssb.second_birth3 desc;
      model smm = first_eclampsia /dist=poisson link=log;
      estimate 'SMM Indicator at First Birth - eclampsia' first_eclampsia 1 -1/exp;
run;

/*Sickle cell*/
proc genmod data = ssb.second_birth3 desc;
      model smm = first_Sickle /dist=poisson link=log;
      estimate 'SMM Indicator at First Birth - Sickle' first_Sickle 1 -1/exp;
run;

/*5. Merge maternal characteristics with SMM data*/
Proc sort data = ssb.mat_Cat; by _brthidhst; run;
Proc sort data = ssb.second_birth3; by _brthidhst; run;

Data ssb.all_vars;
	Merge ssb.mat_cat (in = a) ssb.second_birth3 (in = b);
	By _brthidhst; 
	If a and b;
Run;

/*5a. calculate descriptive statistics for maternal characteristics*/
proc freq data= ssb.all_vars;
table (mrace5c delpayer3c meduc4c mage_cat prehyp predia)*firstsmm /norow nopercent;
format mrace5c mrace5c. delpayer3c delpayer3c. meduc4c meduc4c. mage_cat mage_cat. prehyp prehyp. predia predia.;
run; 

/*6. Get adjusted relative risks for SMM*/
/*6a. get adjusted relative risks for SMM and indicators (age, race, payer type and education level, pregestational diabetes + hypertension)*/
/*SMM*/
proc genmod data = ssb.all_vars desc;
	  class mrace5c delpayer3c meduc4c mage_cat;
      model smm = firstsmm mrace5c delpayer3c meduc4c mage_cat prehyp predia / link=log dist=poisson;
      estimate 'SMM at First Birth' firstsmm 1 -1/exp;
run;
/*SMM no trans*/
proc genmod data = ssb.all_vars desc;
      class mrace5c delpayer3c meduc4c mage_cat;
      model smmnotrans = first_smmnotrans mrace5c delpayer3c meduc4c mage_cat prehyp predia / link=log dist=poisson;
      estimate 'SMM at First Birth - no transfusion' first_smmnotrans 1 -1/exp;
run;

/*Transfusion*/
proc genmod data = ssb.all_vars desc;
      class mrace5c delpayer3c meduc4c mage_cat;
      model smm = first_transfusion mrace5c delpayer3c meduc4c mage_cat prehyp predia / link=log dist=poisson;
      estimate 'SMM Indicator at First Birth - transfusion' first_transfusion 1 -1/exp;
run;

/*DIC*/
proc genmod data = ssb.all_vars desc;
      class mrace5c delpayer3c meduc4c mage_cat;
      model smm = first_dic mrace5c delpayer3c meduc4c mage_cat prehyp predia / link=log dist=poisson;
      estimate 'SMM Indicator at First Birth - DIC' first_dic 1 -1/exp;
run;

/*peahf*/
proc genmod data = ssb.all_vars desc;
      class mrace5c delpayer3c meduc4c mage_cat;
      model smm = first_peahf mrace5c delpayer3c meduc4c mage_cat prehyp predia / link=log dist=poisson;
      estimate 'SMM Indicator at First Birth - PEAHF' first_peahf 1 -1/exp;
run;

/*eclampsia*/
proc genmod data = ssb.all_vars desc;
      class mrace5c delpayer3c meduc4c mage_cat;
      model smm = first_eclampsia mrace5c delpayer3c meduc4c mage_cat prehyp predia / link=log dist=poisson;
      estimate 'SMM Indicator at First Birth - eclampsia' first_eclampsia 1 -1/exp;
run;

/*Sickle cell*/
proc genmod data = ssb.all_vars desc;
      class mrace5c delpayer3c meduc4c mage_cat;
      model smm = first_sickle mrace5c delpayer3c meduc4c mage_cat prehyp predia / link=log dist=poisson;
      estimate 'SMM Indicator at First Birth - sickle' first_sickle 1 -1/exp;
run;

/*7. Sensitivity for recurrence rate over time*/
/*7a. Make 4 datasets for each cohort of 5 year internals*/
data a_97to00 b_01to04 c_05to08 d_09to12; 
set ssb.all_vars;
if _year in (1997:2000) then output a_97to00;
if _year in (2001:2004) then output b_01to04;
if _year in (2005:2008) then output c_05to08;
if _year in (2009:2012) then output d_09to12;
run;

proc freq data=a_97to00; table _year; run;
proc freq data=b_01to04; table _year; run;
proc freq data=c_05to08; table _year; run;
proc freq data=d_09to12; table _year; run;

/*7b. Run main analysis for overall SMM including transfusion*/
/*SMM*/
proc freq data=ssb.all_vars;  table firstsmm*smm/ nocol nopercent; run;
proc freq data=a_97to00;  table firstsmm*smm/ nocol nopercent; run;
proc freq data=b_01to04;  table firstsmm*smm/ nocol nopercent; run;
proc freq data=c_05to08;  table firstsmm*smm/ nocol nopercent; run;
proc freq data=d_09to12;  table firstsmm*smm/ nocol nopercent; run;

/*SMM*/
proc genmod data = ssb.all_vars desc;
	model smm = firstsmm/dist=poisson link=log;
    estimate 'SMM at First Birth' firstsmm 1 -1/exp;
run;

proc genmod data = a_97to00 desc;
	model smm = firstsmm/dist=poisson link=log;
    estimate 'SMM at First Birth' firstsmm 1 -1/exp;
run;

proc genmod data = b_01to04 desc;
	model smm = firstsmm/dist=poisson link=log;
    estimate 'SMM at First Birth' firstsmm 1 -1/exp;
run;

proc genmod data = c_05to08 desc;
	model smm = firstsmm/dist=poisson link=log;
    estimate 'SMM at First Birth' firstsmm 1 -1/exp;
run;

proc genmod data = d_09to12 desc;
	model smm = firstsmm/dist=poisson link=log;
    estimate 'SMM at First Birth' firstsmm 1 -1/exp;
run;

