# Exploring and Practicing MMM - Robyn

## Marketing mix modelling with Robyn on a synthetic benchmark with known ground truth

#### Question

Robyn reports channel ROI with a clean set of plots, but in real work nobody can check those numbers. This project runs Robyn on synthetic data where the true channel effects are known, and asks: when Robyn fits the sales well, does it also get the channel ROI right?

#### Data
Synthetic weekly retail benchmark, 156 weeks, three media channels (PLA, Meta, TV), from the paper A Synthetic Benchmark Dataset with Endogenous Marketing Spend for Validating Marketing Mix Models (arXiv 2608.21130). 
Generator code: [add repository link].

The generator also records each week's true per-channel effect. I removed those columns before modelling and used them only to score the results.

**Model inputs:** total_sales, pla_spend, meta_spend, tv_spend, observed_promotion_dummy, observed_promotional_price_level. 
The two promotion variables carry measurement error by design. Spend is endogenous by design.
The year column was coded 1 to 3. 
I relabelled it 2022 to 2024 so the weekly dates line up with the ISO calendar.

**Method**
Robyn v3.12.1, R 4.6.1. Geometric adstock, Hill saturation, Prophet trend and season.
Time-series validation on, with the training share searched between 50% and 80%. 
5 trials of 2,000 iterations each. No calibration data.

**Hyperparameter ranges**: Used Robyn Recommended Ranges. Random seed: [42].

Model selection rules, written before I opened the ground truth: drop models with an implausible story (for example a channel with zero effect), then take the lowest validation NRMSE among the cluster-top models.

**Results**

Robyn returned 113 Pareto models in 3 clusters. One top model per cluster, against the truth:

PLA ROAS	Meta ROAS	TV ROAS	Total ROAS	Media share of sales
Truth	4.20	2.90	1.56	3.30	18.7%
2_268_5 (cluster 1)	0.63	0.66	0.56	0.63	about 3.7%
1_161_1 (cluster 3)	0.27	0.29	0.27	0.27	about 1.6%
1_199_7 (cluster 2)	0.15	0	0.22	0.11	about 0.6%

**First Observations**
--> Adjusted R² on the training weeks was 0.82 to 0.84 for the three models, yet they credited media with 1 to 4% of sales against a true 18.7%. This proves that a good fit may not mean correct attribution. So we continue our feature engineering. 
--> The selection score pulled toward equal ROAS. DECOMP.RSSD rewards models whose effect shares match their spend shares. Clusters 1 and 3 have DECOMP.RSSD near 0.02 and give nearly equal ROAS to every channel, while the true order is PLA, then Meta, then TV.
--> The reported intervals for cluster 1 were: [0.25, 1.64] for PLA and [0.17, 1.67] for Meta, against true values of 4.20 and 2.90.
--> As per a blind rule selection, it chose 1_161_1, but 2_268_5 was closer to the truth on ROAS level and effect split. Both were far off, and the model with the lowest validation error (1_199_7) was the worst on channel ranking.
The search was not fully converged. Trials 3 to 5 were still improving at 2,000 iterations.

**Limitations**
I have hypotheses for the under-attribution (noisy price and promotion variables, ridge shrinkage, the DECOMP.RSSD pull, incomplete convergence) but have not tested them yet.
Robyn defaults were used for everything not listed above.
Used a single seed for the runs

**Next steps**
Rerun with more iterations and several seeds.
Compare with a plain ridge regression on the same adstocked inputs.
A labelled diagnostic run with narrowed theta ranges, to see whether Robyn can recover the effects when helped.
Fit the same data with Meridian or PyMC-Marketing.
Budget allocation on the fitted response curves, and calibration with experiment results.

**Credits and licence**
Data design from arXiv 2608.21130 (paper licensed CC BY 4.0; check the generator repository for its code licence). 
Model: Robyn (Meta).
