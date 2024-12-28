{smcl}
{* *! version 1.1.0  1aug2022}{...}
{vieweralsosee "regensitivity" "regsensitivity"}{...}
{viewerjumpto "Syntax" "regsensitivity_breakdown##syntax"}{...}
{viewerjumpto "Description" "regsensitivity_breakdown##description"}{...}
{viewerjumpto "Options" "regsensitivity_breakdown##options"}{...}
{viewerjumpto "Remarks" "regsensitivity_breakdown##remarks"}{...}
{viewerjumpto "Stored Results" "regsensitivity_breakdown##results"}{...}
{viewerjumpto "Examples" "regsensitivity_breakdown##examples"}{...}
{title:Title}

{phang}
{cmd:regsensitivity breakdown} {hline 2} Regression sensitivity analysis, Breakdown analysis

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:regsensitivity breakdown}
{it:{help varname:depvar}} {it:{help varname:indepvar}}
{it:{help varlist:controls}}
{ifin}
[,{it:{help regsensitivity_breakdown##analysis:analysis}} 
{it:{help regsensitivity_breakdown##options:options}}]

{phang}
{it:depvar} is the dependent variable.

{phang}
{it:indepvar} is the primary independent variable.

{phang}
{it:controls} are additional covariates included in the regression. Can include 
factor and time series variables.

{synoptset 20 tabbed}{...}
{marker analysis}{...}
{synopthdr:analysis}
{synoptline}
{synopt:{opt dmp}}Diegert, Masten, and Poirier (2022); the default{p_end}
{synopt:{opt oster}}Oster (2019) and Masten and Poirier (2022){p_end}
{synoptline}
{p 4 6 2}
{it:analysis} specifies the sensitivity analysis to be performed. 

{synoptset 20 tabbed}{...}
{marker options}{...}
{synopthdr:options}
{synoptline}
{syntab: Calibration}
{synopt:{opt compare}({help varlist:varlist})}Subset of controls used to calibrate
deviations from identifying assumptions, default all controls{p_end}
{synopt:{opt nocompare}({help varlist:varlist})}Include all controls in comparison controls except these{p_end}

{syntab: Sensitivity parameters (dmp)}
{synopt: {opt ry:bar}({help regsensitivity_bounds##param_spec:param_spec})}Magnitude of effect of the omitted variable on {it:depvar} relative to comparison controls{p_end}
{synopt:{opt c:bar}({help regsensitivity_breakdown##param_spec:param_spec})}Maximum correlation
between the comparison controls and the omitted variable; default 1{p_end}

{syntab: Sensitivity parameters (oster)}
{synopt:{opt r2long}({help regsensitivity_breakdown##param_spec:param_spec})}R-squared of a regression of {it:depvar} on {it:indepvar}, the comparison controls, and the omitted variable; default 1{p_end}
{syntab: Breakdown Hypothesis}
{synopt:{opt beta}({help regsensitivity_breakdown##hypothesis:hypothesis})}Calculate breakdown point relative to this hypothesis; default {help regsensitivity_breakdown##hypothesis:sign}{p_end}

{syntab: Other}
{synopt:{opt ngrid(#)}} Number of points in a grid when expanding values of a sensitivity parameter{p_end}
{synopt:{opt plot}} Plot the results{p_end}

{marker description}{...}
{title:Description}

{pstd}
{cmd:regsensitivity breakdown} calculates one or more breakdown points for a given
hypothesis or hypotheses about the parameter {it:beta}. {it:Beta} is the coefficient
on {it:indepvar} in the infeasible long regression of {it:depvar} on {it:indepvar}, {it:controls}, 
and the omitted variable. Although the omitted variable is not observed, using a set of assumptions indexed by
one or more sensitivity parameters, we can bound the impact of this omitted variable. This gives us a set of
feasible values for {it:beta}, called the identified set. A breakdown point is the smallest value of the sensitivity parameter such that the hypothesis about {it:beta} no longer holds for all values in the identified 
set for {it:beta}.

{pstd}
When {cmd:dmp} is selected, the sensitivity analysis in Diegert, Masten, and Poirier 
(2022) is implemented. In that analysis, there are three sensitivity parameters, 
{it:rxbar}, {it:rybar}, and {it:cbar}. The breakdown point is calculated for 
{it:rxbar}, holding the values of {it:rybar} and {it:cbar} 
fixed. The value of {it:cbar} are given in {cmd:cbar} and {cmd:rybar} options.

{pstd}
When {cmd:oster} is selected, the analysis in Oster (2019) is implemented, along with the Masten and Poirier (2022) extensions. In 
that analysis, there are two sensitivity parameters, {it:delta}, and {it:R-squared(long)}.
The breakdown point is calculated for {it:delta}, holding 
the values of {it:R-squared(long)} fixed. The value of {it:R-squared} is given in 
{cmd:r2long} option.

{pstd}
The hypothesis to be tested is specified in the {cmd:beta}  option. 
When multiple hypotheses are specified in the {cmd:beta} option, the breakdown point 
is calculated for each hypothesis. When multiple hypotheses are
specified, only one value {it:cbar} or {it:R-squared(long)} can be specified.

{pstd}
Results of the analysis are displayed in a table and saved in {cmd:e()}. To see
a plot of the results, use the {cmd:plot} option. For details on the analyses 
see {help regsensitivity_breakdown##remarks:Remarks}.  

{marker options}{...}
{title:Options}

{dlgtab:Analysis}

{phang}
{it: analysis} is one of two sensitivity analyses proposed in the literature. Only one 
statistic can be specified. 

{pmore}
{cmd:dmp} selects the sensitivity analysis proposed in Diegert, Masten, and Poirier (2022)

{pmore}
{cmd:oster} selects the sensitivity analysis proposed in Oster (2019) and extended in Masten and Poirier (2022)

{dlgtab: Calibration}

{p 4 4 2}
The sensitivity parameters used in the analyses in
Diegert, Masten, and Poirier (2022), Oster (2019), and Masten and Poirier (2022) are defined relative to
a set of observed variables. These options are used to select the variables
included in the comparison controls. 

{pmore}
{opt compare}({help varlist:varlist}) Selects the variables to include
in the comparison controls{p_end}

{pmore}
{opt nocompare}({help varlist:varlist}) Selects the variables to exclude
from the comparison controls{p_end}

{dlgtab:Sensitivity Parameters}

{p 4 4 2}
The sensitivity parameters used to relax the no omitted variable bias
assumption as proposed in the paper referenced for each analysis. The options
have been named to follow the notation in each corresponding paper. For more 
details on the definition of each sensitivity parameter, see the referenced paper. 

{p 4 4 2}
Diegert, Masten, and Poirier (2022)

{pmore}
{cmd:rybar}({help regsensitivity_bounds##param_spec:param_spec}) Ratio of the norms of the coefficients on the comparison controls and
the unobserved variable in the infeasible regression of {it:depvar} on {it:indepvar} and the
{it:controls} and the unobserved variable.

{pmore}
{cmd:cbar}({help regsensitivity_breakdown##param_spec:param_spec}) The maximum correlation between the comparison controls and an unobserved variable.

{p 4 4 2}
Oster (2019)

{pmore}
{cmd:r2long}({help regsensitivity_breakdown##param_spec:param_spec}) The R-squared in the infeasible long regression of {it:depvar}
on {it:indepvar}, {it:controls}, and the unobserved variable.

{pmore}
{cmd:maxovb}({help regsensitivity_bounds##param_spec:param_spec}) Maximum absolute value of the omitted variable bias, defined in Masten and Poirier (2022).

{marker param_spec}{...}
{p 4 4 2}
The {it:param_spec} option has the following format:

{pmore}
{help numlist:numlist} [,eq bound relative]

{p 4 4 2}
or

{pmore}
={it:param_exp}

{p 4 4 2}
In the first form, the {help numlist:numlist} specifies the values of the 
sensitivity parameters to use in the analysis.

{p 4 4 2}
When the {it:eq} option is selected ({it:"equal"}), the identified set is calculated 
under the assumption that the sensitivity parameter is equal to the values provided.

{p 4 4 2}
When the {it:bound} option is selected, the identified set is calculated 
under the assumption that the norm of the sensitivity parameter is bounded by the values provided.

{p 4 4 2}
When the {it:relative} option is selected, the input is interpreted relative to a reference
value. For {cmd:r2long}, the reference value is R-squared(medium). For {cmd:maxovb}, the
reference value is the absolute value of Beta(medium). For {cmd:r2long}, for example,
{cmd:r2long(1.3, relative)} is converted to 1.3*R-squared(medium).  

{p 4 4 2}
The following table describes the defaults and availability of the options for
each analysis:

{col 25}{c |}{center 20:equal}{col 45}{center 20:bound}{col 65}{center 20:relative}
{col 5}{hline 20}{c +}{hline 60}
{col 5}{it:DMP (2022)}{col 25}{c |}
{col 25}{c |}
{col 7}{cmd:rxbar}{col 25}{c |}{center 20:Not Implemented}{col 45}{center 20:Default}{col 65}{center 20:Not Implemented}
{col 25}{c |}
{col 7}{cmd:cbar}{col 25}{c |}{center 20:Not Implemented}{col 45}{center 20:Default}{col 65}{center 20:Not Implemented}
{col 25}{c |}
{col 5}{hline 20}{c +}{hline 60}
{col 5}{it:Oster (2019)}{col 25}{c |}
{col 25}{c |}
{col 7}{cmd:delta}{col 25}{c |}{center 20:Default}{col 45}{center 20:Implemented}{col 65}{center 20:Not Implemented}
{col 25}{c |}
{col 7}{cmd:r2long}{col 25}{c |}{center 20:Default}{col 45}{center 20:Not Implemented}{col 65}{center 20:Implemented}
{col 25}{c |}
{col 7}{cmd:maxovb}{col 25}{c |}{center 20:Not Implemented}{col 45}{center 20:Default}{col 65}{center 20:Implemented}

{p 4 4 2}
In the second form, {it:param_exp} is an expression involving the other sensitivity
parameters. At present this is only implemented when {cmd:dmp} with {cmd:rybar(=rxbar)}.
In this case the breakdown point is calculated for {it:rxbar} where {it:rxbar} = {it:rybar}.

{dlgtab:Breakdown Hypothesis}

{phang}
This option specifies the hypothesis or hypotheses for which the breakdown point(s)
will be calculated. 

{pmore}
{opt beta}({help regsensitivity_breakdown##hypothesis:hypothesis}) The coefficient 
on {it:indepvar} in a theoretical regression of {it:depvar} on 
{it:indepvar}, {it:controls}, and an omitted variable.

{marker hypothesis}{...}
{p 4 4 2}
The {it:hypothesis} option has the following format:

{pmore}
{help numlist:numlist} [,lb ub eq]

{p 4 4 2}
or

{pmore}
sign

{p 4 4 2}
Hypothesese are of the format {it:beta} > {it:b}, {it:beta} < {it:b}, or {it:beta} != {it:b}. 
The value(s) of {it:b} are given in the {help numlist:numlist}. 

{p 4 4 2}
The sign of the (in)equality of the hypothesis is specified by the optional
arguments. {cmd:lb}, and {cmd:ub} ("lower bound" and "upper bound") specify the
hypotheses {it:beta} > # and {it:beta} < # respectively. {cmd:eq} specifies the hypothesis,
beta != 0.

{p 4 4 2}
{cmd:sign} tests the hypothesis that sign({it:beta}) = sign({it:beta_med}),
where {it:beta_med} is the coefficient on {it:indepvar} of a regression of {it:depvar}
on {it:indepvar}, {it:controls}. For example if the {it:beta_med} > 0, then
{cmd:sign} specifies the hypothesis {it:beta} > 0.

{p 4 4 2}
Note that the {cmd:eq} option can only be used when the {cmd:oster} option has
been selected and the {cmd:delta} option has been specified with the option {cmd:eq}.
If {cmd:eq} has been specified for either {cmd:delta} or {cmd:beta}, the other
is set to {cmd:eq} automatically.

{dlgtab:Additional options}

{pmore}
{opt ngrid}(#) The number of points to include in a grid of points for the
sensitivity parameter or range of hypothesis. This is only used for the number
of points stored in {cmd:e(breakfront)}.

{pmore}
{opt plot} Produce a plot of the results.

{marker remarks}{...}
{title:Remarks}

{p 4 4 4}
See {help regsensitivity##further_information:here} for links to the articles 
this package is based on, more detailed documentation on the implementation in 
this package, and examples of its use.

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:regsensitivity breakdown} stores the following in {cmd:e()}:

{synoptset 20 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:e(N)}}Number of observations{p_end}
{synopt:{cmd:e(hypoval)}}Value of the hypothesis{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:regsensitivity}{p_end}
{synopt:{cmd:e(subcmd)}}{cmd:breakdown}{p_end}
{synopt:{cmd:e(cmdline)}}Command as typed{p_end}
{synopt:{cmd:e(depvar)}}Dependent variable{p_end}
{synopt:{cmd:e(indvar)}}Primary independent variable{p_end}
{synopt:{cmd:e(controls)}}Additional controls{p_end}
{synopt:{cmd:e(compare)}}Subset of controls used as a reference for the sensitivity analysis{p_end}
{synopt:{cmd:e(analysis)}}Sensitivity analysis performed{p_end}
{synopt:{cmd:e(hyposign)}}Sign of the hypothesis{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 15 19 2: Matrices}{p_end}
{synopt:{cmd:e(sumstats)}}Summary statistics displayed in the table header{p_end}
{synopt:{cmd:e(breakfront)}}Breakdown points including all {cmd:ngrid} points{p_end}
{synopt:{cmd:e(breakfront_table)}}Breakdown points exactly as shown in the output{p_end}

{marker examples}{...}
{title:Examples}

{phang}{cmd:. sysuse bfg2020, clear}{p_end}
{pstd}Loads Bazzi, Fiszbein, and Gebresilasse (2020) dataset included with regsensitivity package.

{phang}{cmd:. local y avgrep2000to2016}{p_end}
{phang}{cmd:. local x tye_tfe890_500kNI_100_l6}{p_end}
{phang}{cmd:. local w1 log_area_2010 lat lon temp_mean rain_mean elev_mean d_coa d_riv d_lak ave_gyi}{p_end}
{phang}{cmd:. local w0 i.statea}{p_end}
{pstd}Set the variables to use in the analysis

{phang}{cmd:. regsensitivity breakdown `y' `x' `w1' `w0', compare(`w1') cbar(0(.1)1), plot}{p_end}
{pstd}
Calculates the breakdown frontier for the hypothesis that {it:beta} > 0 for a 
range of values of {it:cbar}. Displays a table with the results and stores the
results in {cmd:e()}, and plots the results.

{phang} For more examples see this {browse "https://github.com/mattmasten/regsensitivity/blob/master/vignette/vignette.pdf":vignette}.

