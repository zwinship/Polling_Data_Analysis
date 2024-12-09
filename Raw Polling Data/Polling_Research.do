// Policy Eval Final Project .do file
// Zach Winship
// Start date of .do file, 11/15

// If someone where to try and replicate this, they would have to take the raw csv files I created and merged
// There should be 3 in total, I plan on putting them in the github linked on the paper
// If you were to download the files and change the paths I believe the do-file should run almost entirely
// I know realize retrospectively that I many have wrote some code in the console
// I now realize this mistake will probably make it so the do-file will not run correctly 
// They should hopefully be simple fixes the replicator could do 
// For example I remember renaming a few variables but I dont remember what they previously were named
// Other than this anyone should be able to replicate this based on the raw csv files on the github

// Starting data set
import delimited "C:\Users\ZWINSHIP\OneDrive - Bentley University\pythonProject\PollingStudy\merged_polling_data.csv"




// Renaming variables, stata does not like when the variable starts with a year I guess
rename closeness_2024_polls closeness
rename dem_trail_2024_polls dem_trail
rename _state_cum_vote vote_2020
rename v8 vote_2022
rename v9 vote_2024
rename dem_2024_state_cum_vote vote_dem
rename gop_2024_state_cum_vote vote_gop
rename other_state_cum_vote vote_other


// Labeling variables
label variable days_until_vote "days until Nov. 5"
label variable closeness "trailing canidate polling average (2024)"
label variable dem_trail "democrat trailing in polling average (2024)"
label variable vote_2020 "cumlative vote"
label variable vote_2022 "cumlative vote"
label variable vote_2024 "cumlative vote"
label variable vote_dem "2024 cumlative registered democrat vote"
label variable vote_gop "2024 cumlative registered republican vote"
label variable vote_other "2024 cumlative other party vote"


// Encoding the state variable
encode state, gen(state_code)
drop state
rename state_code state
order state, before(days_until_vote)


// Creating a new variable for the z-score of closeness
summarize closeness
// mean = 40.44572
// sd = 5.209691
gen z_closeness = (closeness - 40.44572) / 5.209691
summarize z_closeness





// Merging in Google Trends
// Did a little extra comand window changed for this file so it macthed the master .dta
merge 1:1 state days_until_vote using "C:\Users\ZWINSHIP\OneDrive - Bentley University\pythonProject\Polling Study\trends\trends.dta"
label variable trends "Google Trends Data: 538 Website"




// Droping a bunch of variables I dont need anymore
drop _merge mean_log_closeness sd_log_closeness cont_exposure z_rank_closeness rank_closeness progressive_z_scores

// Logging these variables
gen log_trends = log(trends)
gen log_vote_2024 = log(vote_2024)
gen log_closeness = log(closeness)



// Creating variables to determine levels of exposure
// First starting with quantiles, and then a dummy for if a state is in the 4th quantile for that day
// And then creating a new variable that counts the number of days in a row a state is in the 4th quantiles
// Lastly creating a variable which takes the max streak for each state, to determine how many days of continous exposure a state had
xtile trend_quantile = trends, n(4)

gen fourth_quantile_trend = 0
replace fourth_quantile_trend = 1 if trend_quantile == 4

bysort state: count if fourth_quantile_trend == 1
bysort state: sum fourth_quantile_trend

// Creating the streak variable for the number of continous days in the 4th quantiles
// Then Creating a variable for the max number of this streak for each state
gen streak = 0
bysort state (days_until_vote): replace streak = cond(fourth_quantile_trend == 1, streak[_n-1] + 1, 0)

bysort state: egen max_streak = max(streak)
bysort state: sum max_streak





// Merging in another dataset that has data on the number of registered voters per state
merge m:1 state using "C:\Users\ZWINSHIP\OneDrive - Bentley University\registered-voters-by-state-2024.dta"
// regsiteredvoters is in thousands so I just multiply it by 100 to make it easier for mean
replace registeredvoters = registeredvoters * 1000
drop _merge

// Creating a bunch of new possible outcome variables which uses this new dataset merged from above
//creating new variables for net turnout (votes on day / number of possible registered voters left to vote)
sort state days_until_vote

gen day_turnout = D.vote_2024

gen registeredvotersleft = registeredvoters - vote_2024

gen net_turnout = day_turnout / registeredvotersleft

gen turnout_over_registered = day_turnout / registeredvoters

gen log_day_turnout = log(day_turnout)


//Starting to get a lot of variables so adding labels and reording the variables

label variable trend_quantile "quantiles of the levels variable trends"
label variable fourth_quantile_trend "1 if in 4th quantile at time t"
label variable streak "takes the streak of being in the 4th quantile across consecutive times t"
label variable max_streak "max(streak) for state s"
label variable registeredvoters "Registered Voters for state s"
label variable registeredvotersaspercentofvotin "% of voting age pop. registered for state s"
label variable day_turnout "marginal turnout for state s at time t"
label variable registeredvotersleft "number of regisitered voters left that can still vote for state s at time t"
label variable net_turnout "day_turnout / registeredvotersleft"
label variable turnout_over_registered "day_turnout / registeredvoters"
label variable trends "Google Trends Data for website 538 for state s at time t"

// Ordering for organization
order state days_until_vote vote_2024 log_vote_2024 day_turnout net_turnout turnout_over_registered log_day_turnout ///
	closeness z_closeness log_closeness std_log_closeness ///
	trends log_trends trend_quantile fourth_quantile_trend streak max_streak 

// Creating another possible outcome variable
gen log_net_turnout = log(net_turnout)


// Creating the z_score for trends 
sum trends
gen z_trends = (trends - 25.28571)/ 21.10997



// Renaming the treatment variable
rename fourth_quantile_trend exposure

// Alternative covarite for if the polling is significant on a specific day
gen closepolling = 0
replace closepolling = 1 if z_closeness >= 0.5
replace closepolling = 0 if z_closeness == .





// Section Variables of Party Trends
// Creating outcome variable of interest and a new variable of gop_trail which is just the opposite of dem_trail
gen log_vote_dem = log(vote_dem)
gen day_dem_turnout = D.vote_dem

gen log_vote_gop = log(vote_gop)
gen day_gop_turnout = D.vote_gop

gen gop_trail = 0
replace gop_trail = 1 if dem_trail == 0


// Creating average z_trends per state
egen avg_z_trends = mean(z_trends), by(state)

// Creating in_state variable for observations that include only the treatment and control groups
// Subsettng for only observations of a max_streak of 9, these by defaults have an avg_z_trends >=0.5
// I choose only the states with a max_streak of 9 so the post variable can be fixed at this date
gen in_state = 0
replace in_state = 1 if max_streak == 9 | avg_z_trends <= -0.5


// Helpful variable to see the control and treatment groups when looking at the whole data set
gen treat = 0
replace treat = 1 if max_streak == 9

gen control = 0
replace control = 1 if avg_z_trends <= -0.5

// Creating varible for if the state is in the treatment or control groups
// Exposed_state = 0 then its max_streak <= 6 and if exposed_state = 1 it has max_streak = 9
// This variable is essentially my treatment dummy
gen exposed_state = .
replace exposed_state = 1 if treat == 1
replace exposed_state = 0 if control == 1

// Creating post variable for pre and post the treatment intervention
// The treatment intervention is when the treated enter the 4th quantile of exposure
gen post = 0
replace post = 1 if days_until_vote >= -8 

// Creating variable for if the state is considered to have close average polling
replace close_state = 0
replace close_state = 1 if avg_z_closeness >=0.5

// Creating a subset of the data that includes only the treatment max_streak == 9 and the control max_streak <= 6
replace in_state = 0
replace in_state = 1 if max_streak == 9 | max_streak <= 6

// Swing state dummy based on the 7 swing states in the election
gen swing_state = 0
replace swing_state = 1 if inlist(state, 3, 10, 22, 28, 33, 38, 49)


// Creating variable for dem and gop for if the state averages either a democrat or gop trail
// Determing if the state is a dem_trail or gop_trail state respectively
// This is from the polling data for each day not from election outcomes
egen prop_dem_trail = mean(dem_trail), by(state)
gen dem_trail_state = 0
replace dem_trail_state = 1 if prop_dem_trail >= 0.5
replace dem_trail_state = 0 if dem_trail == .


egen prop_gop_trail = mean(gop_trail), by(state)
gen gop_trail_state = 0
replace gop_trail_state = 1 if prop_gop_trail >= 0.5
replace gop_trail_state = 0 if gop_trail == .




// Cleaning clutter from above
drop upper_bound lower_bound outcome_pred_post outcome_pred margin z_closeness_effect positive_days rel_day_lags rel_day_leads rel_day test treatment_test treatment avg_z_closeness avg_z_trends

// Removing Temp Variable
drop prop_dem_trail prop_gop_trail

label variable gop_trail "If the gop canidate is trailing in polls on day"
label variable closepolling "1 if polling is over 0.5 z-score on day"
label variable in_state "Group of states for subsetting between t and c groups"
label variable treat "Treatment Group inside of in_state"
label variable control "Control Group inside of in_state"
label variable day_dem_turnout "Marginal Turnout of Registered Dem"
label variable day_gop_turnout "Marginal Tunrout of Registered GOP"
label variable close_state "If state avg_z_closeness >= 0.5"
label variable exposed_state "If state avg_z_trends >= 0.5"
label variable post "If time >= -8"
label variable swing_state "If state is one of the seven 2024 swing state"
label variable dem_trail_state "If state has avg dem_trail >= 0.5"
label variable gop_trail_state "If state has avg gop_trail >= 0.5"



// Summary stats for Paper
// Section 1
estpost sum log_vote_2024 closeness trends registeredvoters if exposed_state == 0 & close_state == 0 & in_state == 1
esttab using "e=0_c=0.doc", replace cells("mean sd min max")
	
estpost sum log_vote_2024 closeness trends registeredvoters if exposed_state == 1 & close_state == 0 & in_state == 1
esttab using "e=1_c=0.doc", replace cells("mean sd min max")	

estpost sum log_vote_2024 closeness trends registeredvoters if exposed_state == 0 & close_state == 1 & in_state == 1
esttab using "e=0_c=1.doc", replace cells("mean sd min max")

estpost sum log_vote_2024 closeness trends registeredvoters if exposed_state == 1 & close_state == 1 & in_state == 1
esttab using "e=1_c=1.doc", replace cells("mean sd min max")


// Dem
estpost sum log_vote_dem closeness trends registeredvoters if exposed_state == 0 & dem_trail == 0 & in_state == 1
esttab using "dem_e=0_d=0.doc", replace cells("mean sd min max")
		
estpost sum log_vote_dem closeness trends registeredvoters if exposed_state == 1 & dem_trail == 0 & in_state == 1
esttab using "dem_e=1_d=0.doc", replace cells("mean sd min max")

estpost sum log_vote_dem closeness trends registeredvoters if exposed_state == 0 & dem_trail == 1 & in_state == 1
esttab using "dem_e=0_d=1.doc", replace cells("mean sd min max")

estpost sum log_vote_dem closeness trends registeredvoters if exposed_state == 1 & dem_trail == 1 & in_state == 1
esttab using "dem_e=1_d=1.doc", replace cells("mean sd min max")
		
		
// GOP
estpost sum log_vote_gop closeness trends registeredvoters if exposed_state == 0 & gop_trail == 0 & in_state == 1
esttab using "dem_e=0_g=0.doc", replace cells("mean sd min max")		
		
estpost sum log_vote_gop closeness trends registeredvoters if exposed_state == 1 & gop_trail == 0 & in_state == 1
esttab using "dem_e=1_g=0.doc", replace cells("mean sd min max")

estpost sum log_vote_gop closeness trends registeredvoters if exposed_state == 0 & gop_trail == 1 & in_state == 1
esttab using "dem_e=0_g=1.doc", replace cells("mean sd min max")

estpost sum log_vote_gop closeness trends registeredvoters if exposed_state == 1 & gop_trail == 1 & in_state == 1
esttab using "dem_e=1_g=1.doc", replace cells("mean sd min max")		
		
		


// Regressions on net_turnout outomce
// Regressions continous closeness
reghdfe net_turnout i.post##c.z_closeness##i.exposed_state if in_state == 1 & days_until_vote >= -15, absorb(state days_until_vote) vce(robust)
estimates store model1
reghdfe net_turnout i.post##c.z_closeness##i.exposed_state if in_state == 1 & days_until_vote >= -15, absorb(state days_until_vote) vce(cluster state)
estimates store model2

// Regressions on Binary Closeness
reghdfe net_turnout i.post##i.close_state##i.exposed_state if in_state == 1 & days_until_vote >= -15, absorb(state days_until_vote) vce(robust)
estimates store model3
reghdfe net_turnout i.post##i.close_state##i.exposed_state if in_state == 1 & days_until_vote >= -15, absorb(state days_until_vote) vce(cluster state)
estimates store model4




// Regressions on Log_vote Outcome
// Regressions continous closeness
reghdfe log_vote_2024 i.post##c.z_closeness##i.exposed_state if in_state == 1 & days_until_vote >= -15, absorb(state days_until_vote) vce(robust)
estimates store model5
reghdfe log_vote_2024 i.post##c.z_closeness##i.exposed_state if in_state == 1 & days_until_vote >= -15, absorb(state days_until_vote) vce(cluster state)
estimates store model6

//Regresison on Binary Closeness
reghdfe log_vote_2024 i.post##i.close_state##i.exposed_state if in_state == 1 & days_until_vote >= -15, absorb(state days_until_vote) vce(robust)
estimates store model7
reghdfe log_vote_2024 i.post##i.close_state##i.exposed_state if in_state == 1 & days_until_vote >= -15, absorb(state days_until_vote) vce(cluster state)
estimates store model8


esttab model1 model2 model3 model4 model5 model6 model7 model8 using vote_2024.rtf, se star(* 0.10 ** 0.05 *** 0.01) b(3) n r2 ar2 replace



// Dem  Reg
// No variation of Dem_Trail
reghdfe log_vote_dem i.post##i.exposed_state##i.dem_trail_state if in_state == 1 & days_until_vote >= -15, absorb(state days_until_vote) vce(robust)
estimates store model1
reghdfe log_vote_dem i.post##i.exposed_state##i.dem_trail_state if in_state == 1 & days_until_vote >= -15, absorb(state days_until_vote) vce(cluster state)
estimates store model2

// Variation of Dem_Trail
reghdfe log_vote_dem i.post##i.exposed_state##i.dem_trail if in_state == 1 & days_until_vote >= -15, absorb(state days_until_vote) vce(robust)
estimates store model3
reghdfe log_vote_dem i.post##i.exposed_state##i.dem_trail if in_state == 1 & days_until_vote >= -15, absorb(state days_until_vote) vce(cluster state)
estimates store model4

esttab model1 model2 model3 model4 using dem.rtf, se star(* 0.10 ** 0.05 *** 0.01) b(3) n r2 ar2 replace




// GOP Reg
// No variation of GOP_Trail
reghdfe log_vote_gop i.post##i.exposed_state##i.gop_trail_state if in_state == 1 & days_until_vote >= -15, absorb(state days_until_vote) vce(robust)
estimates store model1
reghdfe log_vote_gop i.post##i.exposed_state##i.gop_trail_state if in_state == 1 & days_until_vote >= -15, absorb(state days_until_vote) vce(cluster state)
estimates store model2

// Variation of GOP_Trail
reghdfe log_vote_gop i.post##i.exposed_state##i.gop_trail if in_state == 1 & days_until_vote >= -15, absorb(state days_until_vote) vce(robust)
estimates store model3
reghdfe log_vote_gop i.post##i.exposed_state##i.gop_trail if in_state == 1 & days_until_vote >= -15, absorb(state days_until_vote) vce(cluster state)
estimates store model4


esttab model1 model2 model3 model4 using gop.rtf, se star(* 0.10 ** 0.05 *** 0.01) b(3) n r2 ar2 replace





// Section 1 Ptrends
// Save Before Subsetting
// P trends for log_vote outcome
preserve
keep if post == 0 & days_until_vote >= -15 & in_state == 1
collapse (mean) log_vote_2024, by(days_until_vote exposed_state close_state)

twoway (line log_vote_2024 days_until_vote if exposed_state == 1 & close_state == 1) ///
	   (line log_vote_2024 days_until_vote if exposed_state == 1 & close_state == 0) ///
	   (line log_vote_2024 days_until_vote if exposed_state == 0 & close_state == 1) ///
	   (line log_vote_2024 days_until_vote if exposed_state == 0 & close_state == 0), ///
	   title("Pre-Treatment Parallel Trends in Log Total Vote") ///
	   ylabel(,angle(horizontal)) xtitle("Days Until Vote") ytitle("Log Total Vote") ///
	   legend(order(1 "Exposed=1, Close State=1" 2 "Exposed=1, Close State=0" ///
	   3 "Exposed=0, Close State=1" 4 "Exposed=0, Close State=0"))
	   
graph export "new_log_ptrend.png", as(png) replace
restore


	   
// P trends for net_turnout outcome
// Save before subsetting
preserve
keep if post == 0 & days_until_vote >= -15 & in_state == 1
collapse (mean) net_turnout, by(days_until_vote exposed_state close_state)

twoway (line net_turnout days_until_vote if exposed_state == 1 & close_state == 1) ///
	   (line net_turnout days_until_vote if exposed_state == 1 & close_state == 0) ///
	   (line net_turnout days_until_vote if exposed_state == 0 & close_state == 1) ///
	   (line net_turnout days_until_vote if exposed_state == 0 & close_state == 0), ///
	   title("Pre-Treatment Parallel Trends in Net Turnout") ///
	   ylabel(,angle(horizontal)) xtitle("Days Until Vote") ytitle("Net Turnout") ///
	   legend(order(1 "Exposed=1, Close State=1" 2 "Exposed=1, Close State=0" ///
	   3 "Exposed=0, Close State=1" 4 "Exposed=0, Close State=0"))
	   
graph export "new_turnout_ptrend.png", as(png) replace
restore
	   
// Section 2 Ptrends
// Dem Ptrends
// Save Before Subsetting
preserve
keep if post == 0 & days_until_vote >= -15 & in_state == 1
collapse (mean) log_vote_dem, by(days_until_vote exposed_state dem_trail_state)

twoway (line log_vote_dem days_until_vote if exposed_state == 1 & dem_trail_state == 1) ///
	   (line log_vote_dem days_until_vote if exposed_state == 1 & dem_trail_state == 0) ///
	   (line log_vote_dem days_until_vote if exposed_state == 0 & dem_trail_state == 1) ///
	   (line log_vote_dem days_until_vote if exposed_state == 0 & dem_trail_state == 0), ///
	   title("Pre-Treatment Parallel Trends in Log Democrat Vote") ///
	   ylabel(,angle(horizontal)) xtitle("Days Until Vote") ytitle("Log Democrat Vote") ///
	   legend(order(1 "Exposed=1, Dem_Trail=1" 2 "Exposed=1, Dem_Trail=0" ///
	   3 "Exposed=0, Dem_Trail=1" 4 "Exposed=0, Dem_Trail=0"))

graph export "new_dem_ptrend.png", as(png) replace
restore

// GOP Ptrends
// Save Before Subsetting
preserve   
keep if post == 0 & days_until_vote >= -15 & in_state == 1
collapse (mean) log_vote_gop, by(days_until_vote exposed_state gop_trail_state)

twoway (line log_vote_gop days_until_vote if exposed_state == 1 & gop_trail_state == 1) ///
	   (line log_vote_gop days_until_vote if exposed_state == 1 & gop_trail_state == 0) ///
	   (line log_vote_gop days_until_vote if exposed_state == 0 & gop_trail_state == 1) ///
	   (line log_vote_gop days_until_vote if exposed_state == 0 & gop_trail_state == 0), ///
	   title("Pre-Treatment Parallel Trends in Log GOP Vote") ///
	   ylabel(,angle(horizontal)) xtitle("Days Until Vote") ytitle("Log GOP Vote") ///
	   legend(order(1 "Exposed=1, GOP_Trail=1" 2 "Exposed=1, GOP_Trail=0" ///
	   3 "Exposed=0, GOP_Trail=1" 4 "Exposed=0, GOP_Trail=0"))

graph export "new_gop_ptrend.png", as(png) replace
restore
	   
	   
	

	
	
	
	
	
	
// My Tell-A-Story Graph for somewhere at the start of the paper
// Save before subet

preserve
keep if days_until_vote >= -15 & in_state == 1

collapse (mean) log_vote_2024, by(days_until_vote exposed_state close_state post )


twoway (lfit log_vote_2024 days_until_vote if exposed_state == 1 & post == 0) ///
	   (lfit log_vote_2024 days_until_vote if exposed_state == 0 & post == 0) ///
	   (line log_vote_2024 days_until_vote if exposed_state == 1 & close_state == 1 & post == 1) ///
	   (line log_vote_2024 days_until_vote if exposed_state == 1 & close_state == 0 & post == 1) ///
	   (line log_vote_2024 days_until_vote if exposed_state == 0 & close_state == 1 & post == 1) ///
	   (line log_vote_2024 days_until_vote if exposed_state == 0 & close_state == 0 & post == 1), ///
	   title("Treatment Effect of Closing Polling post Exposure to Polls") ///
	   ylabel(,angle(horizontal)) xtitle("Days Until Election") ytitle("Log Vote") ///
	   legend(order(1 "Exposed=1" 2 "Exposed=0" ///
	   3 "Exposed = 1, Close State=1" 4 "Exposed=1, Close State=0" ///
	   5 "Exposed = 0, Close State=1" 6 "Exposed=0, Close State=0")) xline(-8) ///
	   xlabel(-8 -15(2)0, valuelabel)

graph export "story.png", as(png) replace
restore




// Story Graph for Dem_vote
preserve
keep if days_until_vote >= -15 & in_state == 1

collapse (mean) log_vote_dem, by(days_until_vote exposed_state dem_trail_state post)


twoway (lfit log_vote_dem days_until_vote if exposed_state == 1 & post == 0) ///
	   (lfit log_vote_dem days_until_vote if exposed_state == 0 & post == 0) ///
	   (line log_vote_dem days_until_vote if exposed_state == 1 & dem_trail_state == 1 & post == 1) ///
	   (line log_vote_dem days_until_vote if exposed_state == 1 & dem_trail_state == 0 & post == 1) ///
	   (line log_vote_dem days_until_vote if exposed_state == 0 & dem_trail_state == 1 & post == 1) ///
	   (line log_vote_dem days_until_vote if exposed_state == 0 & dem_trail_state == 0 & post == 1), ///
	   title("Treatment Effect of Dem_Trail_State post Exposure") ///
	   ylabel(,angle(horizontal)) xtitle("Days Until Election") ytitle("Log Democrat Vote") ///
	   legend(order(1 "Exposed=1" 2 "Exposed=0" ///
	   3 "Exposed = 1, Dem_Trail=1" 4 "Exposed=1, Dem_Trail=0" ///
	   5 "Exposed = 0, Dem_Trail=1" 6 "Exposed=0, Dem_Trail=0")) xline(-8) ///
	   xlabel(-8 -15(2)0, valuelabel)

graph export "dem_story.png", as(png) replace
restore



// Story Graph for GOP_Vote
preserve
keep if days_until_vote >= -15 & in_state == 1

collapse (mean) log_vote_gop, by(days_until_vote gop_trail_state exposed_state post)


twoway (lfit log_vote_gop days_until_vote if exposed_state == 1 & post == 0) ///
	   (lfit log_vote_gop days_until_vote if exposed_state == 0 & post == 0) ///
	   (line log_vote_gop days_until_vote if exposed_state == 1 & gop_trail_state == 1 & post == 1) ///
	   (line log_vote_gop days_until_vote if exposed_state == 1 & gop_trail_state == 0 & post == 1) ///
	   (line log_vote_gop days_until_vote if exposed_state == 0 & gop_trail_state == 1 & post == 1) ///
	   (line log_vote_gop days_until_vote if exposed_state == 0 & gop_trail_state == 0 & post == 1), ///
	   title("Treatment Effect of GOP_Trail_State post Exposure") ///
	   ylabel(,angle(horizontal)) xtitle("Days Until Election") ytitle("Log GOP Vote") ///
	   legend(order(1 "Exposed=1" 2 "Exposed=0" ///
	   3 "Exposed = 1, GOP_Trail=1" 4 "Exposed=1, GOP_Trail=0" ///
	   5 "Exposed = 0, GOP_Trail=1" 6 "Exposed=0, GOP_Trail=0")) xline(-8) ///
	   xlabel(-8 -15(2)0, valuelabel)

graph export "gop_story.png", as(png) replace
restore











