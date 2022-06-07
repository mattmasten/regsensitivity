*! version 1.0.0 Paul Diegert, Matt Masten, Alex Poirier 6jun2022

********************************************************************************
** PROGRAM: Regression Sensivitity
********************************************************************************
// Notes on Organization of Code
// - There are types of output, the identified set and the breakdown frontier,
//   which can be peformed for DMP (2022). There
//   are currently 2 Stata programs handle an ouput for a paper. These are:
//   	- `bounds_dmp`
//   	- `breakdown_dmp`
// - These are wrappers for Mata funcitons that calculate the output. The Stata
//   programs are primarily responsible for handling inputs. The top-level mata
//   functions are:
//      - identified_set (for DMP (2022))
//      - breakdown_frontier (for DMP (2022))
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
	bounds `varlist', compare(`compare') nocompare(`compare') 
	_regsen_display
	
end

********************************************************************************
****** Identified Set
********************************************************************************

// PROGRAM: Identified Set
// DESCRIPTION: Calculate the identified set. 
// INPUT: 
//   - varlist, w1, w0: See `load_dgp`
//   - cbar, rxbar, delta, rmax: (param_spec) Range and option for the
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
			Cbar(string) RXbar(string) ///
			beta(string) ngrid(integer 200) *]
	
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
	
	// parse beta
	parse_beta "`beta'"
	capture scalar `hypoval' = `s(hypoval)'
	if _rc == 198{
		di as error "Cannot specify multiple hypotheses when " /*
		*/ "with regsensitivity bounds, try using regsensitivity " /*
		*/ "breakdown"
	}
	local hyposign `s(hyposign)'

	return clear
	idset_dmp , rxbar(`rxbar') cbar(`cbar')	ngrid(`ngrid')
	if `r(nsparam2)' == 1 {
		breakdown_dmp , cbar(`cbar') beta(`beta')
		scalar breakdown = r(breakfront)[1,2]
		local cbar = r(sparam2_vals)[1,1]
		local other_sensparams "cbar = `cbar', rybar = +inf"	
	}

	// summary stats
	mata: save_dgp_stats(dgp)
	
	// macros
	ereturn post, depname(`y') properties()
	
	ereturn local hyposign `hyposign'
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
	parse_sensparam `cbar', default(bound)
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
		local rxbar 0 `rxmax'
	}
	
	parse_sensparam `rxbar', default(bound)
	local rxbar `s(param)'
	local sparam1_option `s(paramtype)'
	_numlist_to_matrix `rxbar', name(`rx_mat')
	
	if "`sparam1_option'" == "bound" {
	
		mata: identified_set(st_matrix("`c_mat'"), st_matrix("`rx_mat'"), dgp)
		
		local nrxpoints : rowsof `rx_mat'
		
		if `nrxpoints' < `ngrid'{
			// if the grid of rxbar points isn't fine enough,
			// recalcaulte for a larger grid and save the
			// selected points to display in the table
			matrix idset_table = idset1
			mata: st_matrix("`rx_mat'", ///
			                rangen(min(st_matrix("`rx_mat'")), ///
					max(st_matrix("`rx_mat'")), `ngrid'))
			mata: identified_set(st_matrix("`c_mat'"), ///
			                     st_matrix("`rx_mat'"), dgp)
		}
		else {				
			// if the grid of rxbar points is fine enough, choose a
			// selection of points to display in the table 
			// TODO: What do we want to do when you pass multiple vaules of c?
			local c = `c_mat'[1, 1]
			mata: bounds_table("idset`ntables'", ///
			                   st_matrix("`rx_mat'"), "dmp", dgp, `c')
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


********************************************************************************
***** Breakdown Frontier
********************************************************************************

// PROGRAM: Breakdown Frontier
// DESCRIPTION: Calculate the Breakdown Frontier. 
// INPUT: 
//   - varlist, w1, w0: See `load_dgp`
//   - cbar, rxbar, delta, rmax: (param_spec) Range and option for the
//        sensitivity parameters used in the analysis. see `parse_sensparam`
//   - beta: (hypothesis) Specifies the hypothesis for the breakdown point,
//        see `parse_beta`
//   - ngrid: (integer) Number of points in the grid of sensitivity parameter
//        values when grid is not explicitly given  
// RETURN:
//   - see help file

program define breakdown, eclass

	syntax varlist (fv ts) [if] [in], [compare(varlist fv ts) ///
			nocompare(varlist fv ts) ///
			beta(string) ///
			Cbar(string) ///
			ngrid(integer 200) *]

	tempname cbar_mat beta_mat
			
	breakdown_dmp , cbar(`cbar') beta(`beta') ngrid(`ngrid')
	local analysis "DMP (2022)"
	
	
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
*! version 1.0.0  6jun2022

//   - cbar: (param_spec) Range and option cbar. see `parse_sensparam`
//   - ngrid: (integer) Number of points in the grid of sensitivity parameter
//        values when grid is not explicitly given  
// RETURNS:
//   - breakdown: (matrix) table mapping values of cbar or beta to the
//                      breakdown point.
//   - breakdown_table: (matrix) truncated table to be displayed.
//   - additional metadata: sparam2, sparam2_option, analysis

program define breakdown_dmp, rclass

	version 15

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
	
	parse_beta "`beta'"
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

********************************************************************************
**** Helpers 
********************************************************************************

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

	args beta
	
	// default = sign
	if "`beta'" == "" local beta sign
		
	local ntokens : word count `beta' 
	tokenize `beta'
	local hypotype ``ntokens''
	local hypotypes eq lb ub sign
	
	local ishypotype : list hypotype in hypotypes
	
	// if numlist given but no option, default to lower bound
	// TODO: This seems arbitrary
	if !`ishypotype' {
		local hypotype lb
		local nbetatokens = `ntokens'
	}
	else {
		local nbetatokens = `ntokens' - 1
	}
	
	if "`hypotype'" == "sign" {
		// find the direction for the hypothesis when sign option is chosen
		mata: st_local("beta_sign", strofreal(dgp.beta_med >= 0))
		if `beta_sign' {
			local hypotype lb
		}
		else {
			local hypotype ub
		}
		local beta 0
	} 
	else if `ishypotype' {
		// otherwise unpack the hypothesis/es values
		local hypotype ``ntokens''
		local beta 
		forvalues i=1/`nbetatokens' {
			local beta `beta' ``i''
		}
	}
	numlist "`beta'"
	// TODO: add error handling?
	local beta `r(numlist)'
	
	local nbeta : word count `beta'
	if `nbeta' > 1 local val "Beta(Hypothesis)"
	else local val `beta'
	
	if "`hypotype'" == "eq" local hyposign "="
	else if "`hypotype'" == "lb" local hyposign ">"
	else if "`hypotype'" == "ub" local hyposign "<"
	
	sreturn local beta `beta'
	sreturn local hypotype `hypotype'
	sreturn local hyposign = "`hyposign'"
	sreturn local hypoval `val'
	
end

// PROGRAM: Parse Sensitivity Parameter
// DESCRIPTION: Parses the syntax for a `<sensparam>` option to `regsensitivity`
//              where <sensparam> is one of `rxbar`, `cbar`
// INPUT:
//   - anything: (numlist [eq bound]) specification for the sensitivity parameter
//               numlist is the value(s) for the parameter. The option specifies
//               how the parameter is interpreted:
//        - eq: Identified sets will be calculated for <sensparam> == #
//        - bound: Identified sets will be calaculated for |<sensparam>| <= #
//   - default: ({eq bound}) default option when not given explicitly 
program parse_sensparam, sclass

	syntax [anything], [default(string)]
	
	// defaults
	if "`default'" == "" local default bound 
	if "`anything'" == "" local anything 0
	
	// parse the option input 
	local ntokens : word count `anything' 
	tokenize `anything'
	local paramtype ``ntokens''
	local bound_abrev b bo bou boun bound
	local equal_abrev e eq equ equa equal
	local paramtypes `equal_abrev' `bound_abrev'
	
	local isparamtype : list paramtype in paramtypes
	
	if !`isparamtype' {
		// if no paramtype given in the, use the default
		local paramtype `default'
		local nparamtokens = `ntokens'
	}
	else {
		// otherwise extract the parameter type
		local isequal : list paramtype in eq_abrev
		local isbound : list paramtype in bound_abrev
		if `isequal' local paramtype eq
		else if `isbound' local paramtype bound
		
		local nparamtokens = `ntokens' - 1
	}
	
	local param
	forvalues i=1/`nparamtokens' {
		local param `param' ``i''
	}

	// TODO: add error handling?
	sreturn local param `param'
	sreturn local paramtype `paramtype'
	
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

	syntax anything, name(string) [lb(string) ub(string) ngrid(integer 200)]
	
	if "`lb'" == "" local lb .
	if "`ub'" == "" local ub .
	
	local nvals : word count `anything'
	if `nvals' == 2 {
		local up : word 2 of `anything'
		local lw : word 1 of `anything'
		local step = (`up' - `lw') / `ngrid'
		local anything "`lw'(`step')`up'"
	}
	numlist "`anything'"
	local anything `r(numlist)'
	
	foreach el of local anything {
		matrix `name' = nullmat(`name') \ clip(`el', `lb', `ub')
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
	real scalar beta_short, beta_med, r_short, r_med, var_x_resid
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
	
	gamma_med = covwy - s.beta_med * covwx 
	
	// R-squared for different regressions
	s.r_short = s.beta_short^2 * s.var_x / s.var_y
	s.r_med = (
		s.beta_med^2 * s.var_x 
		+ gamma_med' * s.wt * gamma_med
		+ 2 * s.beta_med * gamma_med' * s.wt * covwx
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
	idset = select(idset, idset[.,1] :<= max_bound)
	idx = quantiles(rows(idset), range(0, 1, .1))
	idset = idset[idx,1..cols(idset)]
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


