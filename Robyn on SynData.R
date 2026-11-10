library(Robyn)
remotes::install_github("facebookexperimental/Robyn/R")
library(dplyr)

################################################################
#### Step 1: Load data
sdf <- read.csv("C:/Users/sruth/Documents/Focus/Projects-Practise/MMM/Robyn/synthetic_mmm_data.csv")
View(sdf)
colnames(sdf)
head(sdf)
#### Including holiday list from prophet

data("dt_prophet_holidays")
head(dt_prophet_holidays)

### 
### STEP 2: Prepare the data for loading it into Robyn as input 

# Year is coded 1, 2, 3; map to 2022, 2023, 2024
sdf$year <- sdf$year + 2021

# First week of the data, as the Monday of ISO week `week_of_year[1]` in that year
jan4 <- as.Date(paste0(sdf$year[1], "-01-04"))
wk1_monday <- jan4 - (as.integer(format(jan4, "%u")) - 1)
start <- wk1_monday + 7 * (sdf$week_of_year[1] - 1)
sdf$date <- start + 7 * (seq_len(nrow(sdf)) - 1)   # rows must be in order, one per week

# Checks
stopifnot(!anyDuplicated(sdf$date), all(diff(sdf$date) == 7))
stopifnot(all(as.integer(format(sdf$date, "%Y")) == sdf$year | sdf$week_of_year %in% c(1, 52, 53)))
all(as.integer(format(sdf$date, "%V")) == sdf$week_of_year)   # should print TRUE
range(sdf$date)  

# Keeping only the acceptable fields for the model:

stopifnot(!anyDuplicated(df$date), all(diff(df$date) == 7))

# Model data: practitioner's information set only
dt_model <- sdf %>%
  transmute(
    date,
    total_sales,
    pla_spend, meta_spend, tv_spend,
    observed_promotion_dummy = as.factor(observed_promotion_dummy),
    observed_promotional_price_level
  )

# Answer key, kept apart
dt_truth <- sdf %>% select(date, total_sales, pla_effect, meta_effect, tv_effect)

#### Step 2 Continued : give inputs to the model
InputCollect <- robyn_inputs(
  dt_input = dt_model,
  dt_holidays = dt_prophet_holidays,
  date_var = "date",
  dep_var = "total_sales",
  dep_var_type = "revenue",
  prophet_vars = c("trend", "season"),
  prophet_country = "DE",            # only used for holidays; not in prophet_vars, so it has no effect here
  context_vars = c("observed_promotion_dummy", "observed_promotional_price_level"),
  paid_media_spends = c("pla_spend", "meta_spend", "tv_spend"),
  paid_media_vars   = c("pla_spend", "meta_spend", "tv_spend"),  # no impressions in the data, so same as spends
  factor_vars = "observed_promotion_dummy",
  adstock = "geometric"
)


#### STEP 3: Setting Hyper Parameters

hyperparameters <- list(
  pla_spend_alphas  = c(0.5, 3),  pla_spend_gammas  = c(0.3, 1), pla_spend_thetas  = c(0, 0.3),
  meta_spend_alphas = c(0.5, 3),  meta_spend_gammas = c(0.3, 1), meta_spend_thetas = c(0, 0.3),
  tv_spend_alphas   = c(0.5, 3),  tv_spend_gammas   = c(0.3, 1), tv_spend_thetas   = c(0.3, 0.8),
  train_size = c(0.5, 0.8)
)
InputCollect <- robyn_inputs(InputCollect = InputCollect, hyperparameters = hyperparameters)


#### STEP 4: RUN MODEL

OutputModels <- robyn_run(
  InputCollect = InputCollect,
  iterations = 2000, trials = 5,
  ts_validation = TRUE,
  cores = parallel::detectCores() - 1
)

OutputCollect <- robyn_outputs(
  InputCollect, OutputModels,
  pareto_fronts = "auto", clusters = TRUE,
  csv_out = "pareto", export = TRUE,
  plot_folder = "robyn_out", plot_pareto = TRUE
)

OutputCollect

tr <- sdf[sdf$date >= min(dt_model$date), ]
true_roi <- colSums(tr[, c("pla_effect","meta_effect","tv_effect")]) / colSums(tr[, c("pla_spend","meta_spend","tv_spend")])
true_share <- colSums(tr[, c("pla_effect","meta_effect","tv_effect")]) / sum(tr$total_sales)
rbind(true_roi, true_share)


OutputModels2 <- robyn_run(
  InputCollect = InputCollect,
  iterations = 4000, trials = 5,
  ts_validation = TRUE,
  cores = parallel::detectCores() - 1
)

OutputCollect2 <- robyn_outputs(
  InputCollect, OutputModels2,
  pareto_fronts = "auto", clusters = TRUE,
  csv_out = "pareto", export = TRUE,
  plot_folder = "robyn_out_4000", plot_pareto = TRUE
)
