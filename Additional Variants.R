

# ---- 1. Variant A data ------------------------------------------------------
cutoff <- 0.9   # chosen after looking at sales;
dt_modelA <- dt_model
dt_modelA$discount_depth <- pmax(0, cutoff - dt_modelA$observed_promotional_price_level)
dt_modelA$observed_promotional_price_level <- NULL   # raw price is out
summary(dt_modelA$discount_depth)
cat("Weeks with a discount:", sum(dt_modelA$discount_depth > 0), "of", nrow(dt_modelA), "\n")
plot(dt_modelA$discount_depth, dt_modelA$total_sales, pch = 16,
     xlab = "discount depth", ylab = "total sales")   # expect sales to rise as the discount deepens

# ---- 2. Inputs --------------------------------------------------------------
InputCollectA <- robyn_inputs(
  dt_input = dt_modelA,
  date_var = "date",
  dep_var = "total_sales",
  dep_var_type = "revenue",
  prophet_vars = c("trend", "season"),
  context_vars = c("observed_promotion_dummy", "discount_depth"),   # no sign constraints: one change at a time
  paid_media_spends = c("pla_spend", "meta_spend", "tv_spend"),
  paid_media_vars   = c("pla_spend", "meta_spend", "tv_spend"),
  factor_vars = "observed_promotion_dummy",
  adstock = "geometric",
  hyperparameters = hyperparameters
)


# ---- 3. Run: 2,000 iterations x 5 trials, same seed as before ---------------
# robyn_run's default seed is 123. If you passed a different seed earlier, use that one here.
OutputModelsA <- robyn_run(
  InputCollect = InputCollectA,
  iterations = 2000,
  trials = 5,
  ts_validation = TRUE
)

out_dir <- "variantA"; dir.create(out_dir, showWarnings = FALSE)
OutputCollectA <- robyn_outputs(
  InputCollectA, OutputModelsA,
  pareto_fronts = "auto", clusters = TRUE,
  plot_folder = file.path(getwd(), out_dir), plot_pareto = TRUE, export = TRUE
)


# ---- 4. Scorecard, no ground truth: run it on each run's folder -------------
# Point it at the folder that holds pareto_aggregated.csv.
scorecard <- function(folder, label) {
  a <- read.csv(file.path(folder, "pareto_aggregated.csv"))
  media <- a[a$rn %in% c("pla_spend", "meta_spend", "tv_spend", "digital_spend"), ]
  cat("\n==", label, "==\n")
  cat("Pareto models:", length(unique(media$solID)), "\n")
  cat("Models where each channel's coefficient is exactly zero:\n")
  print(tapply(media$coef == 0, media$rn, sum))
  tops <- unique(media$solID[which(media$top_sol)])
  out <- do.call(rbind, lapply(tops, function(s) {
    x <- media[media$solID == s, ]
    data.frame(solID = s, nrmse_val = round(x$nrmse_val[1], 4), decomp_rssd = round(x$decomp.rssd[1], 3),
               media_share = round(sum(x$xDecompPerc), 3),
               roas = paste(paste0(x$rn, "=", round(x$roi_total, 2)), collapse = "; "))
  }))
  print(out, row.names = FALSE)
}
scorecard(file.path(getwd(), "Robyn_202611060805_init"), "Run 2 (raw price, 4,000 iterations)")
scorecard(file.path(getwd(), out_dir, "Robyn_202611211536_init"), "Variant A")


#------------ Variant d - without the trend --------------#########

dt_modelD <- dt_modelA
InputCollectD <- robyn_inputs(
  dt_input = dt_modelD,
  date_var = "date",
  dep_var = "total_sales",
  dep_var_type = "revenue",
  prophet_vars = "season",                                   # was c("trend", "season")
  context_vars = c("observed_promotion_dummy", "discount_depth"),
  paid_media_spends = c("pla_spend", "meta_spend", "tv_spend"),
  paid_media_vars   = c("pla_spend", "meta_spend", "tv_spend"),
  factor_vars = "observed_promotion_dummy",
  adstock = "geometric",
  hyperparameters = hyperparameters
)


# ---- 4. Run: same iterations, trials and seed as Variant A ------------------
OutputModelsD <- robyn_run(
  InputCollect = InputCollectD,
  iterations = 2000,
  trials = 5,
  ts_validation = TRUE
)

out_dir <- "variantD"; dir.create(out_dir, showWarnings = FALSE)
OutputCollectD <- robyn_outputs(
  InputCollectD, OutputModelsD,
  pareto_fronts = "auto", clusters = TRUE,
  plot_folder = file.path(getwd(), out_dir), plot_pareto = TRUE, export = TRUE
)

scorecard(file.path(getwd(), out_dir, "Robyn_202611211643_init"), "Variant D")


###----------------------------------------------------- with  adifferent seed

# ---- 5. Run: 2,000 iterations x 5 trials, different seed as before ---------------
# robyn_run's default seed is 123. If you passed a different seed earlier, use that one here.
OutputModelsA2 <- robyn_run(
  InputCollect = InputCollectA,
  iterations = 2000,
  trials = 5,
  ts_validation = TRUE,
  seed = 666
)

 out_dir <- "variantA2"; dir.create(out_dir, showWarnings = FALSE)
OutputCollectA <- robyn_outputs(
  InputCollectA, OutputModelsA2,
  pareto_fronts = "auto", clusters = TRUE,
  plot_folder = file.path(getwd(), out_dir), plot_pareto = TRUE, export = TRUE
)

scorecard(file.path(getwd(), "variantA2", "Robyn_202611231138_init"), "Variant A2")

OutputModelsD2 <- robyn_run(
  InputCollect = InputCollectD,
  iterations = 2000,
  trials = 5,
  ts_validation = TRUE,
  seed = 666
)

out_dir <- "variantD2"; dir.create(out_dir, showWarnings = FALSE)
OutputCollectD <- robyn_outputs(
  InputCollectD, OutputModelsD,
  pareto_fronts = "auto", clusters = TRUE,
  plot_folder = file.path(getwd(), out_dir), plot_pareto = TRUE, export = TRUE
)

scorecard(file.path(getwd(), out_dir, "Robyn_202611231429_init"), "Variant D2")
