capture log close
log using "vignette", smcl replace
//_1
sysuse bfg2020, clear
//_2
local y avgrep2000to2016
local x tye_tfe890_500kNI_100_l6
local w1 log_area_2010 lat lon temp_mean rain_mean elev_mean d_coa d_riv d_lak ave_gyi
local w0 i.statea
local w `w1' `w0'
local SE cluster(km_grid_cel_code)
reg `y' `x' `w', `SE' 
//_3
regsensitivity `y' `x' `w', compare(`w1')
//_4
regsensitivity bounds `y' `x' `w', compare(`w1') cbar(.1)
//_5
regsensitivity plot
//_6q
qui graph export dmp_bounds_1.png, width(500) replace
//_7
regsensitivity bounds `y' `x' `w', cbar(.1)
//_8
forvalues i=1/12{
    local rxbar `rxbar' `=e(idset_table)[`i', 1]'
}
regsensitivity bounds `y' `x' `w', compare(`w1') cbar(.1) rxbar(`rxbar') 
//_9
regsensitivity bounds `y' `x' `w', compare(`w1') cbar(0(.2)1) 
//_10q
qui graph export dmp_bounds_2.png, width(700) replace
//_11
regsensitivity bounds `y' `x' `w', compare(`w1') cbar(0(.2)1) rxbar(0 2) plot
//_12q
qui graph export dmp_bounds_3.png, width(700) replace
//_13
regsensitivity breakdown `y' `x' `w', compare(`w1') cbar(0(.1)1)
//_14
regsensitivity plot
//_15q
qui graph export dmp_breakdown_1.png, width(500) replace
//_16
regsensitivity breakdown `y' `x' `w', compare(`w1') beta(-1(.2)1 lb)
//_17
regsensitivity breakdown `y' `x' `w', compare(`w1') cbar(0(.1)1) beta(4 ub)
//_18
regsensitivity bounds `y' `x' `w', compare(`w1') rxbar(0 2) cbar(0(.1)1) beta(4 ub)
//_19
regsensitivity plot, nolegend yrange(0 6)
//_20q
qui graph export dmp_breakdown_2.png, width(500) replace
//_21
regsensitivity bounds `y' `x' `w', compare(`w1') rybar(2)
//_22
regsensitivity plot
//_23q
qui graph export dmp_bounds_4.png, width(500) replace
//_24
regsensitivity bounds `y' `x' `w', compare(`w1') rybar(=rxbar)
//_25
regsensitivity breakdown `y' `x' `w', compare(`w1') rybar(=rxbar) cbar(0 .5 1)
//_26
capture noisily regsensitivity bounds `y' `x' `w', compare(`w1') rybar(.1)
//_27
regsensitivity bounds `y' `x' `w', compare(`w1') oster
//_28
regsensitivity bounds `y' `x' `w', compare(`w1') oster delta(-3 3 eq) plot
//_29q
qui graph export oster_idset_1.png, width(500) replace
//_30
regsensitivity plot, xline(1)
//_31q
qui graph export oster_idset_2.png, width(500) replace
//_32
regsensitivity plot, ywidth(4) xline(-1.704)
//_33q
qui graph export oster_idset_3.png, width(500) replace
//_34
regsensitivity bounds `y' `x' `w', compare(`w1') oster delta(0(.001).999 bound) plot
//_35q
qui graph export oster_idset_4.png, width(500) replace
//_36
regsensitivity plot, ywidth(1000) xline(.965)
//_37q
qui graph export oster_idset_5.png, width(500) replace
//_38
regsensitivity breakdown `y' `x' `w', compare(`w1') oster rmax(0(.1)1) beta(0 eq)
//_39
regsensitivity breakdown `y' `x' `w', compare(`w1') oster rmax(0(.1)1) beta(sign)
//_^
log close
