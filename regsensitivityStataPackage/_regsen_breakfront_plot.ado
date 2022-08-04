*! version 1.1.0  1aug2022

// PROGRAM: Plot Breakdown Frontier
// DESCRIPTION: Post-estimation command to plot identified set
// INPUTS: [see help]

program _regsen_breakfront_plot
	
	version 15
	
	syntax [anything] [, LColor(string) ///
	                     title(string asis) subtitle(string asis) /// 
			     xtitle(string) ytitle(string) ///
			     graphregion(string) bgcolor(string) ///
			     ylabel(string) yscale(string) ///
			     xlabel(string) xscale(string)) name(string) *] 		
	
	
	// =========================================================================
	// 1. Temp names
	// =========================================================================
	
	tempname temp_results breakfront
	
	// =========================================================================
	// 2. Process input
	// =========================================================================
	
	matrix `breakfront' = e(breakfront)
	
	// report the absolute values of the breakdown frontier
	// IMPLEMENTATION NOTE: looping stata rather than vectorized mata
	// because that drops the labels and because it overwrites .b, which
	// is the code we are using for +inf
	local nbreakfront : rowsof(`breakfront')
	forvalues i=1/`nbreakfront'{
		if `breakfront'[`i', 2] < .{
			matrix `breakfront'[`i', 2] = abs(`breakfront'[`i', 2]) 
		}
	}
	
	// save the parameter names for the axis labels
	local axis_labels : colnames e(breakfront)
	
 	matrix colname `breakfront' = x y
	
	svmat `breakfront', names(col)
	
	// defaults for y axis
	if ("`axis_labels'" == "cbar rxbar(Breakdown)"){
		local yscale_default "r(0,1)"
	} 
	else {
		local yscale_default "extend" 
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
		local subtitle `""Regression Sensitivity Analysis (DMP 2022), Breakdown""' 
	}
	else if "`e(analysis)'" == "Oster (2019)"{
		local subtitle `""Regression Sensitivity Analysis (Oster 2019), Breakdown""' 
	} 
		
	// process overall display options with defaults
	local poptions xtitle ytitle /*
	             */graphregion plotregion /*
		     */ylabel yscale /*
		     */xlabel xscale /*
		     */name /*
		     */lcolor
	local defaults `axis_labels' /*
	             */"color(white)" "color(white) margin(b=3 l=0 t=3 r=0)" /*
	             */"#6, nogrid angle(0) notick" "`yscale_default'" /*
		     */",nogrid angle(0) notick" "noextend" /*
		     */`e(param)' gs0
	local noptions : word count `poptions'
	forvalues i = 1/`noptions'{
		local option : word `i' of `poptions'
		local default : word `i' of `defaults'
		if "``option''" == ""{
			local `option' `default'
		}
	}
	
	// =========================================================================
	// 3. Main plot
	// =========================================================================
	
	
	
	twoway line y x, lcolor(`lcolor') ///
	title(`title') subtitle(`subtitle') xtitle(`xtitle') ytitle(`ytitle') /// 
	graphregion(`graphregion') plotregion(`plotregion') ///
	ylabel(`ylabel') yscale(`yscale') /// 
	xlabel(`xlabel') xscale(`xscale') ///
	name(`name', replace)/*
	*/`options'	
	
	drop x y


end




