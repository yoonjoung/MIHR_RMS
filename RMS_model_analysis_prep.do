*THIS DO FILE DOES THE FOLLOWING: 
*(1) check/scan the dataset from Ben. 
*(2) exploratory data analysis 

*Find "QUESTION" throughout the do file. Need to resolve these. 		
*Find "CONFIRM" throughout the do file. Check the results during data analysis. 		
			
* Table of Contents
* A. SETTING 
* B. RUN ASSOCIATED DO FILES 
* C. SCAN DATA
*** C.1 Check id var and duplicates 
*** C.2 Import/merge sampling weight
*** C.3 Check var by section
*** C.4 Check key variables 
* D. CREATE ANALYSIS VARIABLES 
*** D.1 Background, Modules 2 & 4 demographic characteristics
*** D.2 Background, Module 3 household wealth 
*** D.3 Module 6 Resilience
*** D.4 Modeul 7 Aspiration 
*** D.5 Module 9 Likelihood to be affected by shoks - perceived vulnerability 
*** D.6 Module 10 Resources 
*** D.7 Module 11 Shock 
*** D.8 Module 12 Health shock 
*** D.9 Module 12 Health shock coping 
*** D.10 Module 14 Assistance 
*** D.11 Module 17 Maternal diet
* E. SAVE ROUND 1 DATA 
* F. CREATE AND SAVE ROUND 2 MOCK DATA
*** F.1 Select 80% of round 1 sample randomly 
*** F.2 Change time-varying variables randomly 
*** F.3 Save round 2 MOCK data 

clear
clear matrix
clear mata
capture log close
set more off
numlabel, add

************************************************************************
* A. SETTING 
************************************************************************

global maindir "~/Dropbox/0iSquared/iSquared_MIHR/RMS_Data_Analysis/"
global datadir "~/Dropbox/0iSquared/iSquared_MIHR/RMS_Data_Analysis/From_Ben/"

cd $datadir
dir /*all files from Ben*/

cd $maindir
dir /*check associated do files*/

************************************************************************
* B. RUN ASSOCIATED DO FILES 
************************************************************************

do RMS_model_analysis_samplingweight.do

************************************************************************
* C. SCAN DATA
************************************************************************

use "$datadir/MIHR_RMS_Baseline_Cleaned_Dataset.dta", clear

	rename *, lower	
	
*** C.1 Check id var and duplicates 
{
		d, short
		lookfor id
		codebook number formid case_id
		
		duplicates tag case_id, gen(duplicate) 
			drop duplicate
}
*** C.2 Import sampling weight
{	
	* Check cluster id variables 
		lookfor cluster
		lookfor village
		d m1q*
		codebook m1q7 m1q8 m1q9 m1q10
		/* 
		QUESTION: 
		Need to find unique cluster id or combination - see below _merge tabulation 
			- In the main dataset the village (m1q8) has 64 unique values 
			- In the sampling excel sheet there are only 63 unique villeages. 
				But, combination of HealthFacilityA + Village is unique
				FYI, combination of HealthZone + Village is NOT unique
		For now, we just replace/borrow from the previous cluster 
		*/
	
	* Merge with the sampling weight dataset, created in RMS_model_analysis_samplingweight.do
		gen village = m1q8
		sort village 
		
		d, short
		merge village using RMS_cluster_samplingweight.dta, keep(weight*)
			tab _merge, m 
			
			/*
			CONFIRM: 
			There should be only _merge==3 
			i.e., There should be no missing sampling weight*/
				drop if _merge==2
				replace weight = weight[_n-1] if weight==.
				drop _merge
			
			histogram weight, w(0.05) start(0) xline(1) normal
			histogram weight2, w(0.05) start(0) xline(1) normal
}
*** C.3 check var by section
{
		local num = 1
		while `num' <=18 {
			d m`num'q*
			local num = `num' + 1
		}	
		
		* check variables that do not follow quesionnaire numbers
		* Is there a variable for interview results? 
		preserve
		drop m*q*
		d, short
		d
		restore
}
*** C.4 Check key variables 
{
	/*
	Here are a few simple examples you could consider:

	Association between total shocks (shocks_total) [continuous] and 
	has social groups to go to in time of crises (m10q17) [categorical]

	Association between total health shocks (healthshocks_total) [continuous] and 
	Ability to Recover from health shocks (Health_ATR) [continuous] 
	*/

	lookfor shock
	
	d m10q*
	codebook m10q17		
	
	d m11q*
	codebook m10q17		
}
************************************************************************
* D. CREATE ANALYSIS VARIABLES 
************************************************************************

*** D.1 Background, Modules 2 & 4 demographic characteristics
{
	* Age
		gen age=m2q2
		egen agegroup5 = cut(m2q2), at(15,20,25,30,35,40,45,50)
		lab var age "woman's age at interview (years)" 
		lab var agegroup5 "woman's age at interview (5-year group)" 
		
	* Education 
		gen read = m2q4==1 
		gen eduany = m2q5>=2 & m2q5<=6
		gen edupri = m2q5>=3 & m2q5<=6
		gen edusec = m2q5>=4 & m2q5<=6
		lab var read "able to read"
		lab var eduany "attended any school"
		lab var edupri "completed primary school"
		lab var edusec "completed secondary school"
	
	* Household size
		gen hhsize = m4q1_female + m4q1_male 
			histogram hhsize, normal start(1) w(1)
			sum hhsize
		lab var hhsize "Houshold size, total"
		
	* Number of children living together
		gen numbiochild_together = m4q3
		gen numallchild_together = m4q3 + m4q5  
		lab var numbiochild_together "number of biologic children, living together"
		lab var numallchild_together "number of all children, living together"
		
	* Age of youngest child 
		gen agechild = m4q4_months 
		lab var agechild "child's age at interview (months)" 
}	
*** D.2 Background, Module 3 household wealth 
{	
	* Prepare wealth variables for PCA
		gen temprooms = m3q2

		foreach var of varlist m3q3 m3q4 m3q5 {
			gen byte tempcondition_10`var' = `var'>=11 & `var'<=19
			gen byte tempcondition_20`var' = `var'>=21 & `var'<=29
			gen byte tempcondition_30`var' = `var'>=31 & `var'<=39
			gen byte tempcondition_40`var' = `var'>=31 & `var'<=39
		}

		#delimit; 
		global varlistasset "
			m3q9_tv
			m3q9_fridge
			m3q10_watch
			m3q10_bike
			m3q10_moto
			m3q10_car
			m3q10_boat
			m3q11
			m3q12
			m3q13
			m3q14
			m3q16
			m3q18
			"
		;
		#delimit cr
		foreach var of varlist $varlistasset{
			gen byte temphave`var' = `var'>=1 & `var'<=3
		}
				
		#delimit cr
		foreach var of varlist m3q19{
			gen byte tempcooking`var'_1 = `var'==1
			gen byte tempcooking`var'_2 = `var'==2
		}
		
		foreach var of varlist m3q20 m3q21{
			gen byte tempwater_10`var' = `var'>=11 & `var'<=19
			gen byte tempwater_20`var' = `var'>=21 & `var'<=29
			gen byte tempwater_30`var' = `var'>=31 & `var'<=39
			gen byte tempwater_40`var' = `var'>=41 & `var'<=49
			gen byte tempwater_50`var' = `var'>=51 & `var'!=. 
		}		
		
		foreach var of varlist m3q26{
			gen byte temptoilet_10`var' = `var'>=11 & `var'<=19
			gen byte temptoilet_20`var' = `var'>=21 & `var'<=22
			gen byte temptoilet_23`var' = `var'>=23 & `var'<=22
		}				
		
		sum temp*				
		
	* Create index using PCA, quintiles, and tertiles 
		pca temp* [aweight = weight], means
		/*
		CONFIRM: pca results. revise the asset items as needed
		*/
		predict wealthscore
		xtile wealthquintile=wealthscore [pweight=weight], nq(5)
		xtile wealthtertile =wealthscore [pweight=weight], nq(3)
		lab var wealthscore "household wealth index"
		lab var wealthquintile "household wealth index quintile"
		lab var wealthtertile "household wealth index tertile"
		
		sum wealth*
		drop temp*
}
*** D.3 Module 6 Resilience 
{	
	* Prepare individual resilience variables, including recoding - the higher score, the better
		foreach var of varlist m6q1 m6q3 m6q5 m6q7{
			gen res_`var' = `var'
			recode res_`var' (1=5) (2=4) (4=2) (5=1) 
		}
		
		foreach var of varlist m6q2 m6q4 m6q6{
			gen res_`var' = `var'
		}
	
	* Create resilience score by simple sum 
		egen resiscore = rowtotal(res_*) 
			histogram resiscore, start(0) w(1) 		
		lab var resiscore "Resilience score (higher, better)"
		
	* Create tertile? 
		xtile resitertile =resiscore [pweight=weight], nq(3)
		lab var resitertile "Resilience score tertile"
}
*** D.4 Modeul 7 Aspiration
{	
	* Prepare individual aspiration variables, including recoding - the higher score, the better
		foreach var of varlist m7q3 m7q4{
			gen asp_`var' = `var'
			recode asp_`var' (1=5) (2=4) (4=2) (5=1) 
		}
		
		foreach var of varlist m7q1 m7q2{
			gen asp_`var' = `var'
			
		}
	
	* Create aspiration score by simple sum 		
		egen aspiscore = rowtotal(asp_*) 
			histogram aspiscore, start(0) w(1) 		
		lab var aspiscore "Aspiration score (higher, better)"
	
	* Create tertile? 		
		xtile aspitertile =aspiscore [pweight=weight], nq(3)
		lab var aspitertile "Aspiration score tertile"
}
*** D.5 Module 9 Likelihood to be affected by shoks - perceived vulnerability 
{
	* Prepare individual resilience variables, including recoding 
		foreach var of varlist m9q21 m9q22 m9q23 m9q24{
				tab `var', m
		}	
				/*
				QUESTION:
				check coding for these variabled. 
				None has "very likely" - likely data cleaning error 
				*/
		
		foreach var of varlist m9q21 m9q22 m9q23 m9q24{
			gen pvul_`var' = .
				replace pvul_`var' = 4 if `var' =="very_likely" 
				replace pvul_`var' = 3 if `var' =="likely"
                replace pvul_`var' = 2 if `var' =="unlikely"
                replace pvul_`var' = 1 if `var' =="very_unlikely"
		}
		
		sum pvul_*
		
	* Create aspiration score by simple sum 
		egen pvulscore = rowtotal(pvul_*) 
			histogram pvulscore, start(0) w(1)
 		/*the higher score, the more perceived to be vulnerable*/
		lab var pvulscore "Perceived vulnerability score (higher, more likely affected)"
		
	* Create tertile? 	
		xtile pvultertile =pvulscore [pweight=weight], nq(3)
		lab var pvultertile "Perceived vulnerability score tertile"

	* Check correlation between all scores, including wealth score? 	
		pwcorr *score, sig obs
		pwcorr *tertile, sig obs
}		
*** D.6 Module 10 Resources 
{ 
	* Number of groups that she belongs to 
		egen groupnum = rowtotal (m10q1 - m10q16)
		lab var groupnum "Number of groups she/HH belongs to"
			sum groupnum
			histogram groupnum, start(0) w(1)
		
	* Would go to the groups in a crisis
		gen scapital = m10q17==1
		lab var scapital "would go to the groups for help in crisis"
			histogram groupnum, start(0) w(1) by(scapital) freq
}
*** D.7 Module 11 Shock 
{	
	* Find and define shock variables
	
		#delimit; 		
		global varlistshock_env "
			m11q1_excrain
			m11q1_drought
			m11q1_hail
			m11q1_landslide
			m11q1_earthquake
			m11q1_fires
			m11q1_valcano
			m11q1_fires1
			";
		global varlistshock_bio "	
			m11q1_cropdisease
			m11q1_croppest
			m11q1_livestdisease
			m11q1_humandisease
			";
		global varlistshock_conf "
			m11q1_theftmoney
			m11q1_theftcrops
			m11q1_theftassets
			m11q1_theftlivestock
			m11q1_violencehouse
			m11q1_violencecomm
			m11q1_strikes
			m11q1_rape
			m11q1_conflictfodderanim
			m11q1_conflictwateranim
			m11q1_relocation
			m11q1_insecurity
			";
		global varlistshock_eco "
			m11q1_foodprices
			m11q1_unavaillivestock
			m11q1_incpriceslivestock
			m11q1_demandlivestock
			m11q1_decpriceslivestock
			m11q1_workaccid
			m11q1_lostland
			m11q1_jobloss
			m11q1_youthunempl
			m11q1_emigrationhouse
			";
		global varlistshock_dem "
			m11q1_spousedeath
			m11q1_childdeath
			m11q1_otherhousedeath
			m11q1_nonhousefamdeath
			m11q1_someoneelsedeath
			m11q1_divorce
			";	
		global varlistshock_death "
			m11q1_spousedeath
			m11q1_childdeath
			m11q1_otherhousedeath
			";				
		#delimit cr	
		
		sum $varlistshock_env
		sum $varlistshock_bio
		sum $varlistshock_conf
		sum $varlistshock_eco
		sum $varlistshock_dem
		
	* Number of shocks and binary experience of shock by type 
				
		egen numshock_env = rowtotal($varlistshock_env)
		gen byte shock_env = numshock_env >=1 & numshock_env!=.
		
		egen numshock_bio = rowtotal($varlistshock_bio)
		gen byte shock_bio = numshock_bio >=1 & numshock_bio!=.
		
		egen numshock_conf = rowtotal($varlistshock_conf)
		gen byte shock_conf = numshock_conf >=1 & numshock_conf!=.
		
		egen numshock_eco = rowtotal($varlistshock_eco)
		gen byte shock_eco = numshock_eco >=1 & numshock_eco!=.
		
		egen numshock_dem = rowtotal($varlistshock_dem)
		gen byte shock_dem = numshock_dem >=1 & numshock_dem!=.
				
		egen numshock_death = rowtotal($varlistshock_death)
		gen byte shock_death = numshock_death >=1 & numshock_death!=.	
		
		egen numshock_health = rowtotal($varlistshock_death m11q1_humandisease)
		gen byte shock_health = numshock_health >=1 & numshock_health!=.	
		
		egen numshock_eco2 = rowtotal($varlistshock_eco m11q1_someoneelsedeath)
		gen byte shock_eco2 = numshock_eco2 >=1 & numshock_eco2!=.

		egen numshock_any = rowtotal(m11q1_*)
			histogram numshock_any, start(0) w(1) 
		gen byte shock_any = numshock_any >=1 & numshock_any!=.
		
		lab var shock_env "has exprienced shock, environment"
		lab var shock_bio "has exprienced shock, biologic"
		lab var shock_conf "has exprienced shock, conflict"
		lab var shock_eco "has exprienced shock, economic"
		lab var shock_dem "has exprienced shock, demographic events"
		lab var shock_death "has exprienced shock, death"
		lab var shock_health "has exprienced shock, death or health"
		lab var shock_eco2 "has exprienced shock, economic (v2)"
		lab var shock_any "has exprienced shock, any type"
		
		tab *_any, m
}
*** D.8 Module 12 Health shock 
{	
	* Find and define health shock variables
		d m12q1_*	
		sum m12q1_*	
		
		#delimit; 		
		global varlisthealthshock "
			m12q1_illspouse
			m12q1_illchild
			m12q1_illmember
			m12q1_illself
			m12q1_illother
			m12q1_foodsecurity
			m12q1_foodprices
			m12q1_injurychild
			m12q1_injuryother
			m12q1_unpreg
			m12q1_losspreg
			m12q1_gbv
			m12q1_other
			";
		#delimit cr	
		
		sum $varlisthealthshock
		
	* Number of health shocks and binary experience of health shock 
				
		egen numhealthshock = rowtotal($varlisthealthshock)
			histogram numhealthshock, start(0) w(1) 
		gen byte healthshock_any = numhealthshock >=1 & numhealthshock!=.
		lab var healthshock_any "has experienced health shock, any type in module 12"
}
*** D.9 Module 12 Health shock coping
{	
	* Find and define health shock coping variables
		d m12q5_*	
		
		*** Check and rename string variables for easy data management
		d m12q5_*_other
		codebook m12q5_*_other /*Only a small number of responses => ignore for now*/
		rename (m12q5_*_specify_*) (x12q5_*_specify_*) 
		d x12q5_*
				
		d m12q5_* /*CONFIRM: there is no string now*/	
				
		#delimit; 		
		global varlistcopinghealth "
			m12q5_*_c
			m12q5_*_e
			m12q5_*_h
			m12q5_*_l
			m12q5_*_p
			m12q5_*_q
			m12q5_*_r
			m12q5_*_s
			m12q5_*_t
			m12q5_*_u
			m12q5_*_v
			m12q5_*_w
			m12q5_*_x
			m12q5_*_y
			m12q5_*_aa
			m12q5_*_bb
			m12q5_*_cc
			m12q5_*_dd
			m12q5_*_ee			
			";
		#delimit cr	
		/*
		QUESTION:
		I intend to have a list of "positive practices" that are good for health/nutrition.
		But it should be revised per local context.
		*/
		
		sum $varlistcopinghealth
		
	* Number of coping strategies used: any vs. "good/healthy" 
				
		egen numcopingany = rowtotal(m12q5_*)
			histogram numcopingany, start(0) w(1) 
		gen byte coping_any = numcopingany >=1 & numcopingany!=.
		lab var coping "has used any coping strategies"
		
		egen numcopingpositive = rowtotal($varlistcopinghealth)
			histogram numcopingpositive, start(0) w(1) 
		gen byte coping_positive = numcopingpositive >=1 & numcopingpositive!=.
		lab var coping_positive "has used positive coping strategies"
		
		sum coping*
		
	* check against any experience of healthsock	
		bysort healthshock_any: sum coping*
		tab healthshock_any coping_positive, m chi row
}
*** D.10 Module 14 Assistance 
{	
	* Find and define assistance variables
		d m14q*
		bysort m14q1: sum m14q2*
		bysort m14q3: sum m14q4*
		bysort m14q5: sum m14q6*
	
		*** Check and rename string variables for easy data management
		d m14q*otheraid
		codebook m14q*otheraid /*Only a small number of responses => ignore for now*/
		rename (m14q*otheraid) (x14q*otheraid) 
		d m14q*
		sum m14q*
		
	* Receit of aid by source		
		egen numaidgov = rowtotal(m14q2*)
		egen numaidngo = rowtotal(m14q4*)
		egen numaidfam = rowtotal(m14q6*)
				
		global aidlistsource "gov ngo fam"
		foreach item in $aidlistsource{	
			gen aid`item' = numaid`item'>=1 & numaid`item'!=. 	
			}	
		egen aidany = rowmax(aidgov aidngo aidfam)	
		lab var aidgov "has received aid from government"
		lab var aidngo "has received aid from NGO"
		lab var aidfam "has received aid from family/friends/others"
		lab var aidany "has received aid from any sources"		
		
	* Receit of aid by type
		#delimit; 		
		global aidlisttype "
			financial
			foodaid
			foodchild
			medicine
			contracept
			water
			soap
			other	
			";
		#delimit cr			
		foreach item in $aidlisttype{	
			egen temp = rowtotal(m14q2_m14q2_`item' ///
								 m14q4_m14q4_`item' ///
								 m14q6_m14q6_`item') 
			gen aid_`item' = temp>=1 & temp!=. 	
			drop temp
			}
		lab var aid_financial "has received aid, financial"	
		lab var aid_foodaid "has received aid, foodaid"	
		lab var aid_foodchild "has received aid, foodchild"	
		lab var aid_medicine "has received aid, medicine"	
		lab var aid_contracept "has received aid, contracept"	
		lab var aid_water "has received aid, water"	
		lab var aid_soap "has received aid, soap"	
		lab var aid_other "has received aid, other"	
			
		sum aid*	
}		
*** D.11 Module 17 Maternal diet
{
	* Review maternal diet variables
		d m17q*
		sum m17q*
		
	* Create maternal food score by simple sum 
		egen matdietscore = rowtotal(m17q*)
		lab var matdietscore "Maternal diet score (higher, better)"
	
	* Create tertile? 		
		xtile matdiettertile =matdietscore [pweight=weight], nq(3)
		lab var matdiettertile "Maternal diet score tertile"		
}
************************************************************************	
* E. SAVE ROUND 1 DATA 
************************************************************************	

	gen round = 1 /*Baseline*/

save RMS_round1.dta, replace 

************************************************************************	
* F. CREATE AND SAVE ROUND 2 MOCK DATA
************************************************************************	

*** F.1 Select 80% of round 1 sample randomly 
	
		d, short
	
	* Randomly select 80% of observations
		set seed 38
		sample 80	
		d, short
		
	* Drop variables that are collected only in round 1
		drop m2* m3* m4* m5* m6* m7* m8* m9* m10*
		drop age - scapital
	
	* Drop process variables for now 
		drop num*
	
*** F.2 Change time-varying variables randomly - only new analysis/constructed variables
		
	* Change round
		replace round = 2 /*Round 2 or first follow-up*/
		
	* Module 11 Shock 
		sum shock*
		drop shock_any 
		
		set seed 11
		capture drop random
		generate random = runiform()
		foreach var of varlist shock_* {
			recode `var' (0=1) (1=0) if random<=0.2
		}
				
		egen shock_any = rowmax(shock_env shock_bio shock_conf shock_eco shock_dem)
			
		sum shock*
		
	* Module 12 Health shock 
	* Module 12 Health shock coping 
		sum healthshock coping*
		
		set seed 12
		capture drop random
		generate random = runiform()
		foreach var of varlist healthshock_any {
			recode `var' (0=1) (1=0) if random<=0.2
		}		
		
		foreach var of varlist coping_positive {
			recode `var' (0=1) (1=0) if random<=0.2
			replace `var' =0 if healthshock_any==0
		}				
		
	* Module 14 Assistance 
		sum aid*
		drop aidany
		
		set seed 14
		capture drop random
		generate random = runiform()
		foreach var of varlist aidgov aidngo aidfam {
			recode `var' (0=1) (1=0) if random<=0.2
		}		
		egen aidany = rowmax(aidgov aidngo aidfam)
		
		foreach var of varlist aid_* {
			recode `var' (0=1) (1=0) if random<=0.2
			replace `var' =0 if aidany==0
		}		
				
	* Module 17 Maternal diet	
		sum matdiet*
		drop matdiettertile
		
		set seed 17
		capture drop random
		generate random = runiform()
			replace matdietscore = matdietscore - 1 if random>0 & random<=0.1
			replace matdietscore = matdietscore + 1 if random>0.1 & random<=0.2
			replace matdietscore = matdietscore - 2 if random>0.2 & random<=0.3
			replace matdietscore = matdietscore + 2 if random>0.3 & random<=0.4
			replace matdietscore = 0 if matdietscore<0
			
		sum matdietscore
		
		xtile matdiettertile =matdietscore [pweight=weight], nq(3)

		capture drop random
		
*** F.3 Save round 2 MOCK data 
	
save RMS_round2.dta, replace 
	
***CLEAN UP***

local datafiles: dir "$maindir" files "temp*.*"

foreach datafile of local datafiles {
        rm `datafile'
}

*END OF DO FILE
