{smcl}
{* *! version 1.1.0  1aug2022}{...}
{vieweralsosee "regensitivity" "regsensitivity"}{...}
{viewerjumpto "Syntax" "regsensitivity_plot##syntax"}{...}
{viewerjumpto "Description" "regsensitivity_plot##description"}{...}
{viewerjumpto "Options" "regsensitivity_plot##options"}{...}
{viewerjumpto "Remarks" "regsensitivity_plot##remarks"}{...}
{viewerjumpto "Stored Results" "regsensitivity_plot##results"}{...}
{viewerjumpto "Examples" "regsensitivity_plot##examples"}{...}
{title:Title}

{phang}
{bf:regsensitivity plot} {hline 2} Plot results of regression sensitivity analysis

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:regsensitivity} {cmd:plot}
[{cmd:,} 
{it:{help tesensitivity_cpiplot##display_options:display_options} {help regsensitivity_plot##formatting_options:formatting_options}]}

{synoptset 37 tabbed}{...}
{marker display_options}{...}
{synopthdr:display_options}
{synoptline}
{synopt:{opt nobreakdown}}suppress horizontal line for the breakdown point{p_end}
{synopt:{opt yrange}}set the range of the y axis manually{p_end}
{synopt:{opt ywidth}}set the range of the y axis symmetrically around beta(medium){p_end}
{synoptline}
{p 4 6 2}
{it:display_options} control the elements of the graph to be included.

{marker formatting_options}{...}
{synopthdr:formatting_options}
{synoptline}
{synopt:{opt boundpatterns}({it:pattern_list})}specify line patterns for bound lines{p_end}
{synopt:{opt boundcolors}({it:color_list})}specify line colors for bound lines{p_end}
{p2col: {opt boundoptions}({it:{help connect_options}})}additional options for bound lines{p_end}
{p2col: {opt breakdownoptions}({it:{help added_line_options}})}additional options for breakdown analysis conclusion line{p_end}
{p2col: {opt legoptions}({it:{help legend_options}})}formatting options for legend{p_end}
{p2col: {opt noleg:end}}suppress legend{p_end}
{p2col: {it:{help twoway_options}}}formatting options for overall plot{p_end}
{synoptline}
{p 4 6 2}
{it:formatting_options} control the style of the graph.

{marker description}{...}
{title:Desciption}

{pstd}
{cmd:regsensitivity plot} is a post estimation command that plots results
from a call to {cmd:{help regsensitivity:regsensitivity}}. When called
after {cmd:{help regsensitivity_idset:regsensitivity bounds}}, it plots
the upper and lower bounds of beta for a range of values of the sensitivity
parameter used in the analysis (rxbar or delta). When multiple values were
provided for the secondard sensitivity parameter (cbar or R-squared(long)),
multiple sets of bounds are plotted on the same plot. 

{pstd}
When plotting the identified set for the Oster (2019) with the {cmd:eq} option
selected for {cmd:delta}, the lines on the graph are the exact identified set.
Otherwise, the plot shows the upper and lower bounds.

{pstd}
When called after {cmd:{help regsensitivity_breakdown:regsensitivity breakdown}},
it plots the breakdown point as a function of the secondary sensitivity parameter
(cbar or R-squared(long)), or as a function of the hypothesis for the breakdown
point.

{pstd}
The graph is produced using Stata's {cmd:graph twoway} command, and formatting 
can be controlled by passing options to that command through the interface 
provided by this command.

{marker options}{...}
{title:Options}

{dlgtab:Display options}

{phang}
{cmd: nobreakdown} if this option is not chosen, a horizontal line is drawn at the
value of the breakdown analysis hypothesis. {sf} 

{phang}
{cmd: yrange} sets the range of the y-axis manually.{sf} 

{phang}
{cmd: ywidth} sets the range of the y-axis by centering the axis at beta(medium)
and expanding the axis by {cmd:ywidth} * Std(X) in either direction. This is
generally appropriate for the analysis in DMP (2022) since the identified set
is symmetric around beta(medium). {sf} 

{dlgtab:Formatting options}

{phang}
{cmd: boundpatterns}({it:pattern_list}) bounds for each of the values of the secondary sensitivity parameter are 
plotted using these patterns. {it:pattern_list} is a list of up to 8 {help linepatternstyle:linepatternstyles}
separated by spaces. If only one pattern is specified it is used for all 
estimates. 

{phang}
{cmd: boundcolors}({it:color_list}) bounds for each of the values of the secondary sensitivity parameterare 
plotted using these colors. {it:color_list} is a list of up to 8 {help colorstyle:colorstyles}
separated by spaces. If only one pattern is specified it is used for all 
estimates.

{phang}
{cmd: boundoptions}({it:{help connect_options}}) bound lines for all the values of the secondary sensitivity parameter
are plotted with these options. Any options in {it:{help connect_options}}
may be included except for {cmd:lpattern} and {cmd:lcolor}.

{phang}
{cmd: breakdownoptions}({it:{help added_line_options}}) a horizontal line at the 
breakdown analysis conclusion is plotted with these display options. Any suboptions to 
{it:{help added_line_options}} may be included.

{phang}
{cmd: legoptions}({it:{help legend_options}}) by default, a legend is added to the
plot if the secondary sensitivity parameter has multiple values.
Any {it:{help legend_options}} can be included except {cmd:order} or {cmd:label}.

{phang}
{cmd: nolegend} suppresses the legend.

{phang}
{cmd:{it:{help twoway_options}}} any additional {it:{help twoway_options}} to
Stata's {cmd:{help twoway}} command may be included except for {it:{help legend_options}}
 
{marker remarks}{...}
{title:Remarks}

{p 4 4 4}
See {help regsensitivity##further_information:here} for links to the articles 
this package is based on, more detailed documentation on the implementation in 
this package, and examples of its use.
 
{marker examples}{...}
{title:Examples}

{phang}{cmd:. sysuse bfg2020, clear}{p_end}
{pstd}Loads Bazzi, Fiszbein, and Gebresilasse (2020) dataset included with regsensitivity package.

{phang}{cmd:. local y avgrep2000to2016}{p_end}
{phang}{cmd:. local x tye_tfe890_500kNI_100_l6}{p_end}
{phang}{cmd:. local w1 log_area_2010 lat lon temp_mean rain_mean elev_mean d_coa d_riv d_lak ave_gyi}{p_end}
{phang}{cmd:. local w0 i.statea}{p_end}
{pstd}Set the variables to use in the analysis

{phang}{cmd:. regsensitivity bounds `y' `x' `w1' `w0', compare(`w1') oster delta(-2 2)}{p_end}
{pstd}
Calculates the identified set for Beta across a range of values of {it:rxbar},
holding {it:cbar} fixed at 1. Displays a table with the results and stores the
results in {cmd:e()}, and plots the results.

{phang}{cmd:. regsensitivity plot, xline(1)}{p_end}
{pstd}
Plots the results, showing a vertical line at x = 1 where there is an asymptote.

{phang} For more examples see this {browse "https://github.com/mattmasten/regsensitivity/blob/master/vignette/vignette.pdf":vignette}.
