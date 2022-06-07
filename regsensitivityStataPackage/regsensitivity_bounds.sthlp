{smcl}
{* *! version 1.0.0  26may2022}{...}
{vieweralsosee "regensitivity" "regsensitivity"}{...}
{viewerjumpto "Syntax" "regsensitivity_bounds##syntax"}{...}
{viewerjumpto "Description" "regsensitivity_bounds##description"}{...}
{viewerjumpto "Options" "regsensitivity_bounds##options"}{...}
{viewerjumpto "Remarks" "regsensitivity_bouunds##remarks"}{...}
{viewerjumpto "Stored Results" "regsensitivity_bounds##results"}{...}
{viewerjumpto "Examples" "regsensitivity_bounds##examples"}{...}
{title:Title}

{phang}
{cmd:regsensitivity bounds} {hline 2} Regression sensitivity analysis, Bounds

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:regsensitivity bounds}
{it:{help varname:depvar}} {it:{help varname:indepvar}}
{it:{help varlist:controls}}
{ifin}
[, {it:{help regsensitivity_bounds##options:options}}]

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

{syntab: Sensitivity parameters}
{synopt:{opt rx:bar}({help numlist:numlist})}Magnitude of effect of an unobservabled variable on {it:indvar} relative to comparison controls{p_end}
{synopt:{opt c:bar}({help numlist:numlist})}Maximum correlation
between comparison controls and the unobserved variable; default 1{p_end}

{syntab: Breakdown Hypothesis}
{synopt:{opt beta}({help regsensitivity_bounds##hypothesis:hypothesis})}Calculate breakdown point relative to this hypothesis; default {help regsensitivity_bounds##hypothesis:sign} {p_end}

{syntab: Other}
{synopt:{opt ngrid(#)}} Number of points in a grid when expanding values of a sensitivity parameter{p_end}
{synopt:{opt plot}} Plot the results{p_end}

{marker description}{...}
{title:Description}

{pstd}
{cmd:regsensitivity bounds} estimates bounds on the coefficient {it:beta}
on {it:indepvar} obtained from the infeasible long regression of {it:depvar} on {it:indepvar}, {it:controls}, and the unobserved omitted variable. The bounds are given under a range of 
assumptions about the impact of this omitted variable. These assumptions are 
indexed by one or more sensitivity parameters.

{pstd}
In the sensitivity analysis, there are three sensitivity parameters, {it:rxbar}, {it:rybar},
and {it:cbar}. Bounds are calculated for a range of values of the sensitivity
parameters given in the {cmd:rxbar} and {cmd:cbar} options, while {it:rybar} is 
fixed at +infty.

{pstd}
The breakdown point for the hypothesis specified in the {cmd:beta} option is also calculated.

{pstd}
Results of the analysis are displayed in a table and saved in {cmd:e()}. For details 
on the analyses see {help regsensitivity_bounds##remarks:Remarks}.  

{marker options}{...}
{title:Options}

{dlgtab: Calibration}

{p 4 4 2}
The sensitivity parameters used in the anlysis are defined relative to
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
have been named to follow the notation in {browse "https://arxiv.org/pdf/2206.02303.pdf":Diegert, Masten, and Poirier (2022)}. For more 
details on the definition of each sensitivity parameter, see the references 
listed {help regsensitivity##further_information:here}.

{pmore}
{cmd:rxbar}({help numlist:numlist}) This parameter is one way to define the magnitude 
of "selection on unobservables compared to selection on observables." In the 
infeasible regression of {it:indepvar} on the {it:controls} and the unobserved 
variable, {it:rxbar} is the ratio of the norms of the coefficients on the 
comparison controls and the unobserved variable. 

{pmore}
{cmd:cbar}({help numlist:numlist}) The maximum correlation between the comparison controls and the unobserved variable.

{p 4 4 2}
For each option, the {help numlist:numlist} specifies the values of the 
sensitivity parameters to use in the analysis. When exactly two values are given, these are interpreted as a range and are expanded to a uniform grid with {it:npoints} over this range. Otherwise, the {help numlist:numlist} is expanded normally. 

{dlgtab:Breakdown Hypothesis}

{phang}
This option specifies the hypothesis or hypotheses for which the breakdown point(s)
will be calculated. 

{pmore}
{opt beta}({help regsensitivity_bouunds##hypothesis:hypothesis}) The coefficient 
on {it:indvar} in a theoretical regression of {it:depvar} on 
{it:indvar}, {it:controls}, and an omitted variable.

{marker hypothesis}{...}
{p 4 4 2}
The {it:hypothesis} option has the following format:

{pmore}
# [,lb ub]
{it:or}
sign

{p 4 4 2}
Hypothesese are of the format {it:beta} > # or {it:beta} < #. 

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

{dlgtab:General options}

{phang}
Options

{pmore}
{opt ngrid}(#) The number of points to include in a grid of points for the
sensitivity parameter or range of hypothesis.

{pmore}
{opt plot} Show a plot of the results.

{marker remarks}{...}
{title:Remarks}

{p 4 4 4}
See {help regsensitivity##further_information:here} for links to the articles 
this package is based on, more detailed documentation on the implementation in 
this package, and examples of its use.

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:regsensitivity bounds} stores the following in {cmd:e()}:

{synoptset 20 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:e(N)}}Number of observations{p_end}
{synopt:{cmd:e(hypoval)}}Value of the hypothesis for breakdown point{p_end}
{synopt:{cmd:e(breakdown)}}Breakdown point {p_end}

{synoptset 20 tabbed}{...}
{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:regsensitivity}{p_end}
{synopt:{cmd:e(subcmd)}}{cmd:bounds}{p_end}
{synopt:{cmd:e(cmdline)}}Command as typed{p_end}
{synopt:{cmd:e(depvar)}}Dependent variable{p_end}
{synopt:{cmd:e(indvar)}}Primary independent variable{p_end}
{synopt:{cmd:e(controls)}}Additional controls{p_end}
{synopt:{cmd:e(compare)}}Subset of controls used as a reference for the sensitivity analysis{p_end}
{synopt:{cmd:e(analysis)}}Sensitivity analysis performed{p_end}
{synopt:{cmd:e(sparam1)}}Primary sensitivity parameter used to index the identified sets{p_end}
{synopt:{cmd:e(sparam2)}}Secondary sensitivity parameter used to index the identified sets{p_end}
{synopt:{cmd:e(sparam1_option)}}Option given in the {it:{help regesnsitivity_idset##param_spec:param_spec}} for {cmd:e(sparam1)}{p_end}
{synopt:{cmd:e(sparam2_option)}}Option given in the {it:{help regesnsitivity_idset##param_spec:param_spec}} for {cmd:e(sparam2)}{p_end}
{synopt:{cmd:e(hyposign)}}Sign of the hypothesis for breakdown point{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 15 19 2: Matrices}{p_end}
{synopt:{cmd:e(sumstats)}}Summary statistics displayed in the header of the output{p_end}
{synopt:{cmd:e(idset_table)}}identified set exactly as displayed in the output{p_end}
{synopt:{cmd:e(sparam2_vals)}}Values of the secondary sensitivity parameter{p_end}
{synopt:{cmd:e(idset#)}}Identified set for each value of {cmd:e(sensparam1)} holding {cmd:e(sensparam2)} fixed at value # of {cmd:e(sparam2_vals)}{p_end}

{marker examples}{...}
{title:Examples}

{phang}{cmd:. sysuse bfg2020, clear}{p_end}
{pstd}Loads Bazzi, Fiszbein, and Gebresilasse (2020) dataset included with regsensitivity package.

{phang}{cmd:. local y avgrep2000to2016}{p_end}
{phang}{cmd:. local x tye_tfe890_500kNI_100_l6}{p_end}
{phang}{cmd:. local w1 log_area_2010 lat lon temp_mean rain_mean elev_mean d_coa d_riv d_lak ave_gyi}{p_end}
{phang}{cmd:. local w0 i.statea}{p_end}
{pstd}Set the variables to use in the analysis

{phang}{cmd:. regsensitivity bounds `y' `x' `w1' `w0', compare(`w1') plot}{p_end}
{pstd}
Calculates the identified set for Beta across a range of values of {it:rxbar},
holding {it:cbar} fixed at 1. Displays a table with the results and stores the
results in {cmd:e()}, and plots the results.

{phang} For more examples see this {browse "https://github.com/mattmasten/regsensitivity/blob/master/vignette/vignette.pdf":vignette}.

