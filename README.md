# regsensitivity: A Stata Package for Regression Sensitivity Analysis

**Description**: Omitted variables are one of the most important threats to the identification of causal effects. In linear models, the well known Omitted Variable Bias formula shows how an omitted variable can bias the regression coefficient on the covariate of interest when that covariate is correlated with the omitted variable. Since is often implausible to assume that data has been collected on every relevant variable, applied research is often vulnerable to this bias. Nonetheless, omitted variable bias can be quantified under various alternative assumptions about the relationship between the omitted variable and the covariate of interest. Using these techniques, researchers can analyze how sensitive their results are to omitted variable bias.

Several methods of sensitivity analysis for linear models have been proposed in the literature. This repository contains a Stata module that implements the methods proposed in Diegert, Masten, and Poirier (2022), Oster (2019)[^1], and Masten and Poirier (2022). In each of these papers, the authors define a set of sensitivity parameters which index relaxations of the assumption that the covariate of interest is uncorrelated with any unobserved variables. The parameter of interest in both cases is $\beta_\text{long}$, the coefficient on that covariate of interest in the infeasible regression that includes the unobserved variables. Using this framework, we can ask two questions:

1. What is the set of parameter estimates for $\beta_\text{long}$ which are consistent with the relaxed assumptions? That is, what are bounds on the value of $\beta_\text{long}$ under the alternate assumptions?

2. How much can we relax the exogeneity assumption before a hypothesis about $\beta$ is overturned? This is called the _breakdown point_: the maximum relaxation of the baseline assumption before the hypothesis is overturned.

The package can be used to perform both of these sensitivity analyses using the sensitivity parameters defined in Diegert, Masten, and Poirier (2022) and Oster (2019). 

**Authors**: This module was written by Paul Diegert (Duke) in collaboration with [Matt Masten](https://mattmasten.github.io/) and [Alexandre Poirier](https://sites.google.com/site/alexpoirierecon/).

## Requirements

- Stata version 15 or later

## Installation

To install `regsensitivity` from within Stata:
```
ssc install regsensitivity
```
It can also be installed manually by copying all files in the `regsensitivityStataPackage` subdirectory to your `Stata/ado/personal` directory. For explanation of the syntax:
```
help regsensitivity
```

## Subdirectories

- regsensitivityStataPackage - Contains all Stata package files.
- vignette - Contains a vignette showing how to use the module. Specifically, it walks through the empirical illustration of Bazzi, Fiszbein, and Gebresilasse (2020) that is used in Diegert, Masten, and Poirier (2022).

## Troubleshooting

Please post problems or suggestions to the issue queue.

## References

Bazzi, Fiszbein, and Gebresilasse (2020) [Frontier Culture: The Roots and Persistence of Rugged Individualism in the United States](https://www.bu.edu/econ/files/2018/08/BFG_Frontier.pdf), _Econometrica_ ([Journal link](https://onlinelibrary.wiley.com/doi/abs/10.3982/ECTA16484))

Diegert, Masten, and Poirier (2022) [Assessing Omitted Variable Bias when the Controls are Endogenous](https://arxiv.org/abs/2206.02303), arXiv working paper

Masten, and Poirier (2022) [The Effect of Omitted Variables on the Sign of Regression Coefficients](https://arxiv.org/abs/2208.00552), arXiv working paper

Oster (2019) [Unobservable Selection and Coefficient Stability: Theory and Evidence](https://www.brown.edu/research/projects/oster/sites/brown.edu.research.projects.oster/files/uploads/Unobservable_Selection_and_Coefficient_Stability.pdf), _Journal of Business & Economic Statistics_ ([Journal link](https://www.tandfonline.com/doi/abs/10.1080/07350015.2016.1227711?journalCode=ubes20))

## License

&copy; 2022 Paul Diegert, Matt Masten, Alexandre Poirier

The contents of this repository are distributed under the MIT license. See file `LICENSE` for details.

[^1]: The analysis of Oster (2019) is also implemented in another Stata package, [`psacalc`](https://ideas.repec.org/c/boc/bocode/s457677.html), written by Emily Oster. Our package `regsensitivity` extends `psacalc`, providing additional functionality and a consistent user interface to compare results from various sensitivity analyses.