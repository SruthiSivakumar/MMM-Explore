# Exploring and Practicing MMM - Robyn

## Marketing mix modelling with Robyn on a synthetic benchmark with known ground truth
(Follow the slides if you want a quick snapshot:

<img width="893" height="434" alt="image" src="https://github.com/user-attachments/assets/a47bbf8b-4f68-4a51-a9ce-3688bbf9afec" />
<img width="872" height="424" alt="image" src="https://github.com/user-attachments/assets/9119d295-a22b-425b-902f-f07c6d660232" />
<img width="870" height="439" alt="image" src="https://github.com/user-attachments/assets/225074dd-2d20-4a42-945d-560171d4814d" />
<img width="887" height="464" alt="image" src="https://github.com/user-attachments/assets/3c5f88e5-18ba-440f-9cb2-709f1af1e200" />


#### Question
Robyn reports channel ROI with a clean set of plots, but in real work nobody can check those numbers. This project runs Robyn on synthetic data where the true channel effects are known, and asks: when Robyn fits the sales well, does it also get the channel ROI right?

### Objective  
Perform budget allocation for future with 1M$ budget to improve ROAS.

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

**Model selection rules**
drop models with an implausible story (for example a channel with zero effect), 
then take the lowest validation NRMSE among the cluster-top models.

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

### Variants A and D

Both replace raw price with the discount hinge `max(0, 0.9 - price)`. Variant D also drops the Prophet trend term. 2,000 iterations, 5 trials, seed 123. Variants are judged without the truth.

| | A (seed 123) | A2 (second seed) | D (seed 123) |
|---|---|---|---|
| Pareto models | 111 | 125 | 116 |
| Models with Meta exactly zero | 42 | 0 | 26 |
| Validation NRMSE across cluster tops | 0.088 to 0.095 | 0.095 to 0.197 | 0.087 to 0.099 |
| Test NRMSE across cluster tops | 0.114 to 0.117 | not recorded | 0.116 to 0.118 |
| Media share of sales | 2.6 to 8.5% | 4.0 to 13.5% | 3.4 to 7.8% |
| PLA ROAS above Meta | 2 of 5 tops | 2 of 7 tops | 4 of 4 tops |

A "D2" rerun gave output identical to D, so its seed was not changed. It counts as one run, not a second seed.

Variant D cluster tops (ROAS is the average `roi_total`):

| Model | Validation NRMSE | PLA | Meta | TV | Total | Media share |
|---|---|---|---|---|---|---|
| 1_252_7 | 0.0910 | 0.62 | 0.60 | 0.45 | 0.58 | 3.4% |
| 2_284_2 | 0.0869 | 0.91 | 0.80 | 0.64 | 0.83 | 4.7% |
| 5_265_3 | 0.0985 | 1.21 | 0.82 | 0.91 | 1.03 | 5.9% |
| 5_269_7 | 0.0932 | 1.43 | 1.20 | 1.48 | 1.36 | 7.8% |

Total ROAS is the spend-weighted average of the channel values, from the 156-week spend totals.
Chosen model: 2_284_2, the lowest validation NRMSE among all cluster tops in A, A2 and D, under the rule written beforehand.

### Budget allocation (Variant D, `budget_allocation.R`)

Robyn's allocator keeps the total budget fixed and searches for the split that maximises modelled response, with each channel limited to 70% to 130% of its average weekly spend. I set those bounds.

Current weekly spend: PLA 76 on average (range 38 to 214), Meta 52.5 (31 to 197), TV 27.5 (7.5 to 167, median 10.3).

All four D tops give the same spend moves: PLA +30%, Meta -27.6%, TV -30%. PLA is at its upper bound and TV at its lower bound, so the size of the move is set by my bounds. Total media response rises 22 to 29%.

Applied to a budget of 1,000k at the current mix:

| | Now | Plan |
|---|---|---|
| PLA | 486k | 632k |
| Meta | 337k | 244k |
| TV | 177k | 124k |

Modelled blended ROAS moves from 0.58 to 0.71 (1_252_7), 0.83 to 1.06 (2_284_2), 1.03 to 1.25 (5_265_3) and 1.36 to 1.66 (5_269_7). These are model predictions. Nothing in the data has tested them.


**First Observations before EDA**
--> The selection score pulled toward equal ROAS. DECOMP.RSSD rewards models whose effect shares match their spend shares. Clusters 1 and 3 have DECOMP.RSSD near 0.02 and give nearly equal ROAS to every channel, while the true order is PLA, then Meta, then TV.
--> The reported intervals for cluster 1 were: [0.25, 1.64] for PLA and [0.17, 1.67] for Meta, against true values of 4.20 and 2.90.
--> As per rule selection criteria i drew out before hand, i chose 1_161_1, but 2_268_5 was closer to the truth on ROAS level and effect split. Both were far off, and the model with the lowest validation error (1_199_7) was the worst on channel ranking.
The search was not fully converged. Trials 3 to 5 were still improving at 2,000 iterations.

## Additional Observations with EDA and Feature Engineering

1. **A good fit did not mean correct attribution.** Adjusted R² on the training weeks was 0.82 to 0.85 across the top models, yet they credited media with 1 to 4% of sales against a true 18.7%. So we continued our feature engineering. 
2. **Meta at zero in most runs** In `pareto_aggregated.csv`, none of the 384 media coefficients is negative and 52 are exactly zero, all for Meta. A plain regression on the same inputs gives Meta a negative coefficient (-1.7, p = 0.32). Once PLA, season and price are in, Meta adds nothing, so Robyn clamps it to zero.
3. **The selection score pulled toward equal ROAS.** DECOMP.RSSD rewards models whose effect shares match their spend shares. Models in the low-RSSD family give nearly equal ROAS to every channel, while the true order is PLA, then Meta, then TV.
4. **The reported intervals did not contain the truth.** The in-cluster bootstrapped intervals describe spread across models, not accuracy.
5. **More iterations did not change the answer.** Run 2 reproduced the same trial-1 models. Trials 3 to 5 were still improving at 4,000 iterations, but no model in the run 2 Pareto set had a PLA or Meta ROAS above about 1.5.
6. **The inputs explain why attribution is hard.** Spend follows the calendar, so season absorbs much of it. Price drives sales through a threshold that a linear term misses. Only about a quarter of each channel's variation is independent of the other drivers.
7. **The seed moves the channel split a lot.** Variant A with two seeds went from 42 Meta-zero models to none, and the order of PLA and Meta flipped (PLA above Meta in 2 of 5 tops, then 2 of 7). The gap between A and D in Meta-zero models (42 against 26) is inside that noise, so I cannot say that dropping trend helped.
8. **Dropping the trend term changed test error by under 0.002.** That matches the EDA, which found no trend (slope -78 per year, p = 0.32). I kept D as the simpler base.
9. **The allocator result is a corner solution.** Two of the three channels sit on my bounds, so the identical spend moves across models come from the bounds, not from agreement between models. The four D tops are also cluster tops from one search, so they are not independent evidence.
10. **Residuals still climb at high fitted values** in A and D, so sales peaks are under-predicted. The discount hinge did not fix that.
****

**Limitations**
- Robyn defaults were used for everything not listed above.
- No information on the industry of this data to add further flags and information to the model.
- Checked only with two seeds.
- I have hypotheses for the under-attribution (noisy price and promotion variables, ridge shrinkage, the DECOMP.RSSD pull, incomplete convergence) but have not tested them.
- The allocator works on each channel's average weekly spend, so it cannot see TV flighting. At the plan's levels PLA averages 98.6 a week, above its 75th percentile week (91), so part of the plan extrapolates.
- ROAS in this README is the model's average ROAS, not a measured incremental ROAS.

**Next steps**
Before EDA:
- Compare with a plain ridge regression on the same adstocked inputs.
- A labelled diagnostic run with narrowed theta ranges, to see whether Robyn can recover the effects when helped.

After EDA: 
- Run more variants based on out learning from EDA
  - Variant A: replace raw price with the discount hinge.
  - Variant B: A, plus PLA and Meta combined into one digital variable.
  - Variant C: B, plus Weibull adstock for digital, to allow a delayed peak.
  - A variant without the trend term.
  - A log-log model in Meridian or PyMC-Marketing.
- Budget allocation on the fitted response curves.

Steps if I have to keep continuing this or in a real scenario:  
- Calibration with a lift test. A real test is best. A simulated one must be built independently of the ground truth.
- Run Variant B (PLA and Meta combined into one digital variable) and Variant C (Weibull adstock for digital, to allow a delayed peak).
- A log-log model in Meridian or PyMC-Marketing.

**Credits and licence**
Data design from arXiv 2608.21130 (paper licensed CC BY 4.0; check the generator repository for its code licence). 
Model: Robyn (Meta).
