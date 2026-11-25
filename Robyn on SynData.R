library(Robyn)
remotes::install_github("facebookexperimental/Robyn/R")
library(dplyr)
setwd("C:/Users/sruth/Documents/Focus/Projects-Practise/MMM/Robyn")

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

#COnstructing Date field from the year and week information  
# First week of the data, as the Monday of ISO week `week_of_year[1]` in that year
jan4 <- as.Date(paste0(sdf$year[1], "-01-04"))
wk1_monday <- jan4 - (as.integer(format(jan4, "%u")) - 1)
start <- wk1_monday + 7 * (sdf$week_of_year[1] - 1)
sdf$date <- start + 7 * (seq_len(nrow(sdf)) - 1)   # rows must be in order, one per week
range(sdf$date) 

# Checks
stopifnot(!anyDuplicated(sdf$date), all(diff(sdf$date) == 7))
stopifnot(all(as.integer(format(sdf$date, "%Y")) == sdf$year | sdf$week_of_year %in% c(1, 52, 53)))
all(as.integer(format(sdf$date, "%V")) == sdf$week_of_year)   # should print TRUE
range(sdf$date)  

# Keeping only the acceptable fields for the model:
stopifnot(!anyDuplicated(sdf$date), all(diff(sdf$date) == 7))

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

##################################################################################
###################### Exploratory Data Analysis #################################
##################################################################################
d <- data.frame(
  date  = as.Date(dt_model$date),
  sales = dt_model$total_sales,
  pla   = dt_model$pla_spend,
  meta  = dt_model$meta_spend,
  tv    = dt_model$tv_spend,
  promo = as.numeric(as.character(dt_model$observed_promotion_dummy)),
  price = dt_model$observed_promotional_price_level
)

head(d)
d$yr <- as.integer(format(d$date, "%Y"))
d$mo <- as.integer(format(d$date, "%m"))
d$wk <- as.integer(format(d$date, "%V"))

skew <- function(x) mean((x - mean(x))^3) / sd(x)^3 * (n - 1)^1.5 / n^1.5

# Checking if data for all weeks
nrow(d)
format(min(d$date))
format(max(d$date))

# 1. DISTRIBUTIONS: histogram with density and the median marked
par(mfrow = c(2, 3))
for (v in vars) hist(d[[v]], breaks = 30, main = v, xlab = "", col = "grey80")

#Tv is the most random and its set up only in the last 2 years

## 2. Outliers
par(mfrow = c(1, 5))
for (v in vars) boxplot(d[[v]], main = v, col = "grey90", outcol = "red", pch = 16)

# Flags: outside 1.5 x IQR (same rule as the boxplot), and z-scores
flag_iqr <- function(x) {
  q <- quantile(x, c(.25, .75)); i <- diff(q)
  x < q[1] - 1.5 * i | x > q[2] + 1.5 * i
}
flags <- sapply(d[vars], flag_iqr)                         # TRUE/FALSE by week and variable
z     <- sapply(d[vars], function(x) (x - mean(x)) / sd(x))

# a. Long list: one row per flagged value, in date order
out <- do.call(rbind, lapply(vars, function(v) {
  i <- which(flags[, v])
  if (length(i) == 0) return(NULL)
  data.frame(date = d$date[i], variable = v, value = round(d[[v]][i], 1),
             z = round(z[i, v], 2), beyond_3sd = abs(z[i, v]) > 3)
}))
out <- out[order(out$date, out$variable), ]
print(out, row.names = FALSE)

# b. Full row for every flagged week, with how many variables flagged that week
d$n_flags <- rowSums(flags)
show <- cbind(date = d$date, round(d[vars], 1), n_flags = d$n_flags)
print(show[d$n_flags >= 1, ], row.names = FALSE)

# c. Only weeks where two or more variables flag together (the event weeks)
print(show[d$n_flags >= 2, ], row.names = FALSE)

# d. Save to a file for the README or to send to a client
write.csv(out, "flagged_weeks.csv", row.names = FALSE)



# 3. TREND (red line = linear fit)
par(mfrow = c(5, 1), mar = c(2, 4, 2, 1))
for (v in vars) {
  plot(d$date, d[[v]], type = "l", main = v, xlab = "", ylab = "", col = "grey40")
  abline(lm(d[[v]] ~ as.numeric(d$date)), col = "red", lwd = 2)
}

# 4. SEASONALITY: sales by week of year, one line per year
par(mfrow = c(1, 1), mar = c(4, 4, 3, 1))
m <- tapply(d$sales, list(d$wk, d$yr), sum)
matplot(as.integer(rownames(m)), m, type = "l", lty = 1, lwd = 2,
        xlab = "ISO week", ylab = "Sales", main = "Sales by week of year")
legend("topright", legend = colnames(m), col = 1:ncol(m), lty = 1, lwd = 2, bty = "n")

par(mfrow = c(1, 1))  # reset



## lets do some sophisticated plots 
library(ggplot2)
library(tidyr)
library(tidyverse)
vars <- c("sales", "pla", "meta", "tv", "price")


long <- d %>% select(date, yr, wk, mo, all_of(vars)) %>%
  pivot_longer(all_of(vars), names_to = "variable", values_to = "value") %>%
  mutate(variable = factor(variable, levels = vars))
th <- theme_minimal(base_size = 12)

# 1. DISTRIBUTIONS: histogram with density and the median marked
meds <- long %>% group_by(variable) %>% summarise(med = median(value))
p1 <- ggplot(long, aes(value)) +
  geom_histogram(aes(y = after_stat(density)), bins = 30, fill = "grey75", colour = "white") +
  geom_density(colour = "#1f77b4", linewidth = 0.9) +
  geom_vline(data = meds, aes(xintercept = med), linetype = "dashed", colour = "firebrick") +
  facet_wrap(~variable, scales = "free", ncol = 3) +
  labs(title = "Distributions", subtitle = "Dashed line = median. Long right tails mean a few very large weeks",
       x = NULL, y = "Density") + th
ggsave("eda_1_distributions.png", p1, width = 12, height = 7, dpi = 130)

# 2. OUTLIERS: boxplots of standardised values, and flagged weeks on the time axis
flag <- long %>% group_by(variable) %>%
  mutate(z = (value - mean(value)) / sd(value),
         q1 = quantile(value, .25), q3 = quantile(value, .75),
         out_iqr = value < q1 - 1.5 * (q3 - q1) | value > q3 + 1.5 * (q3 - q1)) %>% ungroup()
p2a <- ggplot(flag, aes(variable, z)) +
  geom_boxplot(outlier.colour = "firebrick", fill = "grey90") +
  geom_hline(yintercept = c(-3, 3), linetype = "dotted") +
  labs(title = "Outliers by variable (z-score)", subtitle = "Red points sit outside 1.5 x IQR. Dotted lines mark |z| = 3",
       x = NULL, y = "z-score") + th
p2b <- ggplot(flag, aes(date, value)) +
  geom_line(colour = "grey50") +
  geom_point(data = filter(flag, out_iqr), colour = "firebrick", size = 1.8) +
  facet_wrap(~variable, scales = "free_y", ncol = 1) +
  labs(title = "Where the outlier weeks fall", subtitle = "Red = outside 1.5 x IQR. Check whether they repeat on the same dates each year",
       x = NULL, y = NULL) + th
ggsave("eda_2a_outlier_boxplots.png", p2a, width = 9, height = 5.5, dpi = 130)
ggsave("eda_2b_outlier_weeks.png", p2b, width = 11, height = 10, dpi = 130)


# 3. TREND: series with linear and loess fits, plus yearly totals
p3a <- ggplot(long, aes(date, value)) +
  geom_line(colour = "grey60") +
  geom_smooth(method = "loess", span = 0.6, se = FALSE, colour = "#1f77b4") +
  geom_smooth(method = "lm", se = FALSE, colour = "firebrick", linetype = "dashed") +
  facet_wrap(~variable, scales = "free_y", ncol = 1) +
  labs(title = "Trend", subtitle = "Blue = loess, red dashed = linear fit", x = NULL, y = NULL) + th
yearly <- long %>% group_by(variable, yr) %>% summarise(total = sum(value), .groups = "drop") %>%
  filter(variable != "price")
p3b <- ggplot(yearly, aes(factor(yr), total, fill = factor(yr))) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~variable, scales = "free_y", ncol = 4) +
  labs(title = "Yearly totals", x = NULL, y = NULL) + th
ggsave("eda_3a_trend.png", p3a, width = 11, height = 10, dpi = 130)
ggsave("eda_3b_yearly_totals.png", p3b, width = 11, height = 3.5, dpi = 130)

# 4. SEASONALITY
# 4a. Same weeks laid over each other, one line per year
p4a <- ggplot(filter(long, variable != "price"), aes(wk, value, colour = factor(yr))) +
  geom_line() +
  facet_wrap(~variable, scales = "free_y", ncol = 2) +
  labs(title = "Week of year, one line per year", subtitle = "Lines that overlap mean a fixed calendar pattern",
       x = "ISO week", y = NULL, colour = NULL) + th

# 4b. Month by year heatmap of mean sales
hm <- d %>% group_by(yr, mo) %>% summarise(sales = mean(sales), .groups = "drop")
p4b <- ggplot(hm, aes(factor(mo), factor(yr), fill = sales)) +
  geom_tile(colour = "white") +
  geom_text(aes(label = round(sales)), size = 3) +
  scale_fill_gradient(low = "white", high = "firebrick") +
  labs(title = "Mean weekly sales by month and year", x = "Month", y = NULL) + th

# 4c. Spend and sales by month, indexed to each series' own average
idx <- d %>% group_by(mo) %>% summarise(across(c(sales, pla, meta, tv), mean), .groups = "drop") %>%
  mutate(across(c(sales, pla, meta, tv), ~ .x / mean(.x) * 100)) %>%
  pivot_longer(-mo, names_to = "series", values_to = "index")
p4c <- ggplot(idx, aes(mo, index, colour = series)) +
  geom_line(linewidth = 1) + geom_hline(yintercept = 100, linetype = "dotted") +
  scale_x_continuous(breaks = 1:12) +
  labs(title = "Monthly profile (100 = average month)",
       subtitle = "Spend that peaks with sales is planned around the season", x = "Month", y = "Index", colour = NULL) + th
ggsave("eda_4a_week_of_year.png", p4a, width = 11, height = 6, dpi = 130)
ggsave("eda_4b_month_year_heatmap.png", p4b, width = 9, height = 3.5, dpi = 130)
ggsave("eda_4c_monthly_profile.png", p4c, width = 9, height = 5, dpi = 130)

# 4d. Trend / season / remainder split of sales (stl needs the weekly frequency set to 52)
fit_4d <- stl(ts(d$sales, frequency = 52), s.window = "periodic")
png("eda_4d_stl_sales.png", width = 1200, height = 900, res = 120)
plot(fit_4d, main = "Sales: trend, season and remainder (STL)")

dev.off()

#####################################################################################
############### Perfoming some checks on assumptions ################################

n <- nrow(d)
d$trend <- seq_len(n)
d$disc  <- pmax(0, 0.9 - d$price)            # discount hinge; 0.9 chosen by looking at sales
for (k in 1:4) {                              # smooth yearly season: 4 sine/cosine pairs
  d[[paste0("s", k)]] <- sin(2 * pi * k * d$wk / 52)
  d[[paste0("c", k)]] <- cos(2 * pi * k * d$wk / 52)
}
season <- c(paste0("s", 1:4), paste0("c", 1:4))
xv <- c("pla", "meta", "tv", "promo", "disc", "trend", season)

# 1. CORRELATIONS
print(round(cor(d[c("sales", "pla", "meta", "tv", "promo", "price")]), 2))
pairs(d[c("sales", "pla", "meta", "tv", "price")], lower.panel = NULL, pch = 16, cex = .5)

# Adstocked spend (theta 0.3 for digital, 0.5 for TV), for a closer look at PLA vs Meta
adstock <- function(x, th) {
  o <- numeric(length(x)); 
  for (i in seq_along(x)) 
    o[i] <- x[i] + if (i > 1) th * o[i - 1] else 0;
  o }
cat("PLA vs Meta correlation, adstocked:", round(cor(adstock(d$pla, .3), adstock(d$meta, .3)), 2), "\n")


# 2. MULTICOLLINEARITY
# VIF = 1 / (1 - R2) from regressing each variable on all the others.
# Rule of thumb: above 5 is a concern, above 10 is severe.
vif <- sapply(xv, function(v) 1 / (1 - summary(lm(reformulate(setdiff(xv, v), v), d))$r.squared))
print(round(vif, 1))
cat("Share of each channel's variance that nothing else explains (1/VIF):\n")
print(round(1 / vif[c("pla", "meta", "tv")], 2))
cat("R2 of season terms alone predicting each channel:\n")
print(round(sapply(c("pla", "meta", "tv"), function(v) summary(lm(reformulate(season, v), d))$r.squared), 2))


#####################################################################################
#####################################################################################

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


####################### Feature engineering #####################################3
# Continuing from the EDA, and the above models, we learnt that most models leave Meta at 0 and
# PLA and META seems to be somewhat correlated. However its not big enough to frame as multicollinear. 
# Now lets do a baseline regression to understand whats going on with these variables to coonfirm/conclude

# 3. BASELINE REGRESSION AND ASSUMPTIONS
fit <- lm(reformulate(xv, "sales"), d)
print(round(summary(fit)$coefficients[c("pla", "meta", "tv", "promo", "disc", "trend"), ], 3))
cat("R2:", round(summary(fit)$r.squared, 3), "\n")   # in-sample, so optimistic
res <- resid(fit)

# notice that the meta's estimate is negative, which explains why Robyn curtailed it at 0. 
cat("\nIndependence of errors\n")
cat("Durbin-Watson:", round(sum(diff(res)^2) / sum(res^2), 2), "(2 = none; below 1.5 = positive autocorrelation)\n")
print(Box.test(res, lag = 4, type = "Ljung-Box"))

cat("\nConstant error spread (Breusch-Pagan, by hand)\n")
bp <- n * summary(lm(res^2 ~ fitted(fit)))$r.squared
cat("p =", round(pchisq(bp, 1, lower.tail = FALSE), 4), "\n")
q <- cut(fitted(fit), quantile(fitted(fit), 0:3 / 3), include.lowest = TRUE, labels = c("low", "mid", "high"))
print(round(tapply(res, q, sd)))                      # residual SD by fitted tercile

cat("\nStraight-line shape (RESET, by hand)\n")
fit2 <- update(fit, . ~ . + I(fitted(fit)^2))
print(anova(fit, fit2)[2, "Pr(>F)"])

cat("\nNormality of errors\n")
print(shapiro.test(res))

cat("\nInfluential weeks (Cook's distance)\n")
cd <- cooks.distance(fit)
cat("Weeks above 4/n:", sum(cd > 4 / n), "| largest:", round(max(cd), 3), "\n")
print(round(head(sort(cd, decreasing = TRUE), 5), 3)); print(d$date[order(-cd)][1:5])

cat("\nStability: media coefficients in each half of the data\n")
h <- n %/% 2
for (idx in list(1:h, (h + 1):n))
  print(round(coef(lm(reformulate(xv, "sales"), d[idx, ]))[c("pla", "meta", "tv")], 1))

# 4. DIAGNOSTIC PLOTS: residuals vs fitted, QQ, scale-location, Cook's distance
par(mfrow = c(2, 2)); 
plot(fit, which = c(1, 2, 3, 4)); 
par(mfrow = c(1, 1))
acf(res, main = "Residual autocorrelation")           # bars outside the blue lines = leftover time structure
