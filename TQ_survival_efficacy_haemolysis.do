***********************************************************************************
*	Do-file:		TQ_survival_efficacy_haemolysis.do
*	Project:		TQ pooled data analysis
*
*	Data used:		an1_tq_efficacy.dta
*	Data created:	
*
*	Date:			Jul-2022
*	Author: 		Commons.R
***********************************************************************************

*Update PK file
import delimited "/Users/robcommons/Dropbox/Github/Tafenoquine-efficacy/TQ_PK_summaries.csv", clear 
gen log_AUC=log10(auc)
replace auc=auc/1000
save "/Users/robcommons/Dropbox/WWARN Vivax Study Groups/Stata do files/Analysis files/TQ/TQ_PK_summaries.dta", replace


*Update methb file
import delimited "/Users/robcommons/Dropbox/Github/Tafenoquine-efficacy/day_7_mthb.csv", varnames(1) stringcols(3) clear 
drop v1
replace day7_mthb="" if day7_mthb=="NA"
destring day7_mthb, gen(day7_mthb2)
drop day7_mthb
rename day7_mthb2 day7_mthb
save "/Users/robcommons/Dropbox/WWARN Vivax Study Groups/Stata do files/Analysis files/TQ/day_7_mthb.dta", replace



*******************************************
********Main efficacy analysis***********
*******************************************
clear all
cd "/Users/robcommons/Dropbox/WWARN Vivax Study Groups/Data/Analysis/TQ"
use "/Users/robcommons/Dropbox/Github/Tafenoquine-efficacy/an1_tq_efficacy.dta"

gen study="GATHER" if sid=="BSAJK"
replace study="DETECTIVE_Ph3" if sid=="KTMTV"
replace study="DETECTIVE_Ph2" if sid=="PRSXC"

*Drop PQ
drop if trt2=="Pq"

*Generate TQ dose in mg
gen AMT=round(weight*tqmgkgtot,1)
tab AMT

*Merge Pk and methb
drop _merge
merge m:1 pid using "/Users/robcommons/Dropbox/WWARN Vivax Study Groups/Stata do files/Analysis files/TQ/TQ_PK_summaries.dta"
drop if _merge==2
drop _merge
merge m:1 pid using "/Users/robcommons/Dropbox/WWARN Vivax Study Groups/Stata do files/Analysis files/TQ/day_7_mthb.dta"
drop if _merge==2
drop _merge


gen weight_5=weight/5
gen cqmgkgtot_5=cqmgkgtot/5
gen age_5=age/5

gen origin180=7
replace origin180=0 if dlast<7

gen tqcat5=0 if trt2!="Tq"
replace tqcat5=1 if tqmgkgtot<3.75&trt2=="Tq"
replace tqcat5=2 if tqmgkgtot>=3.75&tqmgkgtot<6.25
replace tqcat5=3 if tqmgkgtot>=6.25&tqmgkgtot<8.75
replace tqcat5=4 if tqmgkgtot>=8.75&!missing(tqmgkgtot)
label define tqcat5 0 "No TQ" 1 "<3.75mg/kg" 2 "3.75-6.25mg/kg" 3 "6.25-8.75mg/kg" 4 ">=8.75mg/kg"
label values tqcat5 tqcat5


*******KM figures***********
stset dlast180_2, failure (outcome7to180) id(pid) origin(origin180)

sts graph, failure by(tqcat5) ci  xtitle(Days, margin(medsmall)) ytitle(Probability of failure, margin(medsmall)) yscale(range (0 0.75)) ylabel(0 (0.1) 0.7, angle(horizontal) ) xscale(range(-7 173)) xlabel(-7 "0" 83 "90" 173 "180")  graphregion(fcolor(white) ifcolor(white) lcolor(white) ilcolor(white)) plotregion(fcolor(white) ifcolor(white) lcolor(white) ilcolor(white)) ciopts(lcolor(none)) plotopts(lwidth(medthick)) risktable(0 83 173, size(small) order(1 "No TQ" 2 "<3.75" 3 "3.75-<6.25" 4 "6.25-<8.75" 5 ">=8.75") title("")) legend(pos(11) ring(0) col(1) row(5) size(small) label(11 "No TQ") label(12 "3.75mg/kg") label(13 "3.75-<6.25mg/kg") label(14 "6.25-<8.75mg/kg") label(15 ">=8.75mg/kg") order(11 12 13 14 15) region(lwidth(none)) region(fcolor(none) lcolor(none))) title("") saving("KM_by TQ cat.gph", replace)



*******Cox regression analysis looking at tqmgkgtot***********
*All patients
stcox tqmgkgtot  logpara0 , shared(studysite)
matrix list r(table)
estat phtest, detail
gen tqmgkgtot_sq=tqmgkgtot*tqmgkgtot
stcox tqmgkgtot tqmgkgtot_sq logpara0, shared(studysite)

* Restrict to 300mg dose
stcox tqmgkgtot  logpara0 if AMT==300, shared(studysite)
matrix list r(table)

*Look at tqcat
stcox i.tqcat5  logpara0 , shared(studysite)
estat phtest, detail
stphplot, by(tqcat5) nolntime saving("log-log plot for Cox_Tq cat.gph", replace)




*******Generate spline figure for tqmgkgtot ********************
gen tqtot = tqmgkgtot if tqmgkgtot>=0&tqmgkgtot<=15
su tqtot

// Mean centreing logpara0
su logpara0
gen logpara0_mc = logpara0 - `r(mean)' 
su logpara0_mc

generate all =1

preserve
// create spline variables for pqmgkgtot
mkspline spl_tqtot_4=tqtot, cubic nknots(4) di
stcox spl_tqtot_4* logpara0_mc, shared(studysite)
levelsof tqtot, local(tqs)
xblc spl_tqtot_41 spl_tqtot_42 spl_tqtot_43, covname(tqtot) at(`tqs') reference(5) eform gen(ptpqb hrb lbb ubb)

// Overall graph, reference at 5 mg/kg
twoway (rarea lbb ubb ptpqb, sort fcolor(gs13%50) yaxis(1) lcolor(white) lwidth(none)) (line hrb ptpqb, sort lp(solid) yaxis(1)) ,	legend(off) xlabel(0 (1) 15) ylabel(0.5 1 1.5 2 2.5 3 3.5 4 4.5 5, axis(1) angle(horizontal)) xtitle(TQ total dose (mg/kg),  margin(medium)) ytitle(Adjusted hazard ratio, axis(1) margin(medium)) legend(off) graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white)) plotregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white)) saving("TQ spline_cox model_tqmgkgtot.gph", replace)

restore




****Explore relationship between Pk values and outcome
stset dlast180_2, failure (outcome7to180) id(pid) origin(origin180)

*AUC
stcox log_AUC if AMT==300, shared(studysite) //not sig
stcox log_AUC, shared(studysite) //sig

*Adjust for tqmgkgtot & logpara0
stcox tqmgkgtot log_AUC logpara0, shared(studysite) // AUC not sig


*Cmax
stcox cmax if AMT==300, shared(studysite) // sig
stcox cmax, shared(studysite) //sig

*Adjust for tqmgkgtot & logpara0
stcox tqmgkgtot cmax logpara0, shared(studysite) // Cmax not sig


*t1/2
stcox t_12_terminal_rescaled if AMT==300, shared(studysite) //sig
stcox t_12_terminal_rescaled, shared(studysite) //sig

*Adjust for tqmgkgtot & logpara0
stcox tqmgkgtot t_12_terminal_rescaled logpara0, shared(studysite) // sig

*Look at t1/2 by category
summ t_12_terminal_rescaled, detail
hist t_12_terminal_rescaled
egen t_12_5=cut(t_12_terminal_rescaled), group(5)
tab t_12_5
tabstat t_12_terminal_rescaled, by(t_12_5) statistics(min max)

tab  t_12_5 outcome7to180, row
stcox tqmgkgtot i.t_12_5 logpara0, shared(studysite) // sig


/*
*******Generate spline figure for t1/2 ********************
gen tq12 = t_12_terminal_rescaled if t_12_terminal_rescaled>9&t_12_terminal_rescaled<=30
su tq12

// Mean centreing tqmgkgtot
su tqmgkgtot
gen tqmgkgtot_mc = tqmgkgtot - `r(mean)' 
su tqmgkgtot_mc


preserve
// create spline variables for pqmgkgtot
mkspline spl_tq12_4=tq12, cubic nknots(4) di
stcox spl_tq12_4* tqmgkgtot_mc logpara0_mc, shared(studysite)
levelsof tq12, local(tqs)
xblc spl_tq12_41 spl_tq12_42 spl_tq12_43, covname(tq12) at(`tqs') reference(16) eform gen(ptpqb hrb lbb ubb)

// Overall graph, reference at 5 mg/kg
twoway (rarea lbb ubb ptpqb, sort fcolor(gs13%50) yaxis(1) lcolor(white) lwidth(none)) (line hrb ptpqb, sort lp(solid) yaxis(1)) ,	legend(off) xlabel(0 (5) 30) ylabel(0.5 1 1.5 2 2.5 3 3.5 4 4.5 5, axis(1) angle(horizontal)) xtitle(Terminal elimination half-life (days),  margin(medium)) ytitle(Adjusted hazard ratio, axis(1) margin(medium)) legend(off) graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white)) plotregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white)) saving("TQ spline_cox model_t12.gph", replace)

restore
*/


****Explore relationship between metHb and outcome
stset dlast180_2, failure (outcome7to180) id(pid) origin(origin180)

summ day7_mthb
hist day7_mthb
gen logmethb_d7=log10(day7_mthb)

stcox logmethb_d7 if AMT==300, shared(studysite) // sig
stcox logmethb_d7, shared(studysite) //sig

*Adjust for tqmgkgtot & logpara0
stcox tqmgkgtot logmethb_d7 logpara0, shared(studysite) //  ******logmethb_d7 not sig  - AHR 0.78*******
*Adjust for tqmgkgtot & logpara0 & AUC
stcox tqmgkgtot logmethb_d7 log_AUC logpara0, shared(studysite) //  ******logmethb_d7 now sig and AHR 0.4*******
*Adjust for tqmgkgtot & logpara0 & t12
stcox tqmgkgtot logmethb_d7 t_12_terminal_rescaled logpara0, shared(studysite) // ******logmethb_d7  sig and AHR 0.47****
stcox tqmgkgtot c.logmethb_d7##c.t_12_terminal_rescaled logpara0, shared(studysite) // ******significant interaction between t/12 and methb









*******************************************
********Main haemolysis analysis***********
*******************************************
clear all
cd "/Users/robcommons/Dropbox/WWARN Vivax Study Groups/Data/Analysis/TQ"
use "/Users/robcommons/Dropbox/Github/Tafenoquine-efficacy/tq_longitudinal.dta"

gen study="GATHER" if sid=="BSAJK"
replace study="DETECTIVE_Ph3" if sid=="KTMTV"
replace study="DETECTIVE_Ph2" if sid=="PRSXC"

*Generate TQ dose in mg
gen AMT=round(weight*tqmgkgtot,1)
tab AMT

*Merge Pk and methb
merge m:1 pid using "/Users/robcommons/Dropbox/WWARN Vivax Study Groups/Stata do files/Analysis files/TQ/TQ_PK_summaries.dta"
drop if _merge==2
drop _merge
merge m:1 pid using "/Users/robcommons/Dropbox/WWARN Vivax Study Groups/Stata do files/Analysis files/TQ/day_7_mthb.dta"
drop if _merge==2
drop _merge


*Identify if 2 Hb measurements, including one on day 0 are not available
count if hbday0==. & count==1  
// generate a variable with the minimum Hb value after day 0
egen hb2 = min(hb_der) if dayofobs>0, by(pid)
replace hb2=hb2[_n+1] if pid==pid[_n+1] & hb2[_n+1]!=.
order hbday0 hb2 hb_der
// drop if minimum value after day 0 is missing
count if hb2==. & count==1  
br if hb2==. 
gen nofuphb=1 if hb2==.
drop hb2

*Check that everyone assigned Tq has a  dose
tab trt3 //no obs
tab trt2 if count==1, m 
count if trt2=="Tq" & tqmgkgtot==. & count==1 
count if trt2=="Tq" & tqmgkgtot==0 & count==1 
 
codebook sid pid if nofuphb!=1 //3 studies, 836 individuals, only 1 person without follow up Hb

gen weight_5=weight/5
gen cqmgkgtot_5=cqmgkgtot/5
gen age_5=age/5

gen origin180=7
replace origin180=0 if dlast<7

gen tqcat5=0 if trt2!="Tq"
replace tqcat5=1 if tqmgkgtot<3.75&trt2=="Tq"
replace tqcat5=2 if tqmgkgtot>=3.75&tqmgkgtot<6.25
replace tqcat5=3 if tqmgkgtot>=6.25&tqmgkgtot<8.75
replace tqcat5=4 if tqmgkgtot>=8.75&!missing(tqmgkgtot)
label define tqcat5 0 "No TQ" 1 "<3.75mg/kg" 2 "3.75-6.25mg/kg" 3 "6.25-8.75mg/kg" 4 ">=8.75mg/kg"
label values tqcat5 tqcat5

count if missing(g6pda)&!missing(g6pd)&count==1
tab g6pda


	 
***************Generating haem safety variables***************
describe hb_der hbday0
gen float hb= round(hb_der, 0.1)
replace hbday0 = round(hbday0, 0.1)
// did the above as there are some hb values that have a large number of decimal places

* Haemoglobin changes between days 1-14
egen hbmin=min(hb) if dayofobs>=1 & dayofobs<=14, by(pid)
egen hb114=min(hbmin), by(pid)

// day of min Hb between days 1-14
gen hbminday_=dayofobs if hb==hbmin & hb!=. //day on which min hb was measured
egen hbminday=min(hbminday_), by(pid) // first day on which min Hb occurred
drop hbmin hbminday_
tab hbminday if count==1

* percentage decrease in hb per person
bysort pid: gen float hb_pdrop=((hbday0-hb114)/hbday0)*100

* is hb<=7g/dL AND suffered a >=25% drop between days 1-14?
gen hbdrop25=1 if hb_pdrop>=25 & hb_pdrop!=. & hb114<7 
replace hbdrop25=0 if hb_pdrop<25 & hb_pdrop!=.
tab hbdrop25 
tab sid hbdrop25 if count==1  //0 individuals
label values hbdrop25 YesNo
tab tqcat5 hbdrop25 if count==1, row

* >5g/dL drop in haemoglobin between baseline and days 1-14
gen hbdrop5=1 if hbday0-hb114>5 & hbday0!=. & hb114!=. 
replace hbdrop5=0 if hbday0-hb114<5 & hbday0!=. & hb114!=.
tab hbdrop5 if count==1
tab tqcat5 hbdrop5 if count==1, row //1 individual in 3.75-6.25 mg/kg dose cat

* >2g/dL/day fall in haemoglobin between baseline and nadir on days 1 - 14
gen hbdiff = hbday0 - hb114
su hbdiff if count==1
order hbdiff

gen hbdrop_g_per_day= hbdiff/hbminday if count==1
su hbdrop_g_per_day if count==1 & hbdrop_g_per_day!=.
gen hbdroprate_2 = 1 if hbdrop_g_per_day>2 & hbdrop_g_per_day!=.
replace hbdroprate_2 = 0 if hbdrop_g_per_day<=2
label values hbdroprate_2 YesNo
order hbminday hbdrop_g_per_day hbdiff
tab hbdroprate_2 if count==1
tab tqcat5 hbdroprate_2 if count==1, row //10 individuals but no relationship to Tq cat


* Development of mild, moderate or severe anaemia by day 2/3 or day 6+/-1
egen hbday23_ = min(hb_der) if dayofobs>=2 & dayofobs<=3, by(pid)
egen hbday23=min(hbday23_), by(pid)
drop hbday23_

egen hbday678_ = min(hb_der) if dayofobs>=6 & dayofobs<=8, by(pid)
egen hbday678=min(hbday678_), by(pid)
drop hbday678_


* Max absolute reduction in Hb between baseline and days 2/3 and days 5-7
// watch out for regression to mean
gen hbmaxred_day23=hbday0-hbday23  
gen hbmaxred_day678=hbday0-hbday678
gen hbchange_day23 = hbday23-hbday0
gen hbchange_day678= hbday678-hbday0

* Max relative reduction in Hb between baseline and days 2/3 and days 5-7
egen hb23_ = min(hb) if dayofobs>=2 & dayofobs<=3, by(pid)
egen hb23 = min(hb23_), by(pid)
egen hb678_ = min(hb) if dayofobs>=6 & dayofobs<=8, by(pid)
egen hb678 = min(hb678_), by(pid)
drop hb23_ hb678_
gen hbrelred_day23=100-(hb23/hbday0*100)
gen hbrelred_day678=100-(hb678/hbday0*100)


label values hbdrop25 hbdrop5  YesNo


label variable hbdrop25 "Drop in hb of >=25% AND hb below 7 g/dL"
label variable hbdrop5 "Drop in hb of >5 g/dL from baseline between days 1-13"
label variable hbmaxred_day23 "Maximum absolute reduction in Hb: baseline to days 2-3"
label variable hbmaxred_day678 "Maximum absolute reduction in Hb: baseline to day 7"
label variable hb114 "Minimum Hb between days 1-14"
label variable hbmaxred_day23 "Absolute reduction in Hb between day 0 and days 2-3 (g/dL)"
label variable hbmaxred_day678 "Absolute reduction in Hb between day 0 and day 7 (g/dL)"
label variable hbminday "Day of lowest Hb between days 1-13"
label variable hbdrop_g_per_day "Averge drop in Hb in g/dL/day from day 0 to day of lowest Hb between days 1-13"
label variable hbdiff "Difference in Hb from day 0 to day of lowest Hb between days 1-13 (g/dL)"
label variable hb_pdrop "Percentage drop in Hb from day 0 to lowest Hb between days 1-13"
label variable hbdroprate_2 "Hb drop of >2 g/dL/day from day 0 to day of lowest Hb between days 1-13"
label variable hbrelred_day23 "Relative reduction in Hb between day 0 and days 2-3 (%)"
label variable hbrelred_day678 "Relative reduction in Hb between day 0 and day 7 (%)"
label variable hb23 "Lowest Hb on days 2-3"
label variable hb678 "Lowest Hb on day 7"
label variable hbchange_day23 "Change in Hb on days 2-3 relative to day 0"
label variable hbchange_day678 "Change in Hb on day 7 relative to day 0"

* How many hb values do we have per person, including day 0?
//egen id = group(pid)

bysort pid (dayofobs) : gen hbnumobs = sum(!missing(hb_der)) if hbday0!=.
bysort pid: egen hbobs=max(hbnumobs)
tab hbobs tqcat5 if count==1
label variable hbobs "Total number of Hb measurements"


***Look at dayofobs of hb measurements
tab dayofobs tqcat5 if !missing(hb_der)&dayofobs<=14

save "/Users/robcommons/Dropbox/Github/Tafenoquine-efficacy/tq_longitudinal_haem.dta"
keep if count==1

**Look at fall to <5 g/dL
gen hbfall_lt5=1 if hb114<5
replace hbfall_lt5=0 if hb114>=5&!missing(hb114)
tab tqcat5 hbfall_lt5 if count==1, row 


*Look at absolute falls to day 2/3
bysort tqcat5: summ hbchange_day23, detail
*Univariable linear regression
mixed hbchange_day23 tqmgkgtot if count==1 ||studysite: // sig
mixed hbchange_day23 i.tqcat5 if count==1 ||studysite: // sig
*Multivariable linear regression
mixed hbchange_day23 tqmgkgtot age_5 sex logpara0 hbday0 if count==1 || studysite: //  sig
mixed hbchange_day23 i.tqcat5 age_5 sex logpara0 hbday0 if count==1 ||studysite: //sig
lincom 3.tqcat-2.tqcat

/*
 xi: mfp: xtgee hbchange_day23 tqmgkgtot age_5 sex logpara0 hbday0 if count==1, i(studysite)
   est sto model_n
   fracpred  pred4, for(tqmgkgtot) 
   fracpred  pred4_se, for(tqmgkgtot)  stdp
   gen Upper4 = pred4 + 1.96*pred4_se
   gen Lower4 = pred4 - 1.96*pred4_se
   twoway rarea Lower4 Upper4 tqmgkgtot if count==1, sort color(gs8) ||line  pred4  tqmgkgtot  if count==1, sort color(edkblue) ///
           , xscale(range(0 15)) xlabel(0 (2.5) 15) yscale(range(-5 5)) ylabel(-5 (2.5) 5) ytitle("Change in Hb at day 2/3 (g/L)") xtitle("TQ mg/kg") legend(off) graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white)) plotregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white))
*/

*Look at absolute falls to day 5-7
bysort tqcat5: summ hbchange_day678, detail
*Univariable linear regression
mixed hbchange_day678 tqmgkgtot if count==1 ||studysite: // not sig
mixed hbchange_day678 i.tqcat5 if count==1 ||studysite: // not sig
*Multivariable linear regression
mixed hbchange_day678 tqmgkgtot age_5 sex logpara0 hbday0 if count==1 ||studysite: //  sig
mixed hbchange_day678 i.tqcat5 age_5 sex logpara0 hbday0 if count==1 ||studysite: // 3.tqcat5 sig
lincom 3.tqcat-2.tqcat


*AUC
mixed hbchange_day23 tqmgkgtot log_AUC age_5 sex logpara0 hbday0 if count==1 ||studysite: //AUC  sig
mixed hbchange_day678 tqmgkgtot log_AUC age_5 sex logpara0 hbday0 if count==1 ||studysite: //AUC and tqmgkgtot sig

*Cmax
mixed hbchange_day23 tqmgkgtot cmax age_5 sex logpara0 hbday0 if count==1 ||studysite: //cmax not  sig
mixed hbchange_day678 tqmgkgtot cmax age_5 sex logpara0 hbday0 if count==1 ||studysite: //cmax not sig

*look at methb
gen logmethb_d7=log10(day7_mthb)
mixed hbchange_day23 tqmgkgtot logmethb_d7 age_5 sex logpara0 hbday0 if count==1  ||studysite: //sig methb (not tqmg/kg)
mixed hbchange_day23 tqmgkgtot day7_mthb age_5 sex logpara0 hbday0 if count==1  ||studysite: //sig methb (not tqmg/kg)

mixed hbchange_day678 tqmgkgtot logmethb_d7 age_5 sex logpara0 hbday0 if count==1  ||studysite: //sig methb (not tqmg/kg)

*look at t12
mixed hbchange_day23 tqmgkgtot t_12_terminal_rescaled age_5 sex logpara0 hbday0 if count==1  ||studysite: //sig t1/2 (not tqmg/kg)
mixed hbchange_day678 tqmgkgtot t_12_terminal_rescaled age_5 sex logpara0 hbday0 if count==1  ||studysite: //almost sig t1/2 (not tqmg/kg)


*look at t12 and methb
mixed hbchange_day23 tqmgkgtot t_12_terminal_rescaled logmethb_d7 age_5 sex logpara0 hbday0 if count==1  ||studysite: //sig t1/2 and methb (not tqmg/kg)
mixed hbchange_day678 tqmgkgtot t_12_terminal_rescaled logmethb_d7 age_5 sex logpara0 hbday0 if count==1  ||studysite: // sig methb (not t1/2 or tqmg/kg)

*look at t12 and methb interaction
mixed hbchange_day23 tqmgkgtot c.logmethb_d7##c.t_12_terminal_rescaled age_5 sex logpara0 hbday0 if count==1  ||studysite: //interaction not sig
mixed hbchange_day678 tqmgkgtot c.logmethb_d7##c.t_12_terminal_rescale age_5 sex logpara0 hbday0 if count==1  ||studysite: // interaction not sig




***Look at risk of recurrence with haemolysis
stset dlast180_2, failure (outcome7to180) id(pid) origin(origin180)
*Adjust for tqmgkgtot & logpara0 & hbday0
stcox tqmgkgtot hbday0 logpara0 hbchange_day23, shared(studysite) // hbchange not sig
stcox tqmgkgtot hbday0 logpara0 hbchange_day678, shared(studysite) // hbchange not sig



********Generate linear mixed effects models for +/-TQ 
clear all
cd "/Users/robcommons/Dropbox/WWARN Vivax Study Groups/Data/Analysis/TQ"
use "/Users/robcommons/Dropbox/Github/Tafenoquine-efficacy/tq_longitudinal_haem.dta", replace
gen tqcat2=tqcat5
replace tqcat2=1 if tqcat5>0&!missing(tqcat5)
fracpoly, degree(3) noscaling center(no) compare: regress hb dayofobs if dayofobs<=42
gen tq1_1 = tqcat2*Idayo__1
gen tq1_2 = tqcat2*Idayo__2
gen tq1_3 = tqcat2*Idayo__3

xtmixed hb tqcat2 Idayo__1 Idayo__2 Idayo__3  tq1_1 tq1_2 tq1_3  age sex logpara0  if dayofobs<=42||sid:|| pid: Idayo__1 Idayo__2 Idayo__3  , var
egen daygraph10pq = cut (dayofobs), at (0 (1) 42)
sort dayofobs daygraph10pq
preserve
adjust  age sex logpara0 if e(sample), by(daygraph10pq tqcat2) se ci  replace
gen xb_10pq = xb
gen lb_10pq = lb
gen ub_10pq = ub
twoway (line xb_10pq daygraph10pq if tqcat2==0)(line xb_10pq daygraph10pq if tqcat2==1)
twoway  (rarea ub_10pq lb_10pq daygraph10pq if tqcat2==1, fcolor("147 30 17%50") fintensity(50) lcolor(white) lwidth(none)) (line xb_10pq daygraph10pq if tqcat2==1, lcolor("147 30 17") lwidth(thick) lpattern(solid)) (rarea ub_10pq lb_10pq daygraph10pq if tqcat2==0, fcolor("0 96 0%50") fintensity(50) lcolor(white) lwidth(none)) (line xb_10pq daygraph10pq if tqcat2==0, lcolor("0 96 0") lwidth(thick) lpattern(solid))  , ytitle(Haemoglobin (g/dL)) ytitle(, margin(medium)) ylabel(, nogrid) ymtick(, nogrid) xtitle(Day of observation) xtitle(, margin(medium)) xlabel(0 (7) 42) legend(on order(2 "TQ" 4 "No TQ") bmargin(medium) colfirst notextfirst nostack cols(1) size(small) nobox region(fcolor(white) margin(zero) lcolor(white)) position(4) ring(0)) graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white)) plotregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white)) saving("fracypoly_day42.gph", replace)


*Generate linear mixed effects models for +/-TQ 
clear all
cd "/Users/robcommons/Dropbox/WWARN Vivax Study Groups/Data/Analysis/TQ"
use "/Users/robcommons/Dropbox/Github/Tafenoquine-efficacy/tq_longitudinal_haem.dta", replace
gen tqcat2=tqcat5
replace tqcat2=1 if tqcat5>0&!missing(tqcat5)
fracpoly, degree(3) noscaling center(no) compare: regress hb dayofobs if dayofobs<=90
gen tq1_1 = tqcat2*Idayo__1
gen tq1_2 = tqcat2*Idayo__2
gen tq1_3 = tqcat2*Idayo__3

xtmixed hb tqcat2 Idayo__1 Idayo__2 Idayo__3  tq1_1 tq1_2 tq1_3  age sex logpara0  if dayofobs<=90||sid:|| pid: Idayo__1 Idayo__2 Idayo__3  , var
egen daygraph10pq = cut (dayofobs), at (0 (1) 90)
sort dayofobs daygraph10pq
preserve
adjust  age sex logpara0 if e(sample), by(daygraph10pq tqcat2) se ci  replace
gen xb_10pq = xb
gen lb_10pq = lb
gen ub_10pq = ub
twoway (line xb_10pq daygraph10pq if tqcat2==0)(line xb_10pq daygraph10pq if tqcat2==1)
twoway  (rarea ub_10pq lb_10pq daygraph10pq if tqcat2==1, fcolor("147 30 17%50") fintensity(50) lcolor(white) lwidth(none)) (line xb_10pq daygraph10pq if tqcat2==1, lcolor("147 30 17") lwidth(thick) lpattern(solid)) (rarea ub_10pq lb_10pq daygraph10pq if tqcat2==0, fcolor("0 96 0%50") fintensity(50) lcolor(white) lwidth(none)) (line xb_10pq daygraph10pq if tqcat2==0, lcolor("0 96 0") lwidth(thick) lpattern(solid))  , ytitle(Haemoglobin (g/dL)) ytitle(, margin(medium)) ylabel(, nogrid) ymtick(, nogrid) xtitle(Day of observation) xtitle(, margin(medium)) xlabel(0 (10) 90) legend(on order(2 "TQ" 4 "No TQ") bmargin(medium) colfirst notextfirst nostack cols(1) size(small) nobox region(fcolor(white) margin(zero) lcolor(white)) position(4) ring(0)) graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white)) plotregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white)) saving("fracypoly_day90.gph", replace)



