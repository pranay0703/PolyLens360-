# Install required packages: install.packages(c("rugarch","rvinecopulib","jsonlite"))
library(rugarch)
library(rvinecopulib)
library(jsonlite)

# Load historical returns from CSV
returns <- read.csv("historical_returns.csv", header = TRUE, row.names = 1)
assets <- colnames(returns)

# Fit univariate GARCH(1,1) for each asset
garch_fits <- lapply(assets, function(a) {
  spec <- ugarchspec(mean.model = list(armaOrder = c(0, 0)),
                     variance.model = list(model = "sGARCH", garchOrder = c(1, 1)))
  ugarchfit(spec, returns[[a]])
})

# Extract standardized residuals
std_resids <- sapply(garch_fits, function(fit) {
  residuals(fit, standardize = TRUE)
})

# Fit vine copula on residuals
vine_fit  <- vinecop(std_resids)

# Save parameters to JSON
params <- list()
for (i in seq_along(garch_fits)) {
  coef_vals <- coef(garch_fits[[i]])
  params[[assets[i]]] <- list(
    mu    = coef_vals["mu"],
    omega = coef_vals["omega"],
    alpha = coef_vals["alpha1"],
    beta  = coef_vals["beta1"]
  )
}
params[["vine_structure"]] <- vine_fit$structure
write_json(params, "garch_vine_params.json")

print("Finished fitting GARCH + Vine Copula.")
