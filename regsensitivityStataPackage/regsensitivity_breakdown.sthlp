{smcl}
{* *! version 1.0.0  26may2022}{...}
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
[,{it:{help regsensitivity_breakdown##options:options}}]

{phang}
{it:depvar} is the dependent variable.

{phang}
{it:indepvar} is the primary independent variable.

{phang}
{it:controls} are additional covariates included in the regression. Can include 
factor and time series variables.

{synoptset 20 tabbed}{...}
{marker options}{...}
{synopthdr:options}
{synoptline}
{syntab: Calibration}
{synopt:{opt compare}({help varlist:varlist})}Subset of controls used to calibrate
deviations from identifying assumptions, default all controls{p_end}
{synopt:{opt nocompare}({help varlist:varlist})}Include all controls in comparison controls except these{p_end}

{syntab: Sensitivity parameters (dmp)}
{synopt:{opt c:bar}({help numlist:numlist})}Maximum correlation
between the controls and the unobserved variable; default 1{p_end}

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
on {it:indvar} in the infeasible long regression of {it:depvar} on {it:indvar}, {it:controls}, 
and the omitted variable. Although the omitted variable is not observed, using a set of assumptions indexed by
one or more sensitivity parameters, we can bound the impact of this omitted variable. This gives us a set of
feasible values for {it:beta}, called the identified set. A breakdown point is the smallest value of the sensitivity parameter such that the hypothesis about {it:beta} no longer holds for all values in the identified 
set for {it:beta}.

{pstd}
In the sensitivity analysis, there are three sensitivity parameters, 
{it:rxbar}, {it:rybar}, and {it:cbar}. The breakdown point is calculated for 
{it:rxbar}, holding the values of {it:rybar} and {it:cbar} 
fixed. The value of {it:cbar} are given in {cmd:cbar} option, while {it:rybar} is 
fixed at +inf. 

{pstd}
The hypothesis to be tested is specified in the {cmd:beta}  option. 
When multiple hypothesis are specified in the {cmd:beta} option, the breakdown point 
is calculated for each hypothesis. When multiple hypotheses are
specified, only one value {it:cbar} can be specified.

{pstd}
Results of the analysis are displayed in a table and saved in {cmd:e()}. To see
a plot of the results, use the {cmd:plot} option. For details on the analyses 
see {help regsensitivity_breakdown##remarks:Remarks}.  

{marker options}{...}
{title:Options}

{dlgtab: Calibration}

{p 4 4 2}
The sensitivity parameters used in the analysis are defined relative to
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
Sensitivity parameters used to relax the no omitted variable bias
assumption. The options
have been named to follow the notation in {browse "https://arxiv.org/abs/2206.02303":Diegert, Masten, and Poirier (2022)}. For more 
details on the definition of each sensitivity parameter, see the references 
listed {help regsensitivity##further_information:here}.

{pmore}
{cmd:cbar}({help numlist:numlist}) The maximum correlation between the comparison controls and an unobserved variable.

{p 4 4 2}
The {help numlist:numlist} specifies the values of the 
sensitivity parameters to use in the analysis. When exactly two values are given, these are interpreted as a range and are expanded to a uniform grid with {it:npoints} over this range. Otherwise, the {help numlist:numlist} is expanded normally. 

{dlgtab:Breakdown Hypothesis}

{phang}
This option specifies the hypothesis or hypotheses for which the breakdown point(s)
will be calculated. 

{pmore}
{opt beta}({help regsensitivity_breakdown##hypothesis:hypothesis}) The coefficient 
on {it:indvar} in a theoretical regression of {it:depvar} on 
{it:indvar}, {it:controls}, and an omitted variable.

{marker hypothesis}{...}
{p 4 4 2}
The {it:hypothesis} option has the following format:

{pmore}
{help numlist:numlist} [,lb ub]
{it:or}
sign

{p 4 4 2}
Hypothesese are of the format {it:beta} > {it:b} or {it:beta} < {it:b}.
The value(s) of {it:b} are given in the {help numlist:numlist}. 
The {help numlist:numlist} is processed as in the 
{cmd:cbar} option. 
When exactly two values are given, these are interpreted
as a range and are expanded to a uniform grid with {it:ngrid} over this range. 
Otherwise, {it:values} are expanded normally.   

{p 4 4 2}
The sign of the inequality of the hypothesis is specified by the optional
arguments. {cmd:lb}, and {cmd:ub} ("lower bound" and "upper bound") specify the
hypotheses {it:beta} > # and {it:beta} < # respectively. 

{p 4 4 2}
Alternatively {cmd:beta(sign)} tests the hypothesis that sign({it:beta}) = sign({it:beta_med}),
where {it:beta_med} is the coefficient on {it:indvar} of a regression of {it:depvar}
on {it:indvar} and {it:controls}. For example if the {it:beta_med} > 0, then
{cmd:sign} specifies the hypothesis {it:beta} > 0. 

{p 4 4 2}
The default is {cmd:sign}.

{dlgtab:Other options}

{phang}
Additional options.

{pmore}
{opt ngrid}(#) The number of points to include in a grid of points for the
sensitivity parameter or range of hypothesis.

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

