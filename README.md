# Exploring and Practicing MMM - Robyn

## Marketing mix modelling with Robyn on a synthetic benchmark with known ground truth

#### Question

Robyn reports channel ROI with a clean set of plots, but in real work nobody can check those numbers. This project runs Robyn on synthetic data where the true channel effects are known, and asks: when Robyn fits the sales well, does it also get the channel ROI right?

#### Data
Synthetic weekly retail benchmark, 156 weeks, three media channels (PLA, Meta, TV), from the paper A Synthetic Benchmark Dataset with Endogenous Marketing Spend for Validating Marketing Mix Models (arXiv 2608.21130). 
Generator code: [Synthetic_Data_Generation_for_MMM.ipynb].

The generator also records each week's true per-channel effect. I removed those columns before modelling and used them only to score the results.

**Model inputs:** total_sales, pla_spend, meta_spend, tv_spend, observed_promotion_dummy, observed_promotional_price_level. 
The two promotion variables carry measurement error by design. Spend is endogenous by design.
The year column was coded 1 to 3. 
I relabelled it 2022 to 2024 so the weekly dates line up with the ISO calendar.

**Method**
Robyn v3.12.1, R 4.6.1. Geometric adstock, Hill saturation, Prophet trend and season.
Time-series validation on, with the training share searched between 50% and 80%. 
- Run 1: 2,000 iterations per trial. Run 2: 4,000 iterations per trial, same setup.

**Hyperparameter ranges**: Used Robyn Recommended Ranges. Random seed: [42].

Model selection rules, drop models with an implausible story (for example a channel with zero effect), then take the lowest validation NRMSE among the cluster-top models.

## Exploratory analysis

Done on the model inputs only.

| Area | Finding | Decision |
|---|---|---|
| Data quality | 156 weeks, no gaps, duplicates, missing values or zero spend | None needed |
| Distributions | Sales and spend are right-skewed. TV sits near 10 in about 130 weeks, with 24 flight weeks at 75 to 165. Price has a second clump at 0.55 to 0.8 | Keep the allocator inside observed ranges (PLA 38 to 214, Meta 31 to 197, TV 7.5 to 167). Report TV with low confidence |
| Price | Sales are flat (about 2,440) whenever price is above 0.85, then rise to 3,649 at 0.7 to 0.85 and 4,489 below 0.7. A discount hinge near 0.9 correlates 0.82 with sales; raw price correlates -0.72 | Replace raw price with a discount hinge (Variant A). I picked the 0.9 cut-off by looking at sales |
| Promo flag | It disagrees with price: 10 weeks with price below 0.85 are not flagged, and 13 weeks at price 1 or higher are | Do not rely on the flag alone |
| Outliers | Flagged sales, PLA, Meta and price weeks fall on the same calendar slots each year (January, July, November), so they are events | Keep all of them. Check the STL remainder for true anomalies |
| Trend | No detectable trend. Yearly spend totals are nearly flat | Test a variant without the trend term. Assume a flat baseline for planning |
| Seasonality | Same-week sales correlate 0.91 to 0.97 across years. Sales spikes recur in weeks 3 to 5, 17, 28 to 29 and 47 to 48. PLA and Meta spend peak in the same windows, about one to two weeks earlier | Keep Prophet's season. Test delayed adstock for digital (Variant C). Do not read peak-season spend as higher efficiency |
| TV | Eight flights on fixed calendar dates (late May to June, late November to December). Flight weeks average 2,552 in sales against 2,788 otherwise | Fixed-calendar timing makes it hard to separate from season. Wide range |
| Multicollinearity | PLA and Meta correlate 0.75. VIF is 3.8 to 4.2 for the three channels, condition number 4.8. Only about a quarter of each channel's variance is unexplained by season and the other drivers | Moderate collinearity. Report PLA and Meta together (Variant B) |
| Model assumptions | A plain regression stand-in shows autocorrelated errors (Durbin-Watson 1.25), errors that grow with sales, mild curvature (RESET p = 0.01) and heavy-tailed errors. No single week dominates (largest Cook's distance 0.175) | Note as limits. Try a log-log model in Meridian or PyMC-Marketing |


**Results**

Robyn returned 113 Pareto models in 3 clusters. One top model per cluster, against the truth:
| | PLA ROAS | Meta ROAS | TV ROAS | Total ROAS | Media share of sales |
|---|---|---|---|---|---|
| **Truth** | 4.20 | 2.90 | 1.56 | 3.30 | 18.7% |
| Run 1: 2_268_5 | 0.63 | 0.66 | 0.56 | 0.63 | about 3.7% |
| Run 1: 1_161_1 | 0.27 | 0.29 | 0.27 | 0.27 | about 1.6% |
| Run 1: 1_199_7 | 0.15 | 0 | 0.22 | 0.11 | about 0.6% |
| Run 2: 1_483_3 | 0.39 | 0 | 0.67 | 0.31 | about 1.8% |
| Run 2: 1_199_7 | 0.15 | 0 | 0.22 | 0.11 | about 0.6% |
| Run 2: 1_428_5 | 0.23 | 0.22 | 0.23 | 0.23 | about 1.3% |

**First Observations**
--> The selection score pulled toward equal ROAS. DECOMP.RSSD rewards models whose effect shares match their spend shares. Clusters 1 and 3 have DECOMP.RSSD near 0.02 and give nearly equal ROAS to every channel, while the true order is PLA, then Meta, then TV.
--> The reported intervals for cluster 1 were: [0.25, 1.64] for PLA and [0.17, 1.67] for Meta, against true values of 4.20 and 2.90.
--> As per a blind rule selection, it chose 1_161_1, but 2_268_5 was closer to the truth on ROAS level and effect split. Both were far off, and the model with the lowest validation error (1_199_7) was the worst on channel ranking.
The search was not fully converged. Trials 3 to 5 were still improving at 2,000 iterations.

## What I found with additonal EDA

1. **A good fit did not mean correct attribution.** Adjusted R² on the training weeks was 0.82 to 0.85 across the top models, yet they credited media with 1 to 4% of sales against a true 18.7%. So we continued our feature engineering. 
2. **Meta at zero is a sign-constraint result.** In `pareto_aggregated.csv`, none of the 384 media coefficients is negative and 52 are exactly zero, all for Meta. A plain regression on the same inputs gives Meta a negative coefficient (-1.7, p = 0.32). Once PLA, season and price are in, Meta adds nothing, so Robyn clamps it to zero.
3. **The selection score pulled toward equal ROAS.** DECOMP.RSSD rewards models whose effect shares match their spend shares. Models in the low-RSSD family give nearly equal ROAS to every channel, while the true order is PLA, then Meta, then TV.
4. **The reported intervals did not contain the truth.** The in-cluster bootstrapped intervals describe spread across models, not accuracy.
5. **My selection rule picked the wrong model in run 1.** It chose 1_161_1, but 2_268_5 was closer to the truth on ROAS level and effect split. Both were far off.
6. **More iterations did not change the answer.** Run 2 reproduced the same trial-1 models. Trials 3 to 5 were still improving at 4,000 iterations, but no model in the run 2 Pareto set had a PLA or Meta ROAS above about 1.5.
7. **The inputs explain why attribution is hard.** Spend follows the calendar, so season absorbs much of it. Price drives sales through a threshold that a linear term misses. Only about a quarter of each channel's variation is independent of the other drivers.


**Limitations**
I have hypotheses for the under-attribution (noisy price and promotion variables, ridge shrinkage, the DECOMP.RSSD pull, incomplete convergence) but have not tested them yet.
Robyn defaults were used for everything not listed above.
Used a single seed for the runs

**Next steps**

- Compare with a plain ridge regression on the same adstocked inputs.
- A labelled diagnostic run with narrowed theta ranges, to see whether Robyn can recover the effects when helped.
- Fit the same data with Meridian or PyMC-Marketing.
- Budget allocation on the fitted response curves, and calibration with experiment results.
- Run more variants based on out learning from EDA
  - Variant A: replace raw price with the discount hinge.
  - Variant B: A, plus PLA and Meta combined into one digital variable.
  - Variant C: B, plus Weibull adstock for digital, to allow a delayed peak.
  - A variant without the trend term.
  - A log-log model in Meridian or PyMC-Marketing.
- Budget allocation on the fitted response curves.

**Credits and licence**
Data design from arXiv 2608.21130 (paper licensed CC BY 4.0; check the generator repository for its code licence). 
Model: Robyn (Meta).
