*! version 1.1.0 Paul Diegert, Matt Masten, Alex Poirier 1aug2022

********************************************************************************
** PROGRAM: Regression Sensivitity
********************************************************************************
// Notes on Organization of Code
// - There are types of output, the identified set and the breakdown frontier,
//   which can be peformed for two papers DMP (2022) and Oster (2019). There
//   are 4 Stata programs handle an ouput for a paper. These are:
//   	- `bounds_dmp`
//   	- `bounds_oster`
//   	- `breakdown_dmp`
//   	- `breakdown_oster`
// - These are wrappers for Mata funcitons that calculate the output. The Stata
//   programs are primarily responsible for handling inputs. The top-level mata
//   functions are:
//      - identified_set (for DMP (2022))
//      - breakdown_frontier (for DMP (2022))
//      - oster_idset_eq (identified set when delta is equal to input values)
//      - oster_idset_bound (identified set when delta is bounded by input values)
//      - oster_breakdown_eq (breakdown point for hypothesis Beta != input values)
//      - oster_breakdown_bound (breakdown point for hypothesie Beta > input values)
// - All sensitivity analysis depend only on the variance matrix of (Y, X, W1),
//   so before running any analysis, the Stata Program `load_dgp` calls a mata
//   program `get_dgp` to calculate this variance matrix and parameters derived
//   from it and store this in memory.
// - Higher-level Stata wrappers are provided for each of the outputs
//      - `bounds`
//      - `breakdown`
//   which are in turn called by the top level interface, `regsensitivity`
// - In addition to the main analysis, there is also a post-estimation command
//   `plot` which calls the _regsen_<output_type>_plot command depending on the
//   subsommand to last call to `regsensitivity`.

// PROGRAM: Regsensitivity
// DESCRIPTION: Main interface [see help file]
program define regsensitivity, eclass

	version 15
	
	// check if called with a subcommand or not
	local subcommands bounds breakdown plot
	
	gettoken subcommand 0 : 0
	
	// correct parsing of comma if no space after subcommand
	if regexm("`subcommand'", ",$"){
		local subcommand = substr("`subcommand'", 1, strlen("`subcommand'") - 1)
		local 0 ,`0'
	}
	
	local issubcommand : list subcommand in subcommands
	
	// if no subcommand, run `summary`
	if(!`issubcommand'){
		local 0 `subcommand' `0'
		local subcommand summary
	}
	
	// allow automatic plotting
	local plot plot
	local ploton : list plot in 0
	local 0 : list 0 - plot
	local plot `ploton'

	// This loads the dgp summary stats into mata global memory which the
	// other subprocesses will use
	if("`subcommand'" != "plot"){
		quietly load_dgp `0'
	}
	
	if("`subcommand'" == "summary"){
		summary `0'
	}
	else if("`subcommand'" == "breakdown"){
		breakdown `0'
		_regsen_display
		if `plot' _regsen_breakfront_plot
	}
	else if("`subcommand'" == "bounds"){
		bounds `0'
		local nsparam2 : rowsof e(sparam2_vals)
		if `nsparam2' == 1 {
			_regsen_display
			if `plot' _regsen_idset_plot
		}
		else {
			_regsen_idset_plot
		}
		
	}
	else if("`subcommand'" == "plot"){
		if "`e(subcmd)'" == "bound"{
			quietly _regsen_idset_plot `0'
		}
		else if "`e(subcmd)'" == "breakdown"{
			quietly _regsen_breakfront_plot `0'
		}
	}
	capture scalar drop nobs
	// clear mata memory
	
end

// PROGRAM: Load DGP
// DESCRIPTION: Load the summary statistics used to perform all sensitivity
//              analysis into Mata memory. All analysis is performed using the
//              transformed variables z = M(Y, X, W1), where M = (I - P) and P
//              is the projection onto W0. The sensitivity parameters only
//              depend on Var(Z), which is what is stored in Mata memory. 
// INPUT: 
//   - varlist: (varname varname varlist) the dependent and independent variables
//   - compare: (varlist)
//   - options (anything) aditional options will be ignored 

program define load_dgp

	syntax varlist (fv ts) [if] [in], [compare(varlist fv ts) nocompare(varlist fv ts) *]
	
	tempfile active_data
	
	quietly save `active_data'
	
	marksample touse
	quietly keep if `touse'
	
	local y: word 1 of `varlist'
	local x: word 2 of `varlist'
	local w: list varlist - y
	local w: list w - x
	
	if "`compare'" != "" {
		local w1 `compare'
		local w0 : list w - w1
	}
	else if "`nocompare'" != "" {
		local w0 `nocompare'
		local w1 : list w - w0
	}
	else {
		local w1 `w'
	}
	
	local yxw1 `y' `x' `w1'
	
	// In order to project Y, X, W1 onto W0, we have to expand any
	// factor or time series variables manually and work with the dummies
	quietly fvrevar `yxw1'
	local yxw1 `r(varlist)'

	// Project (Y,X,W1) and replace variables with the residual.
	foreach v of local yxw1 {
		quietly regress `v' `w0'
		quietly predict `v'r, resid
		quietly replace `v' = `v'r
		quietly drop `v'r
	}
	
	// Get the names of the expanded variables to save the DGP to Mata.
	local w1expanded : list yxw1 - y
	local w1expanded : list w1expanded - x
	
	mata: dgp = get_dgp("`y'", "`x'", "`w1expanded'")
	scalar nobs = _N
	
	quietly use `active_data', clear

end

program define summary

	syntax varlist (fv ts) [if] [in], [compare(varlist fv ts) ///
			nocompare(varlist fv ts)]
		
	di
	
	// dmp bounds
	bounds `varlist', compare(`compare') nocompare(`compare') dmp 
	_regsen_display
	
	// oster breakdown points
	mata: st_local("r2rot", strofreal(min((dgp.r_med * 1.3, 1))))
	breakdown `varlist', w1(`w1') w0(`w0') oster r2long(`r2rot' 1)
	_regsen_display , shortheader

end

********************************************************************************
****** Identified Set
********************************************************************************

// PROGRAM: Identified Set
// DESCRIPTION: Calculate the identified set. 
// INPUT: 
//   - varlist, w1, w0: See `load_dgp`
//   - oster, dmp (on/off): choose the analysis
//   - cbar, rxbar, delta, r2long: (param_spec) Range and option for the
//        sensitivity parameters used in the analysis. see `parse_sensparam`
//   - beta: (hypothesis) Specifies the hypothesis for the breakdown point,
//        see `parse_beta`
//   - ngrid: (integer) Number of points in the grid of sensitivity parameter
//        values when grid is not explicitly given  
// RETURN:
//   - see help file

program define bounds, eclass

	syntax varlist (fv ts) [if] [in], [compare(varlist fv ts) ///
			nocompare(varlist fv ts) ///
			oster dmp ///
			Cbar(string) RXbar(string) ///
			r2long(string) delta(string) ///
			beta(string) ngrid(integer 200) ///
			maxovb(string) *]
	
	tempname hypoval
	
	// extract variable lists
	local y: word 1 of `varlist'
	local x: word 2 of `varlist'
	local w: list varlist - y
	local w: list w - x
	
	if "`compare'" != "" {
		local w1 `compare'
		local w0 : list w - w1
	}
	else if "`nocompare'" != "" {
		local w0 `nocompare'
		local w1 : list w - w0
	}
	else {
		local w1 `w'
	}
	
	// defaults
	if "`oster'" == "" & "`dmp'" == ""{
		local dmp dmp
	}
	
	// check that multiple hypotheses not specified for beta
	_format_option_input `beta'
	parse_beta `s(formatted_option_input)'
	capture scalar `hypoval' = `s(hypoval)'
	if _rc == 198{
		di as error "Cannot specify multiple hypotheses when " /*
		*/ "with regsensitivity bounds, try using regsensitivity " /*
		*/ "breakdown"
	}
	//local hyposign `s(hyposign)'

	if "`oster'" != ""{
		local other_sparam_fmt "%5.3g"
		
		// defaults for beta hypothesis type
		// 1. If |delta| < d, and beta not given -> beta(sign)
		// 2. If delta = d, and beta not given, default -> beta(0 eq)
		// 3. If delta = d, and beta(#) given, default -> beta(# eq)
		
		local eq equal
		local bound bound
		
		_format_option_input `delta'
		local delta_options `s(options)'
		local delta_is_equal : list eq in delta_options
		local delta_is_bound : list bound in delta_options
		
		_format_option_input `beta'
		local beta_options `s(options)'

		local bound lb ub sign
		local beta_is_equal : list eq in beta_options
		local beta_option_bound : list bound & beta_options
		local beta_is_bound = "`beta_option_bound'" != ""
		
		// breakdown frontier defaults dependent on how idset is calculated
		if "`delta'" == "" & `beta_is_bound'{
			local delta "0(.1)1, bound"
		}
		else if "`beta'" == "" & `delta_is_bound' {
			local beta "sign"
		}
		else if "`beta'" == "" & `delta_is_equal' {
			local beta "0, equal" 
		}
		else if !`beta_is_bound' & !`beta_is_equal' & `delta_is_equal'{
			local beta "`s(args)', `s(options)' equal"
		}
		else if `beta_is_bound' & `delta_is_equal'{
			di as error "breakdown frontier can only be calcualted for " ///
				"an inequality hypothesis when using delta = #"
			exit 198
		}
		
		idset_oster , delta(`delta') r2long(`r2long') maxovb(`maxovb') ngrid(`ngrid')
		
		// TODO: not implemented errors?
		if `r(nsparam2)' == 1 {
			breakdown_oster, r2long(`r2long') beta(`beta') maxovb(`maxovb')
			scalar breakdown = r(breakfront)[1,2]
			local r2long = r(sparam2_vals)[1,1]
			
			local r2long_fmt = strofreal(`r2long', "`other_sparam_fmt'")
			local other_sensparams "R-squared(long) = `r2long_fmt'"
			local hyposign "`r(hyposign)'"
			if `r(maxovb)' < .b {
				local maxovb = r(maxovb)
				local maxovb_fmt = strofreal(`maxovb', "`other_sparam_fmt'")
				local other_sensparams "`other_sensparams', max OVB = `maxovb_fmt'"
			}
		}
	}
	else if "`dmp'" != "" {
		return clear
		idset_dmp , rxbar(`rxbar') cbar(`cbar')	ngrid(`ngrid')
		if `r(nsparam2)' == 1 {
			breakdown_dmp , cbar(`cbar') beta(`beta')
			scalar breakdown = r(breakfront)[1,2]
			local cbar = r(sparam2_vals)[1,1]
			local other_sensparams "cbar = `cbar', rybar = +inf"
			local hyposign "`r(hyposign)'"
		}
	}
	
	// summary stats
	mata: save_dgp_stats(dgp)
	
	// macros
	ereturn post, depname(`y') properties()
	
	ereturn local hyposign "`hyposign'"
	ereturn local sparam2_option `r(sparam2_option)'
	ereturn local sparam2 `r(sparam2)'
	ereturn local sparam1_option `r(sparam1_option)'
	ereturn local sparam1 `r(sparam1)'
	ereturn local param "Beta"
	ereturn local analysis `r(analysis)'
	ereturn local compare `w1'
	ereturn local controls `w'
	ereturn local indvar : word 2 of `varlist'
	ereturn local depvar `y'
	ereturn local cmdline `"regsensitivity bound `0'"'
	ereturn local subcmd bound
	ereturn local cmd regsensitivity

	// scalars
	capture ereturn scalar breakdown = breakdown
	ereturn scalar hypoval = `hypoval'
	ereturn scalar N =  nobs
	
	// matrices
	forvalues i = 1/`r(nsparam2)'{
		matrix idset`i' = r(idset`i')
		ereturn matrix idset`i' = idset`i'
	}
	matrix sparam2_vals = r(sparam2_vals)
	ereturn matrix sparam2_vals = sparam2_vals
	matrix idset_table = r(idset_table)
	ereturn matrix idset_table = idset_table
	ereturn matrix sumstats = stats
	
	// internal
	if `r(nsparam2)' == 1{
		ereturn hidden local other_sensparams = `"`other_sensparams'"'
		ereturn hidden local ntables = `r(nsparam2)'
	}

	if "`r(sparam1_option)'" == "eq" & "`oster'" == "oster" {
		// These are the asymptotes of the function delta -> beta, used 
		// for the plot when delta == d
		matrix roots = r(roots) 
		ereturn hidden matrix roots = roots
	}


end

// PROGRAM: Identified Set, DMP (2022)
// DESCRIPTION: Calculate the identified set for the analysis in Diegert, Masten,
//              Poirier (2022)
// NOTES:
//   - Allows bound option only for rxbar and cbar.
// INPUT: 
//   - cbar, rxbar: (param_spec) Range and option for the
//        sensitivity parameters used in the analysis. see `parse_sensparam`
//   - ngrid: (integer) Number of points in the grid of sensitivity parameter
//        values when grid is not explicitly given  
// RETURNS:
//   - idset_table: (matrix) table mapping values of rxbar to identified set,
//                  to be used in displayed output. 
//   - sparam2_vals: (matrix) table of values of cbar.
//   - idset#: (matrix) table mapping values of rxbar to identified set, 
//             holding cbar fixed at # of sparam2_vals. Includes a finer grid 
//             of values to be used in plotting and to be saved in e().
//   - additional metadata: sparam1, sparam1, sparam1_option, sparam2_option,
//             analysis
program define idset_dmp, rclass

	syntax , [rxbar(string) cbar(string) ngrid(integer 200) *]

	tempvar rx_mat c_mat breakdown

	// parse cbar
	if "`cbar'" == "" local cbar 1 // default
	
	_format_option_input `cbar' default(bound)
	_parse_formatted_sensparam `s(formatted_option_input)'
	local cbar `s(param)'
	local sparam2_option `s(paramtype)'
	if "`sparam2_option'" == "eq"{
		di as error "DMP (2022) identified set is not implemented for cbar = c"
		exit 198
	}
	_numlist_to_matrix `cbar', name(`c_mat')
	local ncbar : rowsof `c_mat'

	
	// parse rxbar
	if "`rxbar'" == ""{
		// default to range [0, rxmax], rxmax is the point where
		// identified set is (-inf, +inf)
		mata: rxmax = max_beta_bound(st_matrix("`c_mat'")[1,1] * .95, dgp)  
		// TODO: arbitrary multiplier
		mata: st_local("rxmax", strofreal(rxmax))
		local step = `rxmax' / 10
		local rxbar 0(`step')`rxmax'
	}
	
	_format_option_input `rxbar' default(bound)
	_parse_formatted_sensparam `s(formatted_option_input)'
	local rxbar `s(param)'
	local sparam1_option `s(paramtype)'
	_numlist_to_matrix `rxbar', name(`rx_mat')
	
	if "`sparam1_option'" == "bound" {
	
		// calcualates the identified set and saves it to matrix idset#
		// for each # in the values of cbar
		mata: identified_set(st_matrix("`c_mat'"), st_matrix("`rx_mat'"), dgp)
		
		// format the output table to stop at first value above threshold
		// where the identified set is [-inf, +inf] and add the exact
		// point where that happens. If there are multiple values of cbar
		// use only the last.
		local c = `c_mat'[`ntables',`ntables']
		mata: bounds_table("idset`ntables'", ///
		   st_matrix("`rx_mat'"), "dmp", dgp, `c')
		// output table is saved to idset_table
		   
		   
		// if the grid is too coarse, recalculate for a finer grid for
		// plotting, and save this 
		local nrxpoints : rowsof `rx_mat'
		if `nrxpoints' < `ngrid'{
			mata: st_matrix("`rx_mat'", ///
					rangen(min(st_matrix("`rx_mat'")), ///
				max(st_matrix("`rx_mat'")), `ngrid'))
			mata: identified_set(st_matrix("`c_mat'"), ///
					     st_matrix("`rx_mat'"), dgp)
		} 

	}
	else {
		di as error "DMP (2022) identified set is not implemented for rxbar = r"
		exit 198
		
	}
	
	// returns
	return local analysis DMP (2022)
	return matrix idset_table = idset_table
	forvalues i = 1/`ntables'{
		return matrix idset`i' = idset`i'
	}
	return matrix sparam2_vals `c_mat'
	return local sparam1 rxbar
	return local sparam2 cbar
	return local sparam1_option `sparam1_option'
	return local sparam2_option `sparam2_option'
	return local nsparam2 `ntables'

	
end

// PROGRAM: Identified Set, Oster (2019)
// DESCRIPTION: Calculate the identified set for the analysis in Oster (2019)
// INPUT: 
//   - delta, r2long: (param_spec) Range and option for the
//        sensitivity parameters used in the analysis. see `parse_sensparam`
//   - ngrid: (integer) Number of points in the grid of sensitivity parameter
//        values when grid is not explicitly given  
// RETURNS:
//   - idset_table: (matrix) table mapping values of rxbar to identified set,
//                  to be used in displayed output. 
//   - sparam2_vals: (matrix) table of values of r2long.
//   - idset#: (matrix) table mapping values of rxbar to identified set, 
//             holding r2long fixed at # of sparam2_vals. Includes a finer grid 
//             of values to be used in plotting and to be saved in e().
//   - additional metadata: sparam1, sparam1, sparam1_option, sparam2_option 
//        (names and options for the two sensitivity parameters), analysis 
//        (name of the analysis) 
//   - roots: (matrix, internal) The asymptotes of the function delta -> beta,
//            used to help plot the identified set when param1_option == eq
program define idset_oster, rclass

	syntax , [maxovb(string) r2long(string) delta(string) ngrid(integer 200) *]

	tempname delta_mat r_mat maxovb_mat

	if "`r2long'" == ""{
		local r2long 1 eq
	}
	if "`delta'" == ""{
		local delta -.99(.01).99 eq
	}
	if "`maxovb'" == ""{
		local maxovb -1
	}
	
	_format_option_input `delta' default(eq)
	parse_sensparam `s(formatted_option_input)' 
	local delta `s(param)'
	local sparam1_option `s(paramtype)'

	_format_option_input `r2long' matrix_name("`r_mat'")
	parse_r2long `s(formatted_option_input)' 
	local r2long `s(param)'
	local sparam2_option `s(paramtype)'
	local nsparam2 : rowsof `r_mat'
	
	_format_option_input `maxovb' matrix_name("`maxovb_mat'")
	parse_maxovb `s(formatted_option_input)'
	local maxovb `s(maxovb)'
	
	if "`sparam2_option'" == "bound"{
		di as error "Oster (2019) identified set is not implemented for " /*   
		*/          "|R-squared(long)| < r"
		exit 198
	}
	
	if (`nsparam2' > 1) & ("`sparam1_option'" == "eq") {
		di as error "Oster (2019) identified set can only be calculated " /*
			 */ "for one value of R-squared(long) when calcualted for " /*
			 */ "Delta = d"
		exit 198
	}
	
	
	// case one delta: eq
	if "`sparam1_option'" == "eq" { 
		_numlist_to_matrix `delta', name(`delta_mat')
		// returns results to idset# for each value of r-squared(long) 
		// and the local ntables
		mata: oster_idset_eq(st_matrix("`r_mat'"), st_matrix("`delta_mat'"), st_matrix("`maxovb_mat'"), dgp)
		// formats the idset table to have three columns
		mata: set_table("idset`ntables'")
		// save the points where the delta -> beta function has asymptotes
		// this is just for formatting the plot
		mata: oster_delta_asymptotes(`r2long', dgp)
		// TODO: will this fail if you try to pass mulitple values of r2long?
	}
	
	// case two delta: bound
	else if "`sparam1_option'" == "bound" {
		_numlist_to_matrix `delta', name(`delta_mat') lb(0)
		mata: oster_idset_bound(st_matrix("`r_mat'"), ///
		                        st_matrix("`delta_mat'"), st_matrix("`maxovb_mat'"), dgp)
		mata: bounds_table("idset`ntables'", st_matrix("`delta_mat'"), "oster", dgp)
		local ndeltapoints : rowsof `delta_mat'
		if `ndeltapoints' < `ngrid'{
			mata: st_matrix("`delta_mat'", ///
					rangen(min(st_matrix("`delta_mat'")), ///
					max(st_matrix("`delta_mat'")), `ngrid'))
			mata: oster_idset_bound(st_matrix("`r_mat'"), ///
		                        st_matrix("`delta_mat'"), st_matrix("`maxovb_mat'"), dgp)
		} 

	}
	// returns
	return local analysis Oster (2019)
	return matrix idset_table = idset_table
	forvalues i = 1/`ntables'{
		return matrix idset`i' = idset`i'
	}
	return matrix sparam2_vals `r_mat'
	return local sparam1 Delta
	return local sparam2 R-squared(long)
	return local sparam1_option `sparam1_option'
	return local sparam2_option `sparam2_option'
	return local nsparam2 `nsparam2'
	
	if "`sparam1_option'" == "eq" {
		return matrix roots = roots
	}

end

********************************************************************************
***** Breakdown Frontier
********************************************************************************

// PROGRAM: Breakdown Frontier
// DESCRIPTION: Calculate the Breakdown Frontier. 
// INPUT: 
//   - varlist, w1, w0: See `load_dgp`
//   - oster, dmp (on/off): choose the analysis
//   - cbar, rxbar, delta, r2long: (param_spec) Range and option for the
//        sensitivity parameters used in the analysis. see `parse_sensparam`
//   - beta: (hypothesis) Specifies the hypothesis for the breakdown point,
//        see `parse_beta`
//   - betabound: (real scalar) When calculating the Oster breakdown frontier
//                with the `bound` option, specifies a maximum value of beta 
//   - ngrid: (integer) Number of points in the grid of sensitivity parameter
//        values when grid is not explicitly given  
// RETURN:
//   - see help file

program define breakdown, eclass

	syntax varlist (fv ts) [if] [in], [compare(varlist fv ts) ///
			nocompare(varlist fv ts) ///
			beta(string) maxovb(string) ///
			oster dmp ///
			Cbar(string) r2long(string) ///
			ngrid(integer 200) *]

	tempname r2long_mat cbar_mat beta_mat
	
	// defaults
	if "`oster'" == "" & "`dmp'" == ""{
		local dmp dmp
	}
			
	if "`oster'" != ""{
		breakdown_oster , r2long(`r2long') beta(`beta') maxovb(`maxovb')
		local analysis "Oster 2019"
	}
	else if "`dmp'" != ""{
		breakdown_dmp , cbar(`cbar') beta(`beta') ngrid(`ngrid')
		local analysis "DMP (2022)"
	}
	
	matrix breakfront = r(breakfront)
	matrix breakfront_table = r(breakfront_table)
	
	// summary stats
	mata: save_dgp_stats(dgp)

	// extract variable lists
	local y: word 1 of `varlist'
	local x: word 2 of `varlist'
	local w: list varlist - y
	local w: list w - x
	
	if "`compare'" != "" {
		local w1 `compare'
		local w0 : list w - w1
	}
	else if "`nocompare'" != "" {
		local w0 `nocompare'
		local w1 : list w - w0
	}
	else {
		local w1 `w'
	}
	
	// macros
	ereturn post, depname(`y') properties()
	
	ereturn local hyposign "`r(hyposign)'"
	ereturn local sparam1_option `r(sparam1_option)'
	ereturn local sparam1 `r(sparam1)'
	ereturn local param "Beta"
	ereturn local analysis `r(analysis)'
	ereturn local compare `w1'
	ereturn local controls `w'
	ereturn local indvar : word 2 of `varlist'
	ereturn local depvar `y'
	ereturn local cmdline `"regsensitivity breakdown `0'"'
	ereturn local subcmd breakdown
	ereturn local cmd regsensitivity

	// scalars
	ereturn scalar N = nobs
	ereturn scalar hypoval = r(hypoval)
	
	// matrices
	ereturn matrix breakfront_table = breakfront_table
	ereturn matrix breakfront = breakfront
	ereturn matrix sumstats = stats

	// internal
	ereturn hidden local other_sparams = "`r(other_sparams)'"
	
end

// PROGRAM: Breakdown Frontier, DMP (2022)
// DESCRIPTION: Calculate the breakdown frontier for the analysis in Diegert, Masten,
//              Poirier (2022).
// NOTES:
//   - Allows eq, lb, ub option for beta.
//   - Allows only bound option for cbar(long)
// INPUT: 
//   - beta: (numlist [eq ub lb sign]) Hypothesis to compute the breakdown 
//           frontier for. See `parse beta`
//   - cbar: (param_spec) Range and option cbar. see `parse_sensparam`
//   - ngrid: (integer) Number of points in the grid of sensitivity parameter
//        values when grid is not explicitly given  
// RETURNS:
//   - breakdown: (matrix) table mapping values of cbar or beta to the
//                      breakdown point.
//   - breakdown_table: (matrix) truncated table to be displayed.
//   - additional metadata: sparam2, sparam2_option, analysis

program define breakdown_dmp, rclass

	syntax , [cbar(string) beta(string) ngrid(integer 200)]

	tempname cbar_mat beta_mat varying_param
	
	// allow results from this command to be added to idset results
	return add
	
	// defaults
	if "`beta'" == ""{
		local beta sign
	}
	if "`cbar'" == ""{
		local cbar 1
	}
	
	_format_option_input `beta'
	parse_beta `s(formatted_option_input)'
	local hyposign "`s(hyposign)'"
	local hypoval `s(hypoval)'
	
	_numlist_to_matrix `cbar', name(`cbar_mat')
	_numlist_to_matrix `s(beta)', name(`beta_mat') //lb(-100) ub(100)  
	// TODO: fix these arbitrary bounds

	
	if "`hyposign'" == "="{
		di as error "Breakdown hypotheses of the form Beta != b " /*
		*/ "are not implemented for DMP 2022"
		exit 179
	}
	else {
		// This calcualtes the breakdown frontier and saves it to a matrix
		// called `breakfront`
		mata: breakdown_frontier(st_matrix("`beta_mat'"), ///
		                         st_matrix("`cbar_mat'"), "`hyposign'", dgp)
		
		local nbeta : rowsof `beta_mat'
		local ncbar : rowsof `cbar_mat'
		local nbfpoints = max(`ncbar', `nbeta')
		
		
		if (`nbeta' > 1) & (`ncbar' > 1){
			di as error "syntax error: multiple values allowed " /*
				 */ "for either beta or cbar, not both"
			exit 198
		}
		else if (`nbeta' > 1){
			local breakfront_table_names `""Beta(Hypothesis)" "rxbar(Breakdown)""'
			local other_sparams "cbar = `=`cbar_mat'[1,1]', rybar = +inf"
			local varying_param `beta_mat'
		}
		else {
			local breakfront_table_names `""cbar" "rxbar(Breakdown)""'
			local other_sparams "rybar = +inf"
			local varying_param `cbar_mat'
		}
		if (`nbeta' == 1) & (`ncbar' == 1){
			matrix breakfront_table = breakfront
		}
		else if `nbfpoints' < `ngrid'{
			// if the grid of breakfront points isn't fine enough,
			// recalcaulte for a larger grid and save the
			// selected points to display in the table
			matrix breakfront_table = breakfront
			mata: st_matrix("`varying_param'", /// 
			      rangen(min(st_matrix("`varying_param'")), ///
			      max(st_matrix("`varying_param'")), `ngrid'))
	
			// This creates the abbreviated table and saves it to 
			// breakfront_table
			mata: breakdown_frontier(st_matrix("`beta_mat'"), ///
						 st_matrix("`cbar_mat'"), ///
						 "`hyposign'", dgp)
		}
		else {				
			// if the grid of breakfront points is fine enough,
			// choose a selection of points to display in the table 
			mata: breakfront_table("breakfront", ///
						st_matrix("`varying_param'"))
		} 
		
		matrix colnames breakfront = `breakfront_table_names'
		matrix colnames breakfront_table = `breakfront_table_names'

	}

	return matrix breakfront = breakfront
	return matrix breakfront_table = breakfront_table
	return local hyposign `"`hyposign'"'
	if "`hypoval'" != "Beta(Hypothesis)" return scalar hypoval = `hypoval'
	else return scalar hypoval = .
	return local other_sparams "`other_sparams'" // TODO: handling of this
	return local sparam2 cbar
	return local analysis DMP (2022)

end

// PROGRAM: Breakdown Frontier, Oster (2019)
// DESCRIPTION: Calculate the breakdown frontier for the analysis in Oster (2019).
// NOTES:
//   - Allows eq, lb, ub option for beta.
//   - Allows only eq option for R-squared(long)
// INPUT: 
//   - beta: (numlist [eq ub lb sign]) Hypothesis to compute the breakdown 
//           frontier for. See `parse beta`
//   - r2long: (param_spec) Range and option R-squared(long). see `parse_sensparam`
//   - ngrid: (integer) Number of points in the grid of sensitivity parameter
//        values when grid is not explicitly given  
// RETURNS:
//   - breakdown: (matrix) table mapping values of cbar or beta to the
//                      breakdown point.
//   - breakdown_table: (matrix) truncated table to be displayed.
//   - additional metadata: sparam2, sparam2_option, analysis

program define breakdown_oster, rclass

	syntax , [r2long(string) beta(string) maxovb(string) ngrid(integer 200)]
	
	tempname r2long_mat beta_mat maxovb_mat
	
	// allow results from this command to be added to idset results
	return add
	
	local other_sparam_fmt "%5.3g"
	
	if "`beta'" == ""{
		local beta 0 eq
	}
	if "`maxovb'" == ""{
		local maxovb -1
	}
	if "`r2long'" == ""{
		local r2long 1
	}
	
	// process beta
	_format_option_input `beta'
	parse_beta `s(formatted_option_input)'
	local hyposign "`s(hyposign)'"
	local hypoval `s(hypoval)'
	
	_numlist_to_matrix `s(beta)', name(`beta_mat')
	
	// process rsquared(long)
	if "`r2long'" == "" {
		local r2long 1 eq
	}
	
	_format_option_input `r2long' matrix_name("`r2long_mat'")
	parse_r2long `s(formatted_option_input)'
	local r2long `s(param)'
	local sparam2_option `s(paramtype)'
	local nsparam2 : rowsof `r2long_mat'
	
	_format_option_input `maxovb' matrix_name("`maxovb_mat'")
	parse_maxovb `s(formatted_option_input)' 
	local maxovb `s(maxovb)'
	local nmaxovb : rowsof `maxovb_mat'
	
	
	// calculate breakdown frontier with hypothesis beta = `hypoval'
	if "`hyposign'" == "="{
		mata: oster_breakdown_eq(st_matrix("`r2long_mat'"), st_matrix("`beta_mat'"), st_matrix("`maxovb_mat'"), dgp)

		local nbeta : rowsof `beta_mat'
		local nr2long : rowsof `r2long_mat'
		local nbfpoints = max(`nr2long', `nbeta')
		
		if (`nbeta' > 1) & (`nr2long' > 1){
			di as error "syntax error: multiple values allowed " /*
			*/          "for either beta or r2long, not both"
			exit 198
		}
		else if (`nmaxovb' > 1){
			local r2long_scalar =`r2long_mat'[1,1]
			local r2long_fmt = strofreal(`r2long_scalar', "`other_sparam_fmt'")
			local breakfront_table_names `""OVB(Max)" "Delta(Breakdown)""'
			local other_sensparams "R-squared(long) = `r2long_fmt'"
			local varying_param `maxovb_mat'
			di "`other_sensparams'"
		}
		else if (`nr2long' > 1){
			local breakfront_table_names `""R-squared(long)" "Delta(Breakdown)""'
			if "`maxovb'" != "-1"{
				local maxovb_fmt = strofreal(`maxovb', "`other_sparam_fmt'")
				local other_sensparams "Max OVB = `maxovb_fmt'"
			}
			local varying_param `r2long_mat'
		}
		else {
			local r2long_scalar =`r2long_mat'[1,1]
			local r2long_fmt = strofreal(`r2long_scalar', "`other_sparam_fmt'")
			local breakfront_table_names `""Beta(Hypothesis)" "Delta(Breakdown)""'
			local other_sensparams "R-squared(long) = `r2long_fmt'"
			if "`maxovb'" != "-1"{
				local maxovb_fmt = strofreal(`maxovb', "`other_sparam_fmt'")
				local other_sensparams "`other_sensparams', max OVB = `maxovb_fmt'"
			}
			local varying_param `beta_mat'			
		}
		if (`nbeta' == 1) & (`nr2long' == 1){
			matrix breakfront_table = breakfront

		}
		else if `nbfpoints' < `ngrid'{
			// if the grid of breakfront points isn't fine enough,
			// recalcaulte for a larger grid and save the
			// selected points to display in the table
			matrix breakfront_table = breakfront
			mata: st_matrix("`varying_param'", ///
					rangen(min(st_matrix("`varying_param'")), ///
					max(st_matrix("`varying_param'")), `ngrid'))
	
			// This creates the abbreviated table and saves it to breakfront_table
			mata: oster_breakdown_eq(st_matrix("`r2long_mat'"), ///
			                         st_matrix("`beta_mat'"), st_matrix("`maxovb_mat'"), dgp)
			
		}
		else {				
			// if the grid of breakfront points is fine enough, choose a
			// selection of points to display in the table 
			mata: breakfront_table("breakfront", st_matrix("`varying_param'"))
		}
		
		matrix colnames breakfront = `breakfront_table_names'
		matrix colnames breakfront_table = `breakfront_table_names'
	}
	
	// calculate breakdown frontier with hypothesis beta >< `hypoval'
	else {
		// This calcualtes the breakdown frontier and saves it to a matrix
		// called `breakfront`
		mata: oster_breakdown_bound(st_matrix("`r2long_mat'"), ///
		      st_matrix("`beta_mat'"), st_matrix("`maxovb_mat'"), ///
		      "`hyposign'", dgp)
		
		local nbeta : rowsof `beta_mat'
		local nr2long : rowsof `r2long_mat'
		local nbfpoints = max(`nr2long', `nbeta', `nmaxovb')
		
		if (`nbeta' > 1) & (`nr2long' > 1){
			di as error "syntax error: multiple values allowed " /*
			*/          "for either beta or r2long, not both"
			exit 198
		}
		else if (`nmaxovb' > 1){
			local r2long_scalar =`r2long_mat'[1,1]
			local r2long_fmt = strofreal(`r2long_scalar', "`other_sparam_fmt'")
			local breakfront_table_names `""OVB(Max)" "Delta(Breakdown)""'
			local other_sensparams "R-squared(long) = `r2long_fmt'"
			local varying_param `maxovb_mat'
		}
		else if (`nr2long' > 1){
			local breakfront_table_names `""R-squared(long)" "Delta(Breakdown)""'
			if "`maxovb'" != "-1"{
				local maxovb_fmt = strofreal(`maxovb', "`other_sparam_fmt'")
				local other_sensparams "Max OVB = `maxovb_fmt'"
			}
			local varying_param `r2long_mat'
		}
		else {
			local r2long_scalar =`r2long_mat'[1,1]
			local r2long_fmt = strofreal(`r2long_scalar', "`other_sparam_fmt'")
			local breakfront_table_names `""Beta(Hypothesis)" "Delta(Breakdown)""'
			local other_sensparams "R-squared(long) = `r2long_fmt'"
			if "`maxovb'" != "-1"{
				local maxovb_fmt = strofreal(`maxovb', "`other_sparam_fmt'")
				local other_sensparams "`other_sensparams', max OVB = `maxovb_fmt'"
			}
			local varying_param `beta_mat'			
		}
		
		if (`nbeta' == 1) & (`nr2long' == 1) & (`nmaxovb' <= 1) {
			matrix breakfront_table = breakfront
		}
		else if `nbfpoints' < `ngrid'{
			// if the grid of breakfront points isn't fine enough,
			// recalcaulte for a larger grid and save the
			// selected points to display in the table
			matrix breakfront_table = breakfront
			mata: st_matrix("`varying_param'", ///
					rangen(min(st_matrix("`varying_param'")), ///
					max(st_matrix("`varying_param'")), `ngrid'))
	
			// This creates the abbreviated table and saves it to breakfront_table
			mata: oster_breakdown_bound(st_matrix("`r2long_mat'"), ///
			      st_matrix("`beta_mat'"), st_matrix("`maxovb_mat'"), "`hyposign'", dgp)
			 
			
		}
		else {				
			// if the grid of breakfront points is fine enough, choose a
			// selection of points to display in the table 
			mata: breakfront_table("breakfront", st_matrix("`varying_param'"))
		} 
		
		matrix colnames breakfront = `breakfront_table_names'
		matrix colnames breakfront_table = `breakfront_table_names'
	}
	

	return matrix breakfront = breakfront
	return matrix breakfront_table = breakfront_table
	return local hyposign `"`hyposign'"'
	if "`hypoval'" != "Beta(Hypothesis)"{
		return scalar hypoval = `hypoval' 
	}
	else{
		return scalar hypoval = .
	}
	if "`maxovb'" != "-1" & `nmaxovb' <= 1{
		return scalar maxovb = `maxovb'
	}
	else{
		return scalar maxovb = .b
	}
	return local other_sparams "`other_sensparams'" // TODO: handling of this
	return local sparam2 R-squared(long)
	return local analysis Oster (2019)

end

********************************************************************************
**** Option Parsing
********************************************************************************

// PROGRAM: Parse R-squared(long)
program parse_r2long, sclass

	syntax anything, matrix_name(string) [Equal Bound RELative]
	
	if "`bound'" != ""{
		di as error "R-squared(long) not implemented for bound"
		exit 198
	}
	
	_parse_formatted_sensparam `anything', default(equal) `equal' `relative'
	local r2long `s(param)'
	mata: st_local("r_med", strofreal(dgp.r_med))
	local sparam_option `s(paramtype)'
	if `s(relative)' {
		local multiplier `r_med'
	}
	else {
		local multiplier 1
	}
	_numlist_to_matrix `r2long', ///
		name(`matrix_name') ///
		lb(`r_med') ub(1) multiplier(`multiplier')
		
	local nr2long : rowsof(`matrix_name')
	if `nr2long' == 1{
		local r2long = `matrix_name'[1,1]
	}
		
	sreturn local param `r2long'
	sreturn local paramtype `sparam_option'
end

program parse_maxovb, sclass

	syntax anything, matrix_name(string) [Equal Bound RELative]

	if "`equal'" != ""{
		di as error "Max OVB not implemented for equal"
		exit 198
	}

	_parse_formatted_sensparam `anything', default(bound) `bound' `relative'
	
	local maxovb `s(param)'
	mata: st_local("beta_med", strofreal(abs(dgp.beta_med)))
	if `s(relative)' {
		local multiplier `beta_med'
	}
	else {
		local multiplier 1
	}
	_numlist_to_matrix `maxovb', name(`matrix_name') lb(-1) multiplier(`multiplier')
	
	local nmaxovb : rowsof(`matrix_name')
	if `nmaxovb' == 1{
		local maxovb = `matrix_name'[1,1]
	}
	
	sreturn local maxovb `maxovb'

end
	
program parse_sensparam, sclass

	_parse_formatted_sensparam `0'
	sreturn local param `s(param)'
	sreturn local paramtype `s(paramtype)'
	sreturn local relative `s(relative)'
	
end

program _parse_formatted_sensparam, sclass
	
	syntax [anything], [default(string) RELative Equal Bound]
	
	sreturn local param `anything'
	if "`equal'" == "" && "`bound'" == ""{
		sreturn local paramtype `default'
	}
	else if "`equal'" != "" && "`bound'" != ""{
		di as error "both equal and bound option specified"
		exit 198
		
	}
	else if "`equal'" != ""{
		sreturn local paramtype "eq"
	}
	else if "`bound'" != ""{
		sreturn local paramtype "bound"
	}
	sreturn local relative = "`relative'" != "" 

end

// PROGRAM: Format option input
// DESCRIPTION: The allows options to be pased without a comma
program _format_option_input, sclass

	syntax [anything], [*]
	
	local ntokens : word count `anything'
	tokenize `anything'
	forvalues i=1/`ntokens'{
		local isword = regexm("``i''", "^[a-zA-Z].*$")
		if `isword'{
			local options "`options' ``i''"
		}
		else{
			local args "`args' ``i''"
		}
	}
	local args = strtrim("`args'")
	
	if "`args'" == "" & "`options'" == ""{
		sreturn local formatted_option_input 
	}
	else if "`options'" != "" {
		sreturn local formatted_option_input "`args', `options'"
	}
	else {
		sreturn local formatted_option_input "`args'"
	}
	sreturn local options `options'
	sreturn local args `args'

	// separate all the options into before and after comma

end

// PROGRAM: Parse Beta
// DESCRIPTION: Parses the syntax for the `beta` option to `regsensitivity`
// NOTES:
//   - default for beta is sign if no 
// INPUT:
//   - beta: (numlist [eq ub lb sign]) specification for the hypothesis/es.
//           numlist are the value(s) of the hypothesis/es. The option
//           specifies the sign of the hypothesis test. They are as follows
//       - eq: "equal," Beta(param) != beta(value)
//       - lb: "lower bound," Beta(param) > beta(value)
//       - ub: "upper bound," Beta(param) < beta(value)
//       - sign: "sign change," sign(Beta(param)) = sign(Beta_med) 
program define parse_beta, sclass

	syntax [anything], [EQual lb ub sign]
	
	local beta `anything'
	// default = sign
	if "`beta'" == "" local beta 0
	
	if "`equal'" == "" & "`lb'" == "" & "`ub'" == ""{
		local sign "sign"
	}
	
	numlist "`beta'"
	local beta `r(numlist)'
	loca nbeta : word count `beta' 
	
	if "`sign'" == "sign" & `nbeta' > 1{
		di as error "sign option can only be used with a single value input for beta"
		exit 198
	}
	
	// TODO: update this so you can have a "sign" hypothesis with val other than 0
	else if "`sign'" == "sign" {
		// find the direction for the hypothesis when sign option is chosen
		mata: st_local("beta_sign", strofreal(dgp.beta_med >= `beta'))
		if `beta_sign' {
			local lb lb
		}
		else {
			local ub ub
		}
	} 

	if `nbeta' > 1 local val "Beta(Hypothesis)"
	else local val `beta'
	
	if "`equal'" == "equal" local hyposign "="
	else if "`lb'" == "lb" local hyposign ">"
	else if "`ub'" == "ub" local hyposign "<"
	
	sreturn local beta `beta'
	sreturn local hypotype `hypotype'
	sreturn local hyposign = "`hyposign'"
	sreturn local hypoval `val'
	
end


// PROGRAM: numlist to matrix
// DESCRIPTION: convert a numlist to a matrix with a single column with the 
//              expanded values of the numlist
// NOTES:
//    - If only two values are passed in the numlist, they are interpreted as
//      bounds of a range and will be filled in with ngrid points. Otherwise,
//      the numlis will be expanded normally.
// INPUT:
//    - anything: (numlist)
//    - name: (string) name of the matrix to return
//    - lb: (real scalar) lower bound. If specified this will
//          drop any values in the numlist below this
//    - ub: (real scalar) upper bound. (same as lb)
//    - ngrid: (integer) number of grid points to use when given range endpoints 
// RETURN:
//    - <"name">: (matrix) The matrix is saved to stata memory.
program define _numlist_to_matrix

	syntax anything, name(string) [lb(string) ub(string) /// 
	                               ngrid(integer 200) multiplier(real 1)]

	// 
	if "`lb'" == "" local lb -1e+100
	if "`ub'" == "" local ub 1e+100
	
	// This was previously treating an input of two values specially
	// expanding it into a grid. I think this was making the input
	// a little less predictable and wasn't that useful because you can
	// always just enter the range you want exactly.
// 	local nvals : word count `anything'
// 	if `nvals' == 2 {
// 		local up : word 2 of `anything'
// 		local lw : word 1 of `anything'
// 		local step = (`up' - `lw') / `ngrid'
// 		local anything "`lw'(`step')`up'"
// 	}
	numlist "`anything'"
	local anything `r(numlist)'
	
	local included_min 0
	local included_max 0
	foreach el of local anything {
		local el = `el' * `multiplier'
		if (`el' < `lb') & (!`included_min'){
			matrix `name' = nullmat(`name') \ `lb'
			local included_min 1
		}
		else if (`el' >= `lb') & (`el' <= `ub'){
			matrix `name' = nullmat(`name')  \ `el'
		}
		else if (`el' > `ub') & (!`included_max'){
			matrix `name' = nullmat(`name') \ `ub'
			local included_max 1
		}
	}
	
	// mata: st_matrix("`name'", clip(st_matrix("`name'"), `lb', `ub'))
	
end


********************************************************************************
******* Mata implementation
********************************************************************************

mata:

// =============================================================================
// DGP 
// =============================================================================

struct dgp{
	real scalar var_y, var_x, var_w, wt, k0, k1, k2, covwx_norm_sq
	real scalar beta_short, beta_med, gamma_med, pi_med, r_short, r_med, var_x_resid
}

// FUNCTION: Get DGP
// DESCRIPTION: Calculate the Var(Y, X, W1) and various functions of this matrix
//              which are used in calculations for the sensitivity analyses.
// INPUT:
//   - yname: (string) name of the dependent variable
//   - xname: (string) name of the independent variable
//   - wname: (string) name of additional controls
// RETURN: (struct dgp) `struct_dgp`
struct dgp scalar get_dgp(
	string scalar yname,
	string scalar xname,
	string scalar wname
){
	
	real matrix y, x, w, vw, v
	real scalar covwx, covwy, covxy
	struct dgp scalar s

	// unpack variables
	y = st_data(., yname)
	x = st_data(., xname)
	w = st_data(., wname)
	
	// Remove constants
	// (The variance matrix of W1 needs to have full rank, which will fail if we
	//  try to calculate the variance matrix with a constant. A constant should
	//  always be included in W0)
	vw = variance(w)
	for (i=rows(vw)-1; i >= 2; i = i - 1){
		if (vw[i,i] == 0) {
			imin = max((1, i-1))
			imax = min((cols(w), i+1))
			w = (w[.,1..imin],w[.,imax..cols(w)])
		}
	}
	if (vw[cols(vw), cols(vw)] == 0) {
		w = w[.,1..(cols(vw) - 1)]
	}
	if (vw[1,1] == 0) {
		w = w[.,2..cols(w)]
	}
	
	// combine the data together
	data = (y, x, w)
	
	// calcaulte the variance
	v = variance(data)
	
	// save sufficient parameters
	s.var_y = v[1, 1]
	s.var_x = v[2, 2] 
	s.var_w = v[3..rows(v), 3..cols(v)]
	
	// weighting matrix
	s.wt = cholinv(s.var_w)
	
	covwx = v[3..rows(v), 2]
	covwy = v[3..rows(v), 1]
	covxy = v[1, 2]
	
	// see DMP (2022) for notation (these are variances/covariances of 
	// MX, MY)
	s.k0 = s.var_x - covwx' * s.wt * covwx
	s.k1 = covxy - covwx' * s.wt * covwy
	s.k2 = s.var_y - covwy' * s.wt * covwy
	
	s.covwx_norm_sq = s.var_x - s.k0 
	
	// stats for oster stuff
	s.var_x_resid = s.k0  
	
	// beta of Y on X and Y on (X, W1)
	s.beta_short = covxy / s.var_x
	s.beta_med = s.k1 / s.k0
	
	// unweighted gamma_med and pi_med
	s.gamma_med = covwy - s.beta_med * covwx
	s.pi_med = covwx
	
	// R-squared for different regressions
	s.r_short = s.beta_short^2 * s.var_x / s.var_y
	s.r_med = (
		s.beta_med^2 * s.var_x 
		+ s.gamma_med' * s.wt * s.gamma_med
		+ 2 * s.beta_med * s.gamma_med' * s.wt * covwx
	) / s.var_y
	
	return(s)
	
}

// FUNCTION: Save DGP Summary Statistics
// DESCRIPTION: Save the DGP summary statistics to a stata matrix
// INPUT:
//   - dgp (struct dgp)
// STATA RETURN:
//   - stats: (matrix) Summary statistics (Beta, R-squared, Variances)
void save_dgp_stats(struct dgp scalar s){
	stats = (s.beta_short \ s.beta_med \ s.r_short \ s.r_med 
		 \ s.var_y \ s.var_x \ s.var_x_resid)
	names = ("Beta (short)" \ "Beta (medium)" \ "R2 (short)" 
		  \ "R2 (medium)" \ "Var(Y)" \ "Var(X)" \ "Var(X_Residual)")
	names = (J(7, 1, ""), names)
	st_matrix("stats", stats)
	st_matrixrowstripe("stats", names)
}
	
// =============================================================================
// Diegert, Masten, and Poirier (2022) 
// =============================================================================

// FUNCTION: zmax
// DESCRIPTION: zbar(c, rx) function as defined in DMP (2022)
// INPUT:
//   - c: (real scalar)
//   - rx: (real scalar) 
//   - s: (struct dgp)
// RETURN:
//   - z: (real scalar) 
numeric scalar zmax(
	numeric scalar c, 	
	numeric scalar rx, 
	struct dgp scalar s
){
	cmax = min((c,rx))
	
	z = sqrt(s.covwx_norm_sq) * rx * sqrt(1 - cmax^2)
	z = z / (1 - rx * cmax)
	
	return(z)
}

// FUNCTION: Beta deviation
// DESCRIPTION: dev(zbar) function as defined in DMP (2022)
// INPUT:
//   - z: (real scalar) 
//   - s: (struct dgp)
// RETURN:
//   - z: (real scalar) 
numeric scalar beta_deviation(
	numeric scalar z, 
	struct dgp scalar s
){
	z_sq = z^2
	z_sq = min((z_sq, s.k0 - .000001))
	deviation_sq = (z_sq * (s.k2/s.k0 - (s.k1/s.k0)^2)) / (s.k0 - z_sq)
	deviation = sqrt(deviation_sq)
	return(deviation)
}

// FUNCTION: Maximum Beta Bound
// DESCRIPTION: Find the value of rxbar at which the identified set becomes
//              (-inf, +inf)
// INPUT:
//   - c: (real scalar) 
//   - s: (struct dgp)
// RETURN:
//   - rxbar: (real scalar) 
numeric scalar max_beta_bound(
	real scalar c,
	struct dgp scalar s
){
	
	real scalar A, B, C, root1, root2
	
	if(c == 1){
		return(sqrt(s.k0 / s.var_x))
	}
	
	A = c^2 * (s.k0 + s.covwx_norm_sq) - s.covwx_norm_sq
	B = s.k0 * c
	C = s.k0
	
	root1 = (B + sqrt(B^2 - A * C)) / A
	root2 = (B - sqrt(B^2 - A * C)) / A
	
	if(0 <= root1 & root1 <= root2){
		return(root1)
	} else {
		return(root2)
	}
	
}

// FUNCTION: Beta Bounds
// DESCRIPTION: Find the upper and lower bounds of the identified set for beta
//              for each value of rxbar in the input for the fixed value of
//              cbar given in the input.
// INPUT:
//   - c: (real scalar)
//   - rx: (real colvector) 
//   - s: (struct dgp)
// RETURN:
//   - beta: (real matrix[n x 3]) identified set.
//               - column 1: value of rxbar
//               - column 2: lower bound of beta
//               - column 3: upper bound of beta 
numeric matrix beta_bounds(
	numeric scalar c,
	numeric colvector rx,
	struct dgp scalar s
){
	
	finite_threshold = max_beta_bound(c, s)
	
	bounds = J(rows(rx), 2, .)
	for (i = 1; i <= rows(rx); i++){
		finite = rx[i] < finite_threshold
		if (finite) {
			z = zmax(c, rx[i], s)
			dev = beta_deviation(z, s)
			bounds[i,1..2] = (s.beta_med - dev, s.beta_med + dev)
		} else {
			bounds[i,1..2] = (.a, .b)
		}
	}
	return(bounds)
}

// FUNCTION: Maximum Breakdown Point
// DESCRIPTION: Find the breakdown point with cbar = 1 for the hypothesis that
//              Beta(param) ≷ beta(input). 
// NOTES:
//   - This is the breakdown point where cbar = rxbar(breakdown max).
//   - The direction of the inequality is implicit: It returns the first point
//     at which beta(input) is included in the identified set for Beta(param)
// INPUT:
//   - beta: (real scalar) 
//   - s: (struct dgp)
// RETURN:
//   - rxbar(breakdown max): (real scalar) 
numeric scalar breakdown_point_max(
	real scalar beta,
	struct dgp scalar s
){
	dev_sq = (beta - s.beta_med)^2
	bp_sq = dev_sq * s.k0
	bp_sq = bp_sq / (bp_sq + s.covwx_norm_sq * (s.k2 / s.k0 - 2 * beta * s.beta_med + beta^2))
	return(sqrt(bp_sq))
}

// FUNCTION: Breakdown Point
// DESCRIPTION: Find the breakdown point with cbar as input for the hypothesis 
//              that Beta(param) ≷ beta(input). 
// NOTES:
//   - if cbar >= rxbar(breakdown max), then rxbar(breakdown)[c] = rxbar(breakdown)[max]
//   - otherwise rxbar(breakown)[cbar] > rxbar(breakdown)[max], and 
//     cbar < rxbar(breakdown)[cbar]
//   - Checks first that the hypothesis is false at rxbar = 0, otherwise,
//     returns the first value of rxbar at which beta(input) is included in the 
//     identified set for Beta(param)
// INPUT:
//   - beta: (real scalar)
//   - c: (real scalar)
//   - bfmax: (real scalar)
//   - lower_bound: (real scalar{0,1}) Is this a lower bound for Beta? 
//   - s: (struct dgp)
// RETURN:
//   - beta: (real matrix[n x 3]) identified set.
//               - column 1: value of rxbar
//               - column 2: lower bound of beta
//               - column 3: upper bound of beta 
numeric scalar breakdown_point(
	real scalar beta,
	real scalar c,
	real scalar bfmax,
	real scalar lower_bound,
	struct dgp scalar s
){
	
	real scalar A, B, C, root1, root2
	
	// check if the hypothesis is false at rx = 0
	if (lower_bound && (beta >= s.beta_med)) {
		return(0)
	}
	if(lower_bound == 0 && beta <= s.beta_med){
		return(0)
	}
	// check for the case where cbar = rxbar
	if(c >= bfmax){
		return(bfmax)
	}
	
	// otherwise calculate the value where cbar != rxbar
	K1 = s.k0 * (s.beta_med - beta)^2
	K2 = (s.k2 / s.k0) - (2 * s.beta_med * beta) + beta^2
	
	A = K1 * c^2 - (1 - c^2) * s.covwx_norm_sq * K2
	B = K1 * c
	C = K1
	
	root1 = (B + sqrt(B^2 - A * C)) / A
	root2 = (B - sqrt(B^2 - A * C)) / A
	
	if(root1 <= root2 & 0 <= root1){
		return(root1)
	} else {
		return(root2)
	}
	
}

// FUNCTION: Identified Set, DMP
// DESCRIPTION: Calculate the identified set for set of values for rxbar and
//              cbar as in DMP (2022).
// INPUT:
//   - c: (real colvector) cbar 
//   - rx: (real colvector) rxbar
//   - s: (struct dgp)
// STATA RETURN:
//   - idset#: (matrix) Identified sets for each rxbar holding cbar fixed at
//             value # in c as input.
//   - ntables: (local) Number of values of cbar for which there is a
//              corresponding idset# table
void identified_set(
	numeric colvector c,
	numeric colvector rx,
	struct dgp scalar s
){
	for(i=1; i <= rows(c); i++){
		idset = beta_bounds(c[i], rx, s)
		idset = (rx, idset)
		st_matrix("idset" + strofreal(i), idset)
	}
	st_local("ntables", strofreal(rows(c)))
}

// FUNCTION: Breakdown Frontier, DMP
// DESCRIPTION: Calculate the rxbar breakdown point for each value of cbar.
//              for the hypothesis/es input.
// INPUT:
//   - beta: (real colvector) values for the hypothesis/es
//   - cs: (real colvector) cbar 
//   - sign: (string) sign of the hypothesis/es
//   - s: (struct dgp)
// STATA RETURN:
//   - breakfront: (matrix) rxbar(breakdown) for each value of cbar.
void breakdown_frontier(
	real colvector beta,
	real colvector cs,
	string sign,
	struct dgp scalar s
){

	if(rows(beta) > 1){
		cs = J(rows(beta), 1, cs[1])
		index = beta
	}
	else {
		beta = J(rows(cs), 1, beta[1])
		index = cs
	}
	
	lower_bound = sign == ">"
	rx = J(rows(beta), 1, .)
	for(i = 1; i <= rows(beta); i++){
		bfmax = breakdown_point_max(beta[i], s)
		rx[i] = breakdown_point(beta[i], cs[i], bfmax, lower_bound, s)
	}
	rx = (index, rx)
	st_matrix("breakfront", rx)

}
	
	
// =============================================================================
// Oster
// =============================================================================
// FUNCTION: Identified Set, Oster: Scalar inputs
// DESCRIPTION: Calculate the dentified set for Beta, assuming that 
//              (delta, r-squared(long)) are equal to the input values.
// INPUTS:
//    - delta (real scalar)
//    - r_max (real scalar)
//    - s (struct dgp)
// RETURN:
//    - beta: (real rowvector) Identified set for beta 

real rowvector oster_idset_scalar(
	real scalar delta,
	real scalar r_max,
	struct dgp scalar s
) {
// 	if(abs(r_max == s.r_med) < 1e-8){
// 		return(s.beta_med)
// 	}
	
	// coefficients of the cubic equation on page 193
	c0 = (
		(r_max - s.r_med) * s.var_y * delta * 
		(s.beta_short - s.beta_med) * s.var_x
	)
	c1 = (
		delta * (r_max - s.r_med) * s.var_y * (s.var_x - s.var_x_resid) 
		- (s.r_med - s.r_short) * s.var_y * s.var_x_resid 
		- s.var_x * s.var_x_resid * (s.beta_short - s.beta_med)^2
	)
	c2 = s.var_x_resid * (s.beta_short - s.beta_med) * s.var_x * (delta-2)
	c3 = (delta - 1) * (s.var_x_resid * s.var_x - s.var_x_resid^2)
	
	// solve for the roots
	roots = polyroots((c0,c1,c2,c3))
	
	// find the real roots
	roots = realroots(roots)
	sols =  s.beta_med :- roots
	
	// remove the erroneous root if needed
	// NOTES:
	// - root should be removed if ||root_check|| == 0
	// - to check this numerically, need to determine tolerance
	// - can lose floating point precision in previous steps (defining
	//   coefficients and solving the equation) so need more lenient
	//   tolerance. Allowing extra rounding error up to 2 digits seems to work.
	keeping = J(1, cols(roots), 1)
	for(i = 1; i <= cols(roots); i++){
		// tolerance: add 2 digits onto the machine precision of the
		// less precise of the two
		tol = epsilon(max((roots[i] * s.pi_med, s.gamma_med))) * 1e+2
		root_check = s.gamma_med + roots[i] * s.pi_med
		if(norm(root_check) < tol){
			keeping[i] = 0
		}
	}
	sols = select(sols, keeping)
	if(cols(sols) == 0){
		sols = .
	}
	return(sols)
	
}

// FUNCTION: Beta -> Delta(Beta), Oster
// DESCRIPTION: Calculate the unique value of Delta such that Beta is in the
//              identified set when R-squared(long) is the input value.
// INPUTS:
//    - beta (real scalar)
//    - r_max (real scalar)
//    - s (struct dgp)
// RETURN:
//    - delta: (real scalar) Unique value for Delta 
real scalar oster_delta(
	real scalar beta,
	real scalar r_max,
	struct dgp scalar s
){
	real scalar num, denom, delta
	
	if(abs(r_max - s.r_med) < 1e-7) {
		return(.b)
	}
	
	num = (
		(s.beta_med - beta) * (s.r_med - s.r_short) * s.var_y * s.var_x_resid
		+ (s.beta_med - beta) * s.var_x * s.var_x_resid * 
		  (s.beta_short - s.beta_med)^2		
		+ 2 * (s.beta_med - beta)^2 * (s.var_x_resid * 
		  (s.beta_short - s.beta_med) * s.var_x)
		+ ((s.beta_med - beta)^3) * 
		  ((s.var_x_resid * s.var_x - s.var_x_resid^2))
	)
	denom = (
		(r_max - s.r_med) * s.var_y * (s.beta_short - s.beta_med) * s.var_x
		+ (s.beta_med - beta) * (r_max - s.r_med) * s.var_y * 
		  (s.var_x - s.var_x_resid)
		+ ((s.beta_med - beta)^2) * 
		  (s.var_x_resid * (s.beta_short - s.beta_med) * s.var_x)
		+ ((s.beta_med - beta)^3) * 
		  (s.var_x_resid * s.var_x - s.var_x_resid^2)		
	)
	
	delta = num/denom
	
	return(delta)
}

// FUNCTION: Breakdown Point (Delta bound), Oster: Scalar input 
// DESCRIPTION: Find the breakdown point with R-squared(long) as input for 
//              the hypothesis that Beta(param) ≷ beta(input). 
// NOTES:
//    - When the hypothesis is Beta(param) > beta(input), The breakdown
//      point is the smallest value d such that for some b <= beta(input), 
//     |Delta(b)| < d. 
//    - We find this point by checking the critical points of the function
//      beta -> Delta(beta) on the range [-betabound, beta(input)] or 
//      [beta(input), betabound] to find the minimum. 
// INPUTS:
//    - beta (real scalar)
//    - r_max (real scalar)
//    - beta_bound (real scalar) Maximum absolute value of Beta(param).
//    - s (struct dgp)
// RETURN:
//    - delta: (real scalar) Unique value for Delta 
real colvector oster_breakdown_bound_scalar (
	real scalar beta,
	real scalar r_max,
	real scalar ovb_bound,
	real scalar lower_bound,
	struct dgp scalar s
){
	
	if(abs(r_max - s.r_med) < 1e-7) {
		return(.b)
	}
	
	// The following defines the coefficients for the rational function
	// beta_bias -> (delta(beta_bias))^2 where beta bias = beta_med - beta_long
	// and the function is as defined in Oster (2019)
	
	// First defined the Delta function
	
	// denominator
	dcoef = (
		(r_max - s.r_med) * s.var_y * (s.beta_short - s.beta_med) * s.var_x,
		(r_max - s.r_med) * s.var_y * (s.var_x - s.var_x_resid),
		(s.var_x_resid * (s.beta_short - s.beta_med) * s.var_x),
		(s.var_x_resid * s.var_x - s.var_x_resid^2)	
	)
	
	// numerator
	ncoef = (
		0,
		(
			(s.r_med - s.r_short) * s.var_y * s.var_x_resid) 
			+ (s.var_x * s.var_x_resid * (s.beta_short - s.beta_med)^2
		),		
		2 * (s.var_x_resid * (s.beta_short - s.beta_med) * s.var_x),
		(s.var_x_resid * s.var_x - s.var_x_resid^2)
	)
	
	// Square the numerator and denominator polynomials 
	dcoef = polymult(dcoef, dcoef)
	ncoef = polymult(ncoef, ncoef)
	
	// Derive the numerator of the derivative beta_bias -> (delta(beta_bias))^2
	derivn = polymult(polyderiv(ncoef, 1), dcoef)
	derivd = polymult(polyderiv(dcoef, 1), -ncoef)
	deriv = polyadd(derivn, derivd)
	
	// these are all the critical points of the function beta_bias -> (delta(beta))^2
	//  (following Oster's paper, really
	// this is more like the "negative" bias)
	critpoints = polyroots(deriv)
	critpoints = realroots(critpoints)
	
	// keep only the critical points where beta_long >< beta
	// note: the critical points are of the "beta_bias"
	if(lower_bound){
		critpoints = select(critpoints, critpoints :> s.beta_med - beta)	
	}
	else{
		critpoints = select(critpoints, critpoints :< s.beta_med - beta)
	}
	
	// add the bias term corresponding to beta_long = beta
	checkpoints = (critpoints, s.beta_med - beta)'
	
	// if there is a bound (M) on beta_long, then drop any critical points
	// outside this range, and add the value of the bias corresponding
	// to beta_long = -|M|
	// NOTE: (-1) is just a marker meaning no ovb bound
	if(ovb_bound > -1){
		checkpoints = select(checkpoints, ///
				     abs(checkpoints) :< ovb_bound)
	}
	if((ovb_bound > -1) && lower_bound && (s.beta_med - ovb_bound < beta)){
		checkpoints = (checkpoints\ovb_bound)
	}
	else if((ovb_bound > -1) && lower_bound && (s.beta_med - ovb_bound >= beta)){
		return(.b)
	}
	else if((ovb_bound > -1) && !lower_bound && (s.beta_med + ovb_bound > beta)){
		checkpoints = (checkpoints\-ovb_bound)
	}
	else if((ovb_bound > -1) && !lower_bound && (s.beta_med + ovb_bound <= beta)){
		return(.b)
	}

	// calculate the corresponding delta for each point to be checked
	
	deltas_abs = J(rows(checkpoints), 1, .)
	for(i = 1; i <= rows(checkpoints); i++){
		delta = oster_delta(s.beta_med - checkpoints[i], r_max, s)
		deltas_abs[i] = abs(delta)
	}
	
	delta_abs = min(deltas_abs)
	if(ovb_bound == -1){
		delta_abs = min((delta_abs, 1))
	}
	return(delta_abs)	

}

// FUNCTION: Identified Set (Equality), Oster
// DESCRIPTION: Calculate the identified set under the assumption that 
//              (Delta, R-squared(long)) are equal to each of the input values.
// INPUT:
//    - r_max: (real colvector)
//    - delta: (real colvector)
//    - s: (struct dgp)
// STATA RETURN:
//   - idset#: (matrix) Identified sets for each rxbar holding R-squared(long)
//             fixed at value # in r_max as input.
//   - ntables: (local) Number of values of cbar for which there is a
//              corresponding idset# table
void oster_idset_eq(			
	numeric colvector r_max,
	numeric colvector delta,
	numeric colvector maxovb,
	struct dgp scalar s
){
	// for now, only accept a scalar maxovb
	maxovb = maxovb[1]
	
	for(i=1; i <= rows(r_max); i++){
		idset = J(rows(delta), 3, .)
		for(j = 1; j <= rows(delta); j++){
			sols = oster_idset_scalar(delta[j], r_max[i], s)
			// remove any solutions outside the max OVB
			if(maxovb > -1){
				ovb = abs(s.beta_med :- sols)
				sols = select(sols, ovb :< maxovb)
			}
			if(cols(sols) > 0){
				sols = sort(sols', 1)'
			}
			if(cols(sols) == 1){
				idset[j, ] = (sols, ., .)
			}
			else if(cols(sols) == 2){
				idset[j, ] = (sols, .)
			}
			else if(cols(sols) == 3){
				idset[j, ] = sols
			}
		}
		idset = (delta, idset)
		st_matrix("idset" + strofreal(i), idset)
	}
	st_local("ntables", strofreal(rows(r_max)))
}	

// FUNCTION: Identified Set (Bound), Oster
// DESCRIPTION: Calculate the identified set under the assumption that the
//              absolute values of (Delta, R-squared(long)) are bounded by
//              each of the input values.
// INPUT:
//    - r_max: (real colvector)
//    - delta: (real colvector)
//    - s: (struct dgp)
// STATA RETURN:
//   - idset#: (matrix) Identified sets for each rxbar holding R-squared(long)
//             fixed at value # in r_max as input.
//   - ntables: (local) Number of values of cbar for which there is a
//              corresponding idset# table
void oster_idset_bound(			
	numeric colvector r_max,
	numeric colvector delta,
	numeric colvector maxovb,
	struct dgp scalar s
){
	// for now, only allow scalar input of maxovb
	maxovb = maxovb[1]
	
	for(i=1; i <= rows(r_max); i++){
		idset = J(rows(delta), 2, .)
		for(j = 1; j <= rows(delta); j++){
			if(delta[j] >= 1){
				idset[j, ] = (.a, .b)
			}
			else{
				sols1 = oster_idset_scalar(delta[j], r_max[i], s)
				sols2 = oster_idset_scalar(-delta[j], r_max[i], s)
				sols = (sols1, sols2)
				idset[j, ] = (min(sols), max(sols))
			}
			if(maxovb > -1 & abs(idset[j, 1] - s.beta_med) > maxovb){
				idset[j, 1] = s.beta_med - maxovb
			}
			if(maxovb > -1 & abs(idset[j, 2] - s.beta_med) > maxovb){
				idset[j, 2] = s.beta_med + maxovb
			}
		}
		idset[,1] = cummin(idset[,1])
		idset[,2] = cummax(idset[,2])
		idset = (delta, idset)
		st_matrix("idset" + strofreal(i), idset)
	}
	st_local("ntables", strofreal(rows(r_max)))
}

// FUNCTION: Breakdown Frontier (Equal), Oster
// DESCRIPTION: Calculate the delta breakdown point for each value of
//              R-squared(long) for the hypothesis/es input.
// INPUT:
//   - beta: (real colvector) values for the hypothesis/es
//   - r2max: (real colvector) R-squared(long)
//   - s: (struct dgp)
// STATA RETURN:
//   - breakfront: (matrix) delta(breakdown) for each value of R-squared(long).
void oster_breakdown_eq(			
	real colvector r2max,
	real colvector beta,
	real colvector maxovb,
	struct dgp scalar s		
){
	real colvector delta
	
	if(rows(maxovb) > 1){
		beta = J(rows(maxovb), 1, beta[1])
		r2max = J(rows(maxovb), 1, r2max[1])
		index = maxovb
	}
	else if(rows(r2max) > 1){
		beta = J(rows(r2max), 1, beta[1])
		maxovb = J(rows(r2max), 1, maxovb[1])
		index = r2max
	}
	else {
		r2max = J(rows(beta), 1, r2max[1])
		maxovb = J(rows(beta), 1, maxovb[1])
		index = beta
	}
	
	delta = J(rows(beta), 1, .)
	for(i = 1; i <= rows(beta); i++){
		if(maxovb[i] > -1 & abs(s.beta_med - beta[i]) > maxovb[i]){
			delta[i] = .b
		}
		else{
			delta[i] = oster_delta(beta[i], r2max[i], s)
		}
	}
	delta = (index, delta)
	st_matrix("breakfront", delta)
}

// FUNCTION: Breakdown Frontier (Bound), Oster
// DESCRIPTION: Calculate the delta breakdown point for each value of
//              R-squared(long) for the hypothesis/es input. Can take
//              Multiple values for one of (r2max, beta, ovb_bound)
// INPUT:
//   - r2max: (real colvector) R-squared(long)
//   - beta: (real colvector) values for the hypothesis/es
//   - maxovb (real colvector) values for magnitude contraint on ovb
//   - betabouund: (real scalar) Maximum value of Beta.
//   - s: (struct dgp)
// STATA RETURN:
//   - breakfront: (matrix) delta(breakdown) for each value of R-squared(long).
void oster_breakdown_bound(			
	real colvector r2max,
	real colvector beta,
	real colvector maxovb,
	string sign,
	struct dgp scalar s		
){
	real colvector delta
	
	
	if(rows(maxovb) > 1){
		beta = J(rows(maxovb), 1, beta[1])
		r2max = J(rows(maxovb), 1, r2max[1])
		index = maxovb
	}
	else if(rows(r2max) > 1){
		beta = J(rows(r2max), 1, beta[1])
		maxovb = J(rows(r2max), 1, maxovb[1])
		index = r2max
	}
	else {
		r2max = J(rows(beta), 1, r2max[1])
		maxovb = J(rows(beta), 1, maxovb[1])
		index = beta
	}
	
	lower_bound = sign == ">"
	delta = J(rows(beta), 1, .)
	for(i = 1; i <= rows(beta); i++){
		delta[i] = oster_breakdown_bound_scalar( ///
				beta[i], r2max[i], maxovb[i], lower_bound, s)
	}
	delta = (index, delta)
	st_matrix("breakfront", delta)
}

// FUNCTION: Beta -> Delta(Beta) Asymptotes, Oster
// DESCRIPTION: Calculate the asymptotes of the Beta -> Delta(Beta) function
//              with R-squared(long) fixed at the input value
// INPUT:
//   - r2max: (real scalar) R-squared(long)
//   - s: (struct dgp)
// STATA RETURN:
//   - roots: (real rowvector) The values of beta where the function has asymptotes
void oster_delta_asymptotes(
	real scalar r_max,
	struct dgp scalar s
){

	coef = (
		(r_max - s.r_med) * s.var_y * (s.beta_short - s.beta_med) * s.var_x,
		(r_max - s.r_med) * s.var_y * (s.var_x - s.var_x_resid),
		(s.var_x_resid * (s.beta_short - s.beta_med) * s.var_x),
		(s.var_x_resid * s.var_x - s.var_x_resid^2)	
	)
	roots = polyroots(coef)
	roots = realroots(roots)
	roots = -roots :+ s.beta_med
	roots = sort(roots', 1)'
	
	st_matrix("roots", roots)
}


// =============================================================================
// Helpers
// =============================================================================

// FUNCTION: Real Roots
// DESCRIPTION: Select only the real roots in the solutions to a polynomial
//              equation.
// INPUT:
//    - roots: (complex rowvector) solutions to a polynomial equation
// RETURN:
//    - rroots: (real rowvector) real solutions
real rowvector realroots(
	complex rowvector roots
){
	rroots = J(1,0,.)
	for(i = 1; i <= cols(roots); i++){
		conjugates = Re(roots[i]) :== Re(roots) 
		if(sum(conjugates) == 1){
			rroots = (rroots, Re(roots[i]))
		}
	}
	return(rroots)
}

// FUNCTION: Cumulative Minimum
// DESCRIPTION: take the cumulative minimum of a column vector interpreting .a
//              as -inf
// INPUT:
//    - x (real colvector)
// OUTPUT:
//    - y (real colvector)
real colvector cummin(
	real colvector x
){
	y = J(rows(x), 1, .a)
	for(i = 1; i <= rows(x); i++){
		if(x[i] < .){
			y[i] = min(x[1..i])
		}
	}
	return(y)
}

// FUNCTION: Cumulative Maximum
// DESCRIPTION: take the cumulative maximum of a column vector interpreting .b
//              as +inf
// INPUT:
//    - x (real colvector)
// OUTPUT:
//    - y (real colvector)
real colvector cummax(
	real colvector x
){
	y = J(rows(x), 1, .b)
	for(i = 1; i <= rows(x); i++){
		if(x[i] < .){
			y[i] = max(x[1..i])
		}
	}
	return(y)
}

// FUNCTION: Quantiles
// DESCRIPTION: Get the indices for a set of quantiles given the number of rows
// INPUT:
//    - n: (real scalar) number of rows
//    - p: (real colvector) percentiles of the vector
// RETURN:
//    - q: (real colvector) indices for the given quantiles

real colvector quantiles(
	real scalar n, 
	real colvector p
){
	q = J(rows(p), 1, .)
	for (j = 1; j <= rows(p); j++){
	    q[j] = min((floor(p[j] * n) + 1, n))
	}
	return(q)
}

// FUNCTION: Bounds Table
// DESCRIPTION: Format a matrix of idset results to be displayed, when 
//              identified set is displayed as an interval. Replace (.a, .b)
//              with (-inf, +inf), and select 10 evenly spaced points of 
//              sensitivity parameter to display
// INPUTS:
//    - idset_name: (string) Name of the stata matrix
//    - sensparam: (real colvector) sensitivity parameter values
//    - analysis: (string) Name of the analysis (DMP or Oster)
//    - s: (struct dgp)
//    - c: (real scalar, optional) cbar value used to calculate maximum value off
//         identified set
// STATA_RETURN
//    - idset_table: (matrix)
void bounds_table(
	string scalar idset_name,
	real colvector sensparam,
	string scalar analysis,
	struct dgp s,
	| real scalar c
){
	idset = st_matrix(idset_name)
	if(analysis == "dmp"){
		max_bound = max_beta_bound(c, s)
	} 
	else if(analysis == "oster"){
		max_bound = 1
	}
	attainsmax = idset[rows(idset),3] == .b
	idset = select(idset, idset[.,1] :< max_bound)
// 	idx = quantiles(rows(idset), range(0, 1, .1))
// 	idset = idset[idx,1..cols(idset)]
	if(attainsmax){
		idset = (idset \ (max_bound, .a, .b))
	}
	st_matrix("idset_table", idset)
}

// FUNCTION: Set Table
// DESCRIPTION: Format a matrix of idset results to be displayed, when 
//              identified set is displayed as an set of up to 3 points.
//              Select 10 evenly spaced points of sensitivity parameter to 
//              display
// INPUTS:
//    - idset_name: (string) Name of the stata matrix
// STATA_RETURN
//    - idset_table: (matrix)
void set_table(
	string scalar idset_name
){
	idset = st_matrix(idset_name)
	idx = quantiles(rows(idset), range(0, 1, .1))
	idset = idset[idx,1..cols(idset)]
	st_matrix("idset_table", idset)
}
		
// FUNCTION: Breakdown Frontier Table
// DESCRIPTION: Format a matrix of breakdown frontier results to be displayed.
//              Select 10 evenly spaced points of sensitivity parameter to 
//              display
// INPUTS:
//    - breakfront_name: (string) Name of the stata matrix
//    - sensparam: (real colvector) sensitivity parameter values
// STATA_RETURN
//    - idset_table: (matrix)
void breakfront_table(
	string scalar breakfront_name,
	real colvector sensparam
){
	breakfront = st_matrix(breakfront_name)
	idx = quantiles(rows(breakfront), range(0, 1, .1))
	breakfront = breakfront[idx,1..2]
	st_matrix("breakfront_table", breakfront)
}

end


