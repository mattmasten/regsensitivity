{smcl}
{* *! version 1.1.0  1aug2022}{...}
{viewerjumpto "Syntax" "regsensitivity##syntax"}{...}
{viewerjumpto "Description" "regsensitivity##description"}{...}
{viewerjumpto "Further Information" "regsensitivity##further_information"}{...}
{title:Title}

{phang}
{bf:regsensitivity} {hline 2} Regression sensitivity analysis

{marker syntax}{...}
{title:Syntax}

	{cmd:regsensitivity} {it:subcommand} ... [, {it: options}]

{synoptset 20 tabbed}{...}
{marker subcommand}{...}
{synopthdr:subcommand}
{synoptline}
{synopt :{helpb regsensitivity_bounds:bounds}}coefficient bounds{p_end}
{synopt :{helpb regsensitivity_breakdown:breakdown}}breakdown analysis{p_end}
{synopt :{helpb regsensitivity_plot:plot}}plot results{p_end}
{synoptline}

{pstd}
{cmd:regsensitivity} can be abbreviated to {cmd:regsen}.
	
{marker description}{...}
{title:Description}

{pstd}
{cmd:regsensitivity} analyzes the sensitivity of regression coefficient estimates 
to the presence of omitted variables. By default, relaxations of the no omitted
variables assumption are indexed by sensitivity parameters as defined in 
Diegert, Masten, and Poirier (2022). The package also implements the sensitivity analysis 
in Oster (2019) and Masten and Poirier (2022), which use a different set of sensitivity parameters.

{pstd}
{cmd:regsensitivity bounds} calculates bounds on the regression coefficient under
a range of alternative assumptions on the omitted variables.

{pstd}
{cmd:regression breakdown} calculates the maximum value of a sensitivity parameter
under which a given hypothesis holds for all values of the regression coefficients
in the identified set.

{pstd}
{cmd:regsensitivity plot} is a post-estimation command that can be run after
{cmd:regsensitivity bounds} or {cmd:regsensitivity breakdown} to visualize the results.

{marker options}{...}
{title:Options}

{phang}
{cmd: noplot} When called without any subcommands, regsensitivity produces sensitivity summary 
statistics and sensitivity plots for each method. The default auxiliary parameters are set to 
rybar = +inf and cbar = 1 for DMP, and R2long = 1 for Oster. These defaults can be changed by
using the options in the above subcommands. When calling regsensitivity without a subcommand,
select the noplot option to suppress these default plots. {sf} 

{marker further_information}{...}
{title:Further Information}

{p 4 4 4}
This package implements the sensitivity analysis described in {browse "https://arxiv.org/abs/2206.02303":Diegert, Masten, and Poirier (2022)}, 
{browse "https://www.tandfonline.com/doi/abs/10.1080/07350015.2016.1227711":Oster (2019)}, and {browse "https://arxiv.org/abs/2208.00552":Masten and Poirier (2022)}.

{p 4 4 4}
This {browse "https://github.com/mattmasten/regsensitivity/blob/master/vignette/vignette.pdf":vignette} provides a tutorial for use of this package walking through the empirical application in
{browse "https://arxiv.org/abs/2206.02303":Diegert, Masten, and Poirier (2022)}
using data from {browse "https://onlinelibrary.wiley.com/doi/abs/10.3982/ECTA16484":Bazzi, Fiszbein, and Gebresilasse (2020)}. If you are new to this package, this vignette is the best place to start.

{marker references}{...}
{title:References}

{marker BFG2020}{...}
{phang}
Bazzi, Fiszbein, and Gebresilasse (2020) Frontier Culture: The Roots and Persistence of "Rugged Individualism" in the United States, {it:Econometrica}

{marker DMP2022}{...}
{phang}
Diegert, Masten, and Poirier (2022) Assessing Omitted Variable Bias when the Controls are Endogenous, arXiv preprint

{marker MP2022}{...}
{phang}
Masten, and Poirier (2022) The Effect of Omitted Variables on the Sign of Regression Coefficients, arXiv preprint

{marker O2019}{...}
{phang}
Oster (2019) Unobservable Selection and Coefficient Stability: Theory and Evidence, {it:Journal of Business & Economic Statistics}
{p_end}
