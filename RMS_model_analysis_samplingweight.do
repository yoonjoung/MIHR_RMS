*THIS DO FILE CREATES SAMPLING WEIGHTS FOR THE RMS BASELINE SURVEY.  

*OUTPUT
*	1. RMS_cluster_samplingweight.dta: 
*			sampling weights for HH/respondents in each cluster 
*	2. merge_issue_beni_example.dta: 
*			illustrative example of the ID/merge issue - using "Beni" healthzone 
*			(Section B.3)
						
*Find "QUESTION" throughout the do file		
*Find "TEMPORARY FIX" 
			
* Table of Contents
* A. SETTING 
*** A.1 Study design 
* B. Scan worksheets 
*** B.1 Check worksheets in sampling weight excel file
*** B.2 Check worksheets in HH selection excel file from Nancy (Sep 27, 2023)
*** B.3 Illustrative example of the ID/merge issue - using "Beni" healthzone 
* C. Calculate sampling weights   
*** C.1 Get total population size from sheet3 
*** C.2 Calculate or import response rates in each cluster 	
*** C.3 Import probability of selection for households in each sampled clusters - separate file from Nancy	
*** C.4 Calculate probability of selection for clusters in sheet5 
*** C.5 Export the sampling weight to merge with the main dataset 

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
global datadir "~/Dropbox/0iSquared/iSquared_MIHR/RMS_Data_Analysis/From_Ben_Nancy/"

cd $datadir
dir /*all files from Ben and Nancy*/	

cd $maindir
dir /*check associated do files*/

*** A.1 STUDY DESIGN 

global clustersize 64 /*Number of clusters*/
global takesize 25 /*Number of households in a sampled cluster*/
global averagehhsize 6.5 /*Average household size in the study population, from the data*/

************************************************************************
* B. Scan worksheets 
************************************************************************

*** B.1 Check worksheets in sampling weight excel file
{
import excel "$datadir/DRC RMS Community Sampling and Weights.xlsx", describe
return list

	global sheet1 "`r(worksheet_1)'"
	global sheet2 "`r(worksheet_2)'"
	global sheet3 "`r(worksheet_3)'"
	global sheet4 "`r(worksheet_4)'"
	global sheet5 "`r(worksheet_5)'"
	global sheet6 "`r(worksheet_6)'"

import excel "$datadir/DRC RMS Community Sampling and Weights.xlsx", sheet($sheet1) firstrow clear
	d, short	
	d 
	codebook Vil ClusterID /*63 unique village names + 64 unique  numeric ClusterID*/
	
	* Find cluster ID information, since the dataset does not have a clear cluster ID 
		sort Vil
		gen byte temp = Vil ==Vil[_n-1]
		tab temp, m
		egen same=max(temp) , by(Vil)
		tab same, m
		list if same==1

		gen dummy = "_"
		egen clusterunique = concat(HealthFacilityAiredesante dummy Village) 
		list in f/5
		codebook clusterunique
		/* same village name possible, but combination of HealthFacilityA + Village */
				
import excel "$datadir/DRC RMS Community Sampling and Weights.xlsx", sheet($sheet2) firstrow clear
	d, short		
	d
	codebook Vil

import excel "$datadir/DRC RMS Community Sampling and Weights.xlsx", sheet($sheet3) firstrow clear
	d, short		
	d
	codebook Vil

import excel "$datadir/DRC RMS Community Sampling and Weights.xlsx", sheet($sheet4) firstrow clear	
	d, short		
	d
	codebook Village ClusterID Clusterssampled
	
	keep if Clusterssampled!=.
	codebook Village ClusterID /*63 unique village names + 64 unique  numeric ClusterID*/
		
	* Confirm combination of HealthFacilityAiredesante + Village is unique
		gen dummy = "_"
		egen clusterunique = concat(HealthFacilityAiredesante dummy Village) 
		egen clusterunique2 = concat(HealthZone dummy Village) 
		list in f/5
		codebook clusterunique*
						
import excel "$datadir/DRC RMS Community Sampling and Weights.xlsx", sheet($sheet5) firstrow clear	
	d, short		
	d
	codebook Vil ClusterID /*63 unique village names + 64 unique  numeric ClusterID*/
	
	* Confirm combination of HealthFacilityA + Village is unique
		gen dummy = "_"
		egen clusterunique = concat(HealthFacilityAiredesante dummy Village) 
		list in f/5
		codebook clusterunique
		
		sum
		sum Prob* Overall, detail 

import excel "$datadir/DRC RMS Community Sampling and Weights.xlsx", sheet($sheet6) firstrow clear	
	d, short		
	d	
}
*** B.2 Check worksheets in HH selection excel file from Nancy (Sep 27, 2023)
{
import excel "$datadir/RMS Baseline -HH Sampling Distribution by EA.xlsx", describe
return list 

import excel "$datadir/RMS Baseline -HH Sampling Distribution by EA.xlsx", firstrow clear	
	d, short		
	sum
	
	sort Community
	list HealthZone Community No* if  NoofeligibleSampledHousehol!=25
		/*
			 +-------------------------------------------------------------+
			 | Health~e     CommunityName   Noofho~m   Noofel~a   Noofel~l |
			 |-------------------------------------------------------------|
		  2. | MABALAKO             BINGO        197         59         23 |
		 12. |     BENI   CELLULE KASANGA        362         80         49 |
		 30. | MAMBINGI          KITSANGA         50         27         24 |
		 47. | MABALAKO             NGOYO         35         22         22 |
		 54. | MABALAKO             SENGA        237         31         23 |
			 +-------------------------------------------------------------+
		*/	
}
*** B.3 Illustrative example of the ID/merge issue - using "Beni" healthzone 
{	
	/*
	The HH selection worksheet also has ID issues. 
	Using clusters in "Beni" health zone, the following illustrates 
		the merge problem across the three files.
	*/

/*1. HOUSEHOLD SELECTION WORKSHEET*/	
import excel "$datadir/RMS Baseline -HH Sampling Distribution by EA.xlsx", firstrow clear	
	rename *, lower
	
	* Check the unique ID var in the worksheet*/
		unique communityname 
	
	* Change string to lowercase 
		foreach var of varlist healthzonename village communityname{
			replace `var' = lower(`var')
		}
	
	* Prepare for merge
		keep if regexm(healthzonename, "beni")==1
		keep sn healthzone village communityname
		rename (*) (hh_*)
		
		gen village = hh_communityname
		sort village
		save temp_hh.dta, replace

/*2. SAMPLING WEIGHT WORKSHEET*/		
import excel "$datadir/DRC RMS Community Sampling and Weights.xlsx", sheet($sheet5) firstrow clear
	rename *, lower
	
	* Check the unique ID var in the worksheet*/
		unique clusterid  /*===>unique*/
		unique healthfacility village /*===>unique*/
		unique village /*===>Not unique*/
		unique healthzone village /*===>Not unique*/
	
	* Change string to lowercase 
		foreach var of varlist health* village {
			replace `var' = lower(`var')
		}	
	
	* Prepare for merge
		keep if regexm(healthzone, "beni")==1
		keep clusterid health* village
		rename (*) (sw_*)
		gen village = sw_village
		sort village
		save temp_sw.dta, replace

/*3. INTERVIEW DATASET*/		
use "$datadir/MIHR_RMS_Baseline_Cleaned_Dataset.dta", clear 
	rename *, lower 
	rename m1q8 village
	rename m1q9 communename
	rename m1q10 healthzone
		
	* Check the unique ID var for clusters */
		unique village /*====> ONLY 63*/
		unique healthzone village /*====> 151! likely due to de/be */ 
		lookfor cluster
		lookfor id
		
	* Change string to lowercase 
		foreach var of varlist village communename healthzone {
			replace `var' = lower(`var')
		}	

	* Prepare for merge 
		keep if regexm(healthzone, "beni")==1
			tab healthzone
			
		keep village 
		gen obs_interview=1
		
		collapse (count) obs, by(village)
		lab var obs "number of women interviewed per village"
		
	* Merge
		sort village 
		merge village using temp_hh.dta, 
			tab _merge
			rename _merge merge_with_hh

		sort village 
		merge village using temp_sw.dta, 
			tab _merge
			rename _merge merge_with_sw
			
	* Browse
		sort village
		save merge_issue_beni_example.dta, replace
		
	* PAUSE AND CHECK HERE			
}		

************************************************************************
* C. Calculate sampling weights   
************************************************************************

*** C.1 Get total population size from sheet3 
import excel "$datadir/DRC RMS Community Sampling and Weights.xlsx", sheet($sheet3) firstrow clear
	
	rename *, lower
	d
	
	* Check population for each cluster in the study population
		codebook pop	
		gen byte notnumeric = real(pop)==. 
		tab notnumeric 
		list pop if notnumeric==1 
	
	* Replace Pop with missing if non-numeric
		replace pop = "" if notnumeric==1
	
	* Destring and calculate the total pop
		destring pop, replace
		egen totalpop = sum(pop)
		sum totalpop
		return list	
		global totalpop `r(mean)'

*** C.2 Explore response rates in each cluster 	
use "$datadir/MIHR_RMS_Baseline_Cleaned_Dataset.dta", clear

	/*
	QUESTION:
	where can I find the restponse rate by cluster? or interview completion results? 
	Or did the field team sample until they reach the take size? i.e., response rate=100%
	For now, let's create and use mock response rates
	
	ANSWER: 
	There is no clear data about response rate. But, in the interview dataset, 
		the number of observations varies from 22 to 49 in one village.   
		For now, replace it with 25, and then calculate the response rate.
		This village with 49 observations is likely a source of the merge problems.
		"CELLULE KASANGA"! 
		This is actually included in the illustrative example in Beni. 
	*/
		gen village = m1q8
		
		gen obs_interview = 1
			
			collapse (count) obs , by (village)
			
			tab obs, m
			list if obs!=25 /*check this against section B.2*/
			
			/*
			.                         tab obs, m

				(count) |
			obs_intervi |
					 ew |      Freq.     Percent        Cum.
			------------+-----------------------------------
					 22 |          1        1.56        1.56
					 23 |          2        3.12        4.69
					 24 |          1        1.56        6.25
					 25 |         59       92.19       98.44
					 49 |          1        1.56      100.00
			------------+-----------------------------------
				  Total |         64      100.00

			.                         list if obs!=25

				 +----------------------------+
				 |         village   obs_in~w |
				 |----------------------------|
			  2. |           BINGO         23 |
			 12. | CELLULE KASANGA         49 |
			 30. |        KITSANGA         24 |
			 47. |           NGOYO         22 |
			 54. |           SENGA         23 |
				 +----------------------------+
			*/
			
			*TEMPORARY FIX FOR NOW... 
			replace obs = 25 if obs>25			
			
			gen responserate = obs_interview / $takesize
				
			lab var obs "number of women interviewed per village"
			lab var responserate "response rate per village"
					
		keep village responserate
		sort village
		save temp_responserate.dta, replace
				
		*** further investigation about the problem village 
		use "$datadir/MIHR_RMS_Baseline_Cleaned_Dataset.dta", clear
			keep if m1q8=="CELLULE KASANGA"
			codebook m1q7  m1q8  m1q9 /*=====> ugh, no clear clue to fix??*/
	
*** C.3 Import response rate and probability of selection for households in each sampled clusters - separate file from Nancy
import excel "$datadir/RMS Baseline -HH Sampling Distribution by EA.xlsx", firstrow clear	
	d
	rename *, lower

	* Assess distribution 
			histogram noofhouseholdsthatwereenum, start(0) w(25) normal
			histogram noofeligiblehouseholdsinea, start(0) w(10) normal
			
	* Create 
		gen propeligiblehh = noofeligiblehouseholdsinea / noofhouseholdsthatwereenum 
		gen probselection_hh = $takesize / noofhouseholdsthatwereenum 
		
			sum prop prob			
			histogram propeligiblehh, start(0) w(0.05) normal
			histogram probselection_hh, start(0) w(0.025) normal

		rename communityname village
		keep village no* prop prob
		sort village 
		save temp_hhselection.dta, replace			
				
*** C.4 Calculate probability of selection for clusters in sheet5 
import excel "$datadir/DRC RMS Community Sampling and Weights.xlsx", sheet($sheet5) firstrow clear
	
	rename *, lower
	d	

	* merge with response rate "calculated/assigned" from the interview data
		sort village
		merge village using temp_responserate.dta, 
			tab _merge, m 

			/*
			QUESTION: 
			Need to find unique cluster id or combination - see below merge problem
			- In the main dataset the village (m1q8) has 64 unique values 
			- In the sampling excel sheet there are only 63 unique villages. 
				But, combination of HealthFacilityA + Village is unique
				FYI, combination of HealthZone + Village is NOT unique
			*/
			
			/*
			.                         tab _merge, m 

			 _merge |      Freq.     Percent        Cum.
			------------+-----------------------------------
				  1 |          7        9.72        9.72
				  2 |          8       11.11       20.83
				  3 |         57       79.17      100.00
			------------+-----------------------------------
			  Total |         72      100.00

			*/
			drop if _merge==2
			drop _merge
			
			sum responserate
			
			*TEMPORARY FIX FOR NOW... 
			egen temp = mean(responserate)
			replace responserate = temp if responserate==.
			drop temp
	  
	* merge with HH selectino probability 
		sort village
		merge village using temp_hhselection.dta, 
			tab _merge, m 

			/*
			.                         tab _merge, m 

				 _merge |      Freq.     Percent        Cum.
			------------+-----------------------------------
					  1 |          7        9.72        9.72
					  2 |          8       11.11       20.83
					  3 |         57       79.17      100.00
			------------+-----------------------------------
				  Total |         72      100.00
			*/
			drop if _merge==2
			drop _merge
			
			*AGAIN, TEMPORARY FIX FOR NOW... 
			egen temp = mean(probselection_hh)
			replace probselection_hh = temp if probselection_hh==.
			drop temp
			
	* Create selection probabilities for the 64 clusters - PPS
		gen probselection_cluster = ( $clustersize * population2021 ) / $totalpop

	* Create sample design weight - i.e., sampling weight with 100% response rate in all clusters
		
		gen designweight = 1 / (probselection_cluster * probselection_hh) 
	
	* Create sampling weight - i.e., sample design weight, adjusted for response rate  
		gen responsefactor = 1 / (1-(1-responserate)) /*response factor is 1 in RMS*/
		gen weight = designweight * responsefactor
		
		sum prob* *weight
		
		/*
		QUESTION:
		Do we have one respondent per household? 
		If so, this weight above (which is a houshold weight) is 
			basically sampling weight for respondents. 
		If not, this weight should be further adjusted for 
			the responserantes at the respondent level. 	
		For now, I assum we have only one respondent in each sampled household. 	
		*/
		
	* Normalize sampling weight 
	
		foreach var of varlist weight*{
			sum `var'
			replace `var' = `var' / `r(mean)'
			sum `var'
		}
				
		histogram weight, w(0.05) start(0) xline(1)		
			
*** C.4 Export the sampling weight to merge with the main dataset 

	sort village 
	save RMS_cluster_samplingweight.dta, replace

*END OF DO FILE	
