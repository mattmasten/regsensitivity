*! version 1.0.0  6jun2022

// PROGRAM: Plot Identified Set
// DESCRIPTION: Post-estimation command to plot identified set
// INPUTS: [see help]
program _regsen_idset_plot
	
	version 15
	
	syntax [anything] [, noBreakdown ///
			     boundpatterns(string) /// 
			     boundcolors(string) ///
			     boundoptions(string) ///
			     breakdownoptions(string) ///
			     title(string asis) subtitle(string asis) ///
			     xtitle(string) ytitle(string) ///
			     graphregion(string) bgcolor(string) ///
			     ylabel(string) yrange(numlist) ywidth(integer -1) ///
			     name(string) ///
			     legoptions(string) ///
			     noLEGend *]		
	
	// =========================================================================
	// 1. Temp names
	// =========================================================================
	
	tempname idset bmed stdx
	tempfile active_data
	
	quietly save `active_data'
	quietly clear
	
	// =========================================================================
	// 2. Process input
	// =========================================================================
	
	if `ywidth' < 0{
		// if ywidth not given and not plotting oster equal, get the
		// width as the 95th percentile of the values
		matrix `idset' = e(idset1)
		local varx = 1 / e(sumstats)["Var(X)", 1]
		local beta_med = e(sumstats)["Beta(medium)", 1]
		mata: ywidth = ywidth_default(st_matrix("`idset'"), `varx', `beta_med', .95)
		mata: st_local("ywidth", strofreal(ywidth))
	}
	if "`yrange'" != ""{
		// use yrange directly if given
		tokenize `yrange'
		local ymin `1'
		local ymax `2'
		local ylabmin = ceil(`ymin')
		local ylabmax = floor(`ymax')
		local ylabmid = round(e(sumstats)["Beta(medium)", 1])
		if !(`ylabmid' < `ylabmax' & `ylabmid' > `ylabmin'){
			local ylabmid 
		} 
		local labdist = min(`ylabmax' - `ylabmid', `ylabmid' - `ylabmin')
		local labdistmax = `ylabmax' - `ylabmin'
		if `labdist' < `labdistmax' * .05{
			local ylabmid 
		} 
		local ylabel "`ylabmin' `ylabmid' `ylabmax', norescale nogrid angle(0) notick"
	}
	else {
		// otherwise get yrange from ywidth
		scalar `stdx' = 1/sqrt(e(sumstats)["Var(X)", 1])
		scalar `bmed' = e(sumstats)["Beta(medium)", 1]
		local ylabmid = round(`bmed')
		local ylabwidth = floor(`stdx' * `ywidth')
		local ylabmin = `ylabmid' - `ylabwidth'
		local ylabmax = `ylabmid' + `ylabwidth'
		local ymin = `bmed' - (`stdx' * `ywidth')
		local ymax = `bmed' + (`stdx' * `ywidth')
		local ylabel "`ylabmin' `ylabmid' `ylabmax', nogrid angle(0) notick"

	}
	
	
	local nsparam2: rowsof e(sparam2_vals)

	// default to no legend
	local leg `"legend(off)"'
	if "`legoptions'" == ""{
		local legoptions pos(3) cols(1) subtitle(`e(sparam2)')
	}
	else {
		local legoptions `legoptions' subtitle(`e(sparam2)') 
	}
	
	// process breakdown point
	if "`breakdown'" == ""{
		local yl = `e(hypoval)'
		if `yl' >= . {
			local yl = 0
		}
		if "`breakdownoptions'" == ""{
			local breakdownline `"yline(`yl',lcolor(black) lwidth(vthin)) "'
		}
		else {
			local breakdownline `"yline(`yl', `breakdownoptions') "'
		}
	}

	
	// process line patterns and colors for bounds
	if "`boundpatterns'" == ""{
		local boundpatterns solid dash dot dash_dot shortdash /*
		*/shortdash_dot longdash longdash_dot "_-" /*
		*/"_--" "_-#.-"
	}
	else {
		local npatterns : word count `boundpatterns'
		if `npatterns' == 1 {
			local b `boundpatterns'
			local boundpatterns `b' `b' `b' `b' `b' `b' `b' `b' `b' `b' `b'
		}
	}
	if "`boundcolors'" == ""{
		local boundcolors gs0 gs0 gs0 gs0 gs0 gs0 gs0 gs0 gs0 gs0 gs0
	}
	else {
		local ncolors : word count `boundpatterns'
		if `ncolors' == 1 {
			local b `boundcolors'
			local boundcolors `b' `b' `b' `b' `b' `b' `b' `b' `b' `b' `b'
		}
	}
	
	// process legend for multiple plots
	if `nsparam2' > 1 {
		forvalues i= 1/`nsparam2' {
			local cval = e(sparam2_vals)[`i', 1]
			local line_num = `i' * 2
			local leg_lab `"`leg_lab' label(`line_num' "`cval'") "'
			local leg_ord `"`leg_ord' `line_num'"'
		}
		local leg `"legend(order(`leg_ord') `leg_lab' `legoptions'"'
		if !regexm(`"`leg'"', " pos\(.*\)") {
			local leg `"`leg' pos("bottom")"'
		}
		local leg `"`leg')"'
	}
	
	
	// title default (note: this is a hack because you can't include
	// notitle and title(string) as options - they both use the title macro,
	// instead this will manually check the extra options for a notitle option)
	local notitle_name notitle
	local notitle: list notitle_name in options
	if `notitle' {
		local options: list options - notitle_name
	}
	if `"`subtitle'"' != "" | `"`title'"' != "" {
		break
	}
	else if `notitle'{
		local subtitle 
	}
	else if "`e(analysis)'" == "DMP (2022)" {
		local subtitle `""Regression Sensitivity Analysis (DMP 2022), Bounds""' 
	}
	
	// process overall display options with defaults
	local poptions xtitle ytitle /*
	             */graphregion plotregion /*
		     */ylabel yscale /*
		     */xlabel xscale /*
		     */name
	local defaults `e(sparam1)' `e(param)' /*
	             */"color(white)" "color(white) margin(b=3 l=0 t=3 r=0)" /*
	             */",nogrid angle(0) notick" "extend" /*
		     */",nogrid angle(0) notick" "noextend" /*
		     */`e(param)' 
	local noptions : word count `poptions'
	forvalues i = 1/`noptions'{
		local option : word `i' of `poptions'
		local default : word `i' of `defaults'
		if "``option''" == ""{
			local `option' `default'
		}
	}
	
	// process additional formatting options
	// NOTE: the syntax of combining graphs (using ||) seems to be sensitive 
	//       to an extra space so need to have no space if there are no options 
	//       but a space after the options if there are.
	if `"`'options'"' != ""{
		local options "`options' "
	}
	
	// Overide to drop legend if option specified
	if "`legend'" == "nolegend" {
		local leg `"legend(off)"'
	}
	
	local plotspecs title(`title') subtitle(`subtitle') xtitle(`xtitle') ytitle(`ytitle') /*
		   */ graphregion(`graphregion') plotregion(`plotregion') /*
		   */ ylabel(`ylabel') yscale(`yscale') /* 
		   */ name(`name', replace) /*
		   */ `options'	/*
		   */ `breakdownline'

	
	
	// =========================================================================
	// 3. Main plot
	// =========================================================================
	

	// save identified set values to active dataset
	forvalues i= 1/`nsparam2' {
		matrix `idset' = e(idset`i')
		matrix colnames `idset' = rx`i' lower`i' upper`i'
		quietly svmat `idset', names(col)
	}

	forvalues i=1/`nsparam2'{
		local lp : word `i' of `boundpatterns'
		local lc : word `i' of `boundcolors'
		local newplot_ub `"(line upper`i' rx`i', lc(`lc') lp(`lp') `boundoptions')"'
		local newplot_lb `"(line lower`i' rx`i', lc(`lc') lp(`lp') `boundoptions')"'
		local lineplots `"`lineplots' `newplot_ub' `newplot_lb'"'
		quietly replace lower`i' = . if lower`i' < `ymin'
		quietly replace upper`i' = . if upper`i' > `ymax'
	}
	
	twoway `lineplots', `plotspecs' `leg' xlabel(`xlabel') xscale(`xscale') 
		
		
	quietly use `active_data', clear

end

mata:

real colvector quantiles(
	real colvector y, 
	real colvector p
){
	ys = sort(y, 1)
	n = rows(ys)

	q = J(rows(p), 1, .)
	for (j = 1; j <= rows(p); j++){
	    i = 1
	    while((i/n) < p[j]) i++
	    q[j] = ys[i]
	}
	return(q)
}

real scalar ywidth_default(
	real matrix idset,
	real scalar varx,
	real scalar beta_med,
	real scalar p
){
	idset = select(idset, idset[,3] :< .)
	ywidth = quantiles(idset[,3], (p))
	ywidth = ((ywidth - beta_med) / sqrt(varx)) + .1 
	return(ywidth)
}

end


