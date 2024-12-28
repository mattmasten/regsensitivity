*! version 1.2.0 Paul Diegert, Matt Masten, Alex Poirier 29sept24

// global default display settings
// global left_colon = 18 // placement of colon in left column of header
// global right_col  = 48 // start of right column
// global equal_col  = 63 // placement of = in right column
// global right_bord = 80 // total width of table
//
// global labels_width 35 // width of left column with c-dependence values		
// global n_dig 3         // number of decimal points for c-dependence values

// PROGRAM: Display Regsensitivity results
// DESCRIPTION: Main program to display regsensitivity estimation results
//              in stata console. [see help file]
// INPUT:
//    - shortheader: abreviate table header?
program _regsen_display

	version 15
		
	syntax , [shortheader] 
	
	tempvar cmax cqtls breakdown_table

	if "`e(cmd)'" == "regsensitivity" & "`e(subcmd)'" == "bound" {

		display_idset_table e(idset_table), `shortheader'

	}	
	else if "`e(cmd)'" == "regsensitivity" & "`e(subcmd)'" == "breakdown" {
		display_breakdown_table , `shortheader'
	}
end


// PROGRAM: Display Identified Set Table
// DESCRIPTION: Display table of identified sets for each 
// INPUT:
//    - anything: (matrix), table mapping sensitivity parameter to identified setcolumn
//                - column 1:  value of sensitivity parameter, 
//                - additional columns: pairs of lower, upper bounds or values of
//                  finite identified set.
//    - labels_width: (integer) column dividing the parameter labels and identified sets
//    - right_bord: (integer) column for the right border
//    - shortheader: see `_regsen_display`
program display_idset_table

	// process input
	syntax anything, 				///
	      [labels_width(integer 35) 		///
	       right_bord(integer 80) 			///
	       lab_digits(integer 3)			///
	       shortheader]				///
	
	tempname breakdown
	
	// =====================================================================
	// 1. details for table header
	// =====================================================================

	// Breakdown hypothesis
	local breakdown_lbl Breakdown Point
	local hypothesis_lbl Hypothesis
	
	if !`e(include_breakdown)' {
		local breakdown_lbl
	}
	else if `e(hypoval)' < .{
		local hypothesis = strofreal(`e(hypoval)', "%-10.3g")
	}
	else {
		local hypothesis Beta(Hypothesis)
	}
	if !`e(include_breakdown)' {
		local hypothesis_lbl
	}
	else if "`e(hyposign)'" == "=" {
		local hypothesis `"Beta != `hypothesis'"'
	}
	else {
		local hypothesis `"Beta `e(hyposign)' `hypothesis'"'
	}
	
	// extract summary statistics on DGP
	local n_stats = rowsof(e(sumstats))
	local stat_lbls : rownames(e(sumstats))

	forvalues row = 1/`n_stats' {
		local v = e(sumstats)[`row', 1]
		local vs `"`vs' `v'"'
		local ts `"`ts' float"'
	}
	
	
	// =====================================================================
	// 2.1 Formatting
	// =====================================================================
	
	// number of label levels
	local lab_levels: word count `r(nonscalar_sparam)'
	local lab_width_each = 4 + 1 + `lab_digits'
	
	// column labels
	
	tempname mat_sparams
	matrix `mat_sparams' = `anything'[1...,1..`lab_levels']	
	local sparams: colnames(`mat_sparams')
	local tbl_header "_col(2) as text "
	foreach sparam in `sparams' {
		local tbl_header `tbl_header' %-`lab_width_each's "`sparam'"	
	}
	local tbl_header `tbl_header' _col(`labels_width') " `e(param)'"
	
	// determine if sets should be displayed as intervals or finite sets
	if "`e(sparam1_option)'" == "eq" {
		local tuple_type set
	}
	else if "`e(sparam1_option)'" == "bound" {
		local tuple_type interval
	}
	
	// left header table
	local left_labels `"`left_labels' Analysis"' 
	local left_vals `"`left_vals' "`e(analysis)'""'
	local left_labels `"`left_labels' """' 
	local left_vals `"`left_vals' ."' 
	local left_labels `"`left_labels' Treatment"'
	local left_vals `"`left_vals' `e(indvar)'"'
	local left_labels `"`left_labels' Outcome"'
	local left_vals `"`left_vals' `e(depvar)'"'
	local left_labels `"`left_labels' """'
	local left_vals `"`left_vals' ."'
	local left_labels `"`left_labels' """'
	local left_vals `"`left_vals' ."'
	local left_labels `"`left_labels' """'
	local left_vals `"`left_vals' ."'
	local left_labels `"`left_labels' """'
	local left_vals `"`left_vals' ."'
	local left_labels `"`left_labels' """'
	local left_vals `"`left_vals' ."'
	if `e(include_breakdown)' {
		local left_labels `"`left_labels' "Hypothesis""'
		local left_vals `"`left_vals' "`hypothesis'""'
	}
	local left_labels `"`left_labels' "Other Params""'
	local left_vals `"`left_vals' "`e(other_sensparams)'""'
	
	// right header table
	local right_labels = `""Number of obs""'
	local right_vals e(N)
	local right_types int
	forvalues row = 1/`n_stats' {
		local v = e(sumstats)[`row', 1]
		local l : word `row' of `stat_lbls'
		local right_labels = `"`right_labels' "`l'""'
		local right_vals `"`right_vals' `v'"'
		local right_types `"`right_types' float"'
		
	}
	local right_labels `"`right_labels' """'
	local right_vals `"`right_vals' ."'
	local right_types `"`right_types' str"'
	if `e(include_breakdown)' {
		local right_labels `"`right_labels' "Breakdown Point""'
		if e(breakdown) < . {
			scalar `breakdown' = abs(e(breakdown))
			local right_vals `"`right_vals' `breakdown'"'
			local right_types `"`right_types' percent"'
		}
		else {
			local right_vals `"`right_vals' +inf"'
			local right_types `"`right_types' str"'	
		}
		
	}
	
	// =====================================================================
	// 2.2 Write table 
	// =====================================================================

	di 
	if "`shortheader'" == "" {
		_regsen_write_table_header, ///
			title(Regression Sensitivity Analysis, Bounds) ///
			left_labels(`left_labels') ///
			left_vals(`left_vals') ///
			right_labels(`right_labels') ///
			right_vals(`right_vals') ///
			right_types(`right_types')
			di
	}
	
	di as text `"{hline `right_bord'}"'
	di `tbl_header'
	di as text `"{hline `right_bord'}"'
	_regsen_write_tuples `anything', tuple_type(`tuple_type') lab_levels(`lab_levels')
	di as text `"{hline `right_bord'}"'

end

// PROGRAM: Display Breakdown Frontier Table
// DESCRIPTION: Display table of identified sets for each 
// INPUT:
//    - anything: (matrix), table mapping sensitivity parameter to identified setcolumn
//                - column 1:  value of sensitivity parameter, 
//                - additional columns: pairs of lower, upper bounds or values of
//                  finite identified set.
//    - labels_width: (integer) column dividing the parameter labels and identified sets
//    - right_bord: (integer) column for the right border
//    - shortheader: see `_regsen_display`
program display_breakdown_table

	syntax [anything], [shortheader *]
	
	tempname breakfront sum_stats
		
	matrix `breakfront' = e(breakfront_table)
	
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
	

	// =====================================================================
	// 1. details for table header
	// =====================================================================
	
	// Breakdown hypothesis
	if `e(hypoval)' < .{
		local hypothesis = strofreal(`e(hypoval)', "%-10.3g")
	}
	else {
		local hypothesis Beta(Hypothesis)
	}
	if "`e(hyposign)'" == "=" {
		local hypothesis `"Beta != `hypothesis'"'
	}
	else {
		local hypothesis `"Beta `e(hyposign)' `hypothesis'"'
	}	
	
	// summary stats
	local nrows = rowsof(e(sumstats))
	local lbls : rownames(e(sumstats))
	
	// unpack the matrix of summary stats into a macro to be displayed
	forvalues row = 1/`nrows' {
		local v = e(sumstats)[`row', 1]
		local l : word `row' of `lbls'
		local ls `"`ls' "`l'""'            // label
		local vs `"`vs' `v'"'              // value
		local ts `"`ts' float"'	           // format
	}
	
	local otherparams 
	if "`e(other_sparams)'" != ""{
		local otherparams = `""Other Params""'
	}
	
	// =====================================================================
	// 2.2 Write table 
	// =====================================================================
	
	di 
	
	if "`shortheader'" == ""{
		_regsen_write_table_header, title(Regression Sensitivity Analysis, Breakdown Frontier) ///
			left_labels(Analysis "" Treatment Outcome "" "" "" Hypothesis `otherparams' ) ///
			left_vals("`e(analysis)'" . `e(indvar)' `e(depvar)' . . . `"`hypothesis'"' `"`e(other_sparams)'"') ///
			right_labels("Number of obs" `ls' "") ///
			right_vals(`e(N)' `vs') ///
			right_types(int `ts' str)
	}
	else {
		_regsen_write_table_header, title(Regression Sensitivity Analysis, Breakdown Frontier) ///
			left_labels(Analysis Treatment Outcome Hypothesis `otherparams' ) ///
			left_vals("`e(analysis)'" `e(indvar)' `e(depvar)' `"`hypothesis'"' `"`e(other_sparams)'"')
		 di 
	}
	
	_regsen_write_scalar_table `breakfront', `options' percent

end
