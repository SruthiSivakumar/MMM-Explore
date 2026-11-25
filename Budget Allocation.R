# Picking the one model with the least NMRSE of the Variants A, A2 and D2
# Model chosen by the rule written before looking at the truth:
# lowest validation NRMSE among cluster tops (2_284_2, val NRMSE 0.0869, lowest across A, A2 and D).
chosen <- "2_284_2"
others <- c("1_252_7", "5_265_3", "5_269_7")   # the other D cluster tops, for a stability check

out_dir_al <- file.path(getwd(), "allocation"); dir.create(out_dir, showWarnings = FALSE)

# Bounds are multipliers on each channel's current spend in the window.
# 0.7 to 1.3 keeps spend near what the model saw.
lo <- c(0.7, 0.7, 0.7)
hi <- c(1.3, 1.3, 1.3)

run_alloc <- function(model, scenario = "max_response") {
  robyn_allocator(
    InputCollect = InputCollectD,
    OutputCollect = OutputCollectD,
    select_model = model,
    scenario = scenario,                       # same total budget, best split
    channel_constr_low = lo,
    channel_constr_up = hi,
    date_range = "all",
    export = TRUE,
    quiet = TRUE
  )
}

# 1. The chosen model
A <- run_alloc(chosen)
cols <- c("channels", "initSpendUnit", "optmSpendUnit", "initResponseUnit", "optmResponseUnit")
print(A$dt_optimOut[, intersect(cols, names(A$dt_optimOut))])

# 2. Stability check: does each channel move in the same direction in the other tops?
moves <- do.call(rbind, lapply(c(chosen, others), function(m) {
  x <- run_alloc(m)$dt_optimOut
  data.frame(model = m, channel = x$channels,
             spend_change_pct = round(100 * (x$optmSpendUnit / x$initSpendUnit - 1), 1),
             response_change_pct = round(100 * (sum(x$optmResponseUnit) / sum(x$initResponseUnit) - 1), 2))
}))
print(moves, row.names = FALSE)
# Read it this way: if a channel gains budget in every model, the direction is usable.
# If it flips sign between models, report it as undecided.

### Re RUN on VAriant D

# 1. Per channel table for one model: spend, response and ROAS before and after.
# Spend and response are weekly averages over the window. ROAS here is response / spend on the
# allocator's own curve, so it can differ a little from the roi_total in pareto_aggregated.csv.
channel_table <- function(model) {
  x <- run_alloc(model)$dt_optimOut
  data.frame(
    model = model, channel = x$channels,
    spend_now = round(x$initSpendUnit, 1), spend_new = round(x$optmSpendUnit, 1),
    spend_change_pct = round(100 * (x$optmSpendUnit / x$initSpendUnit - 1), 1),
    roas_now = round(x$initResponseUnit / x$initSpendUnit, 2),
    roas_new = round(x$optmResponseUnit / x$optmSpendUnit, 2)
  )
}
print(channel_table(chosen), row.names = FALSE)

# 2. One row per model and channel, plus the total gain once per model (not repeated per channel).
all_models <- c(chosen, others)
moves <- do.call(rbind, lapply(all_models, channel_table))
print(moves, row.names = FALSE)

totals <- do.call(rbind, lapply(all_models, function(m) {
  x <- run_alloc(m)$dt_optimOut
  data.frame(model = m,
             total_roas_now = round(sum(x$initResponseUnit) / sum(x$initSpendUnit), 2),
             total_roas_new = round(sum(x$optmResponseUnit) / sum(x$optmSpendUnit), 2),
             total_response_gain_pct = round(100 * (sum(x$optmResponseUnit) / sum(x$initResponseUnit) - 1), 1))
}))
print(totals, row.names = FALSE)
# Read it this way: if a channel gains budget in every model, the direction is usable.
# If it flips sign between models, report it as undecided.
# A channel sitting exactly at 30 or -30 is pinned to a bound, so the size of the move is set by the bound.

# 3. Dollar split for a budget of your choice, using the spend shares of the chosen model.
budget <- 1e6
a <- run_alloc(chosen)$dt_optimOut
print(data.frame(channel = a$channels,
                 now = round(budget * a$initSpendUnit / sum(a$initSpendUnit), -3),
                 plan = round(budget * a$optmSpendUnit / sum(a$optmSpendUnit), -3)), row.names = FALSE)
