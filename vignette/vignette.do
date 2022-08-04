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
forvalues i=1/11{
    local rxbar `rxbar' `=e(idset_table)[`i', 1]'
}
regsensitivity bounds `y' `x' `w', compare(`w1') cbar(.1) rxbar(`rxbar') 
//_9
regsensitivity bounds `y' `x' `w', compare(`w1') cbar(0(.2)1) 
//_10q
qui graph export dmp_bounds_2.png, width(700) replace
//_11
regsensitivity bounds `y' `x' `w', compare(`w1') cbar(0(.2)1) rxbar(0(.2)2) plot
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
regsensitivity bounds `y' `x' `w', compare(`w1') rxbar(0(.2)2) cbar(0(.1)1) beta(4, ub)
//_19
regsensitivity plot, nolegend yrange(0 6)
//_20q
qui graph export dmp_breakdown_2.png, width(500) replace
//_21
regsensitivity bounds `y' `x' `w', compare(`w1') oster
//_22
regsensitivity bounds `y' `x' `w', compare(`w1') oster delta(-3(.3)3, eq) plot
//_23q
qui graph export oster_idset_1.png, width(500) replace
//_24
regsensitivity plot, ywidth(500) xline(1)
//_25q
qui graph export oster_idset_2.png, width(500) replace
//_26
regsensitivity plot, ywidth(4) xline(-1.704)
//_27q
qui graph export oster_idset_3.png, width(500) replace
//_28
regsensitivity bounds `y' `x' `w', compare(`w1') oster delta(0(.1).9 .999 1, bound) plot
//_29q
qui graph export oster_idset_4.png, width(500) replace
//_30
local breakdown = e(breakdown)
qui regsensitivity bounds `y' `x' `w', compare(`w1') oster delta(0.9(.001).99 .999 1, bound)
regsensitivity plot, yrange(-150 5) xline(`breakdown')
//_31q
qui graph export oster_idset_5.png, width(500) replace
//_32
regsensitivity breakdown `y' `x' `w', compare(`w1') oster r2long(0(.1)1) beta(0, eq)
//_33
regsensitivity breakdown `y' `x' `w', compare(`w1') oster r2long(0(.1)1) beta(sign)
//_34
regsensitivity bounds `y' `x' `w', compare(`w1') oster delta(0(.1)1, bound) beta(sign) maxovb(3)
//_35
regsensitivity bounds `y' `x' `w', compare(`w1') oster delta(-3(.3)3)
regsensitivity plot, yline(-1.05) yline(5.05) yrange(-20 5)
//_36q
qui graph export oster_breakdown_restricted.png, width(500) replace
//_37
regsensitivity breakdown `y' `x' `w', compare(`w1') oster beta(sign) r2long(0(.1)1) maxovb(22)
//_38
regsensitivity breakdown `y' `x' `w', compare(`w1') oster beta(sign) maxovb(2(10)100)
//_39
regsensitivity bounds `y' `x' `w', compare(`w1') oster delta(-3(.3)3, eq) r2long(1.3, relative)
//_40
regsensitivity bounds `y' `x' `w', compare(`w1') oster beta(sign) maxovb(2, relative)
//_^
log close
