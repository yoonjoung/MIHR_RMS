*THIS DO FILE CREATES SAMPLING WEIGHTS FOR THE RMS BASELINE SURVEY.  
			
*Find "QUESTION" throughout the do file		
			
* Table of Contents
* A. SETTING 
*** A.1 Study design 
* B. Scan worksheets 
* C. Calculate sampling weights   
*** C.1 Get total population size from sheet3 
*** C.2 Calculate or import response rates in each cluster 	
*** C.3 Calculate probability of selection in sheet5
*** C.4 Export the samplign weight to merge with the main dataset 

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
okok
cd $maindir
dir /*check associated do files*/

*** A.1 STUDY DESIGN 

global clustersize 64 /*Number of clusters*/
global takesize 25 /*Number of households in a sampled cluster*/
global averagehhsize 6.5 /*Average household size in the study population, from the data*/

************************************************************************
* B. Scan worksheets 
************************************************************************

*** B.1 Check list of worksheets
import excel "$datadir/DRC RMS Community Sampling and Weights.xlsx", describe
return list

	global sheet1 "`r(worksheet_1)'"
	global sheet2 "`r(worksheet_2)'"
	global sheet3 "`r(worksheet_3)'"
	global sheet4 "`r(worksheet_4)'"
	global sheet5 "`r(worksheet_5)'"
	global sheet6 "`r(worksheet_6)'"

*** B.2 Check each worksheet 
import excel "$datadir/DRC RMS Community Sampling and Weights.xlsx", sheet($sheet1) firstrow clear
	d, short	
	d 
	codebook Vil /*63 unique village names*/
	
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
	codebook /*63 unique village names*/
		
	* Confirm combination of HealthFacilityAiredesante + Village is unique
		gen dummy = "_"
		egen clusterunique = concat(HealthFacilityAiredesante dummy Village) 
		egen clusterunique2 = concat(HealthZone dummy Village) 
		list in f/5
		codebook clusterunique*
						
import excel "$datadir/DRC RMS Community Sampling and Weights.xlsx", sheet($sheet5) firstrow clear	
	d, short		
	d
	codebook Vil ClusterID
	
	* Confirm combination of HealthFacilityA + Village is unique
		gen dummy = "_"
		egen clusterunique = concat(HealthFacilityAiredesante dummy Village) 
		list in f/5
		codebook clusterunique
		
		sum
		sum Prob* Overall, detail /*unclear what these columns are*/

import excel "$datadir/DRC RMS Community Sampling and Weights.xlsx", sheet($sheet6) firstrow clear	
	d, short		
	d	

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

*** C.2 Calculate or import response rates in each cluster 	
use "$datadir/MIHR_RMS_Baseline_Cleaned_Dataset.dta", clear

	/*
	QUESTION:
	where can I find the restponse rate by cluster? or interview completion results? 
	Or did the field team sample until they reach the take size? i.e., response rate=100%
	For now, let's create and use mock response rates
	*/
		set seed 38
		generate random = runiform()
		gen responserate = 1 
			replace responserate = 0 if random>0.95
		gen village = m1q8
			
		collapse (mean) responserate, by (village)
		sort village
		save temp.dta, replace
	
*** C.3 Calculate probability of selection in sheet5 
import excel "$datadir/DRC RMS Community Sampling and Weights.xlsx", sheet($sheet5) firstrow clear
	
	rename *, lower
	d	
	
	* Create selection probabilities for the 64 clusters - PPS
		gen probselection_cluster = ( $clustersize * population2021 ) / $totalpop
		
	* Create selection probabilities for households in a sampled cluster - random 
		/*
		QUESTION: 
		Do we adjust for the proportion of HH that have eligible woman? 	
		How did the field team identify eligible households? 	
		Do we assume (or do we not know) the proportion is same
			amogn all clusters in the study area among all clusters that are selected.  
			If so, sampling weight calculation may be based on only cluster selection probability. 
		But, it would be still good to clarfy how this was done.
		For now, we assume and use mock data for proportion of households that have an eligibel woman	
		*/
		*gen propeligiblehh = 1
		set seed 38
		gen propeligiblehh = runiform(0.5, 0.7)		
		gen probselection_hh = $takesize / ( (population2021 / $averagehhsize) * propeligiblehh ) 
		
	* Create sample design weight - i.e., sampling weight with 100% response rate in all clusters
		
		gen designweight = 1 / (probselection_cluster * probselection_hh)

	* Merge with response rates 	
		/*
		QUESTION: 
		Need to find unique cluster id or combination - see below merge problem
		- In the main dataset the village (m1q8) has 64 unique values 
		- In the sampling excel sheet there are only 63 unique villeages. 
			But, combination of HealthFacilityA + Village is unique
			FYI, combination of HealthZone + Village is NOT unique
		Until then we assign mock response rates between 0.9 and 1	
		*/	
		preserve
		sort village
		merge village using temp.dta, 
			tab _merge, m 
		restore
		
		set seed 38
		generate responserate = runiform(0.9, 1)
	
	* Create sampling weight - i.e., sample design weight, adjusted for response rate  
		gen responsefactor = 1 / (1-(1-responserate))
		gen weight = designweight * responsefactor
		
		/*
		Depending on answers to above question about eligible households, 
			the following may be used instead. But see the distribution... 
		*/
		gen weight2 = (1 / probselection_cluster) * responsefactor
		
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
		
	* Normalizw sampling weight 
	
		foreach var of varlist weight*{
			sum `var'
			replace `var' = `var' / `r(mean)'
			sum `var'
		}
				
		histogram weight, w(0.05) start(0) xline(1)
		histogram weight2, w(0.05) start(0) xline(1)
			
*** C.4 Export the sampling weight to merge with the main dataset 

	sort village 
	save RMS_cluster_samplingweight.dta, replace

*END OF DO FILE	
