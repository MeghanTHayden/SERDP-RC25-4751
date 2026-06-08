# Load the PEcAn.all package, which includes all necessary PEcAn functionality
library("PEcAn.all")

# Create the output directory if it doesnt already exist
demo_outdir <- file.path("demo_outdir")
if (!dir.exists(demo_outdir)) {
    # using if(!dir.exists) instead of `showWarnings = FALSE`
    # to allow warnings like 'cannot create dir ...'
    dir.create(demo_outdir,
        recursive = TRUE
    )
}

## Load the settings file

# Define settings file to use, called "pecan.xml"
#settings_path <- here::here("pecan.xml")
settings_path <- here::here("pecan_slurm.xml")

# Read the settings from the pecan.xml file
settings <- PEcAn.settings::read.settings(settings_path)

# Prepare and validate the settings
settings <- PEcAn.settings::prepare.settings(settings)

# Add settings info
settings$info <- list(
  author = "serdp",
  date = Sys.Date(),
  description = "Demo run of PEcAn using SIPNET"
)

## Run Model Simulations

# Create model configs in the run folder
settings <- PEcAn.workflow::runModule.run.write.configs(settings)

# Launch the SIPNET model for the single run configuration created in the previous step
PEcAn.workflow::runModule_start_model_runs(settings)

## Fetch Model Outputs

# Gather up the model output metadata
runid <- as.character(read.table(paste(settings$outdir, "/run/", "runs.txt", sep = ""))[1, 1])
outdir <- file.path(settings$outdir, "/out/", runid)
start.year <- lubridate::year(settings$run$start.date)
end.year <- lubridate::year(settings$run$end.date)
model_output <- PEcAn.utils::read.output(
  runid,
  outdir,
  start.year,
  end.year,
  variables = NULL,
  dataframe = TRUE,
  verbose = FALSE
)
available_vars <- names(model_output)[!names(model_output) %in% c("posix", "time_bounds")]

# Display Available Model Variables
vars_df <- PEcAn.utils::standard_vars |>
  dplyr::select(
    Variable = Variable.Name,
    Description = Long.name
  ) |>
  dplyr::filter(Variable %in% available_vars) |>
  # TODO: add year to PEcAn.utils::standard vars
  dplyr::bind_rows(
    dplyr::tibble(
      Variable = "year",
      Description = "Year"
    )
  )

vars_df$Description[is.na(vars_df$Description)] <- "(No description available)"
knitr::kable(vars_df, caption = "Model Output Variables and Descriptions")

## Ensemble and Sensitivity Analysis
## Debug: Check ensemble.id and related settings
# Manually assign ensemble.id to top level if needed
if (!exists("ensemble.id", where=settings)) {
  settings$ensemble.id <- settings$ensemble$ensemble.id
}

cat("\n=== DEBUGGING ENSEMBLE SETTINGS ===\n")
cat("settings$ensemble.id:", if(exists("ensemble.id", where=settings)) settings$ensemble.id else "NOT FOUND", "\n")
cat("settings$outdir:", settings$outdir, "\n")
cat("Class of settings$ensemble:", class(settings$ensemble), "\n")

# List all .Rdata files in the output directory
ensemble_files <- list.files(settings$outdir, pattern = "ensemble.*\\.Rdata$", full.names = TRUE)
cat("Found ensemble files:\n")
if (length(ensemble_files) > 0) {
  for (f in ensemble_files) cat("  -", f, "\n")
} else {
  cat("  NO ENSEMBLE FILES FOUND!\n")
}

# Print the entire ensemble structure
cat("\nFull ensemble structure:\n")
str(settings$ensemble)

cat("\n=== END DEBUG ===\n\n")

# there needs to be an ensemble run prior to this step...
# drafted something below that works, need to double check

if (PEcAn.utils::status.check("OUTPUT") == 0) {
  PEcAn.utils::status.start("OUTPUT")
  runModule.get.results(settings)
  PEcAn.utils::status.end()
}

runModule.run.ensemble.analysis(settings)

runModule.run.sensitivity.analysis(settings)

### Diagnostic plots to quickly visualize outputs

# First create a new figs folder in the demo_outdir directory
figs <- file.path(demo_outdir, "figs") #to get figs in EFS 
if (!dir.exists(figs)) {
    # using if(!dir.exists) instead of `showWarnings = FALSE`
    # to allow warnings like 'cannot create dir ...'
    dir.create(figs,
        recursive = TRUE
    )
}

# Plot Gross Primary Productivity (GPP) and Net Primary Productivity (NPP)
png(filename = file.path(figs,"sipnet_GPP_NPP_by_time.png"), width = 800, height = 600, res=100)
par(mfrow=c(1,1), mar=c(4.2,5.3,1,0.4), oma=c(0, 0.1, 0, 0.2))
plot(model_output$posix, model_output$GPP,
  type = "l",
  col = "green",
  xlab = "Date",
  ylab = "Carbon Flux (kg C m-2 s-1)",
  main = "Carbon Fluxes Over Time"
)
lines(model_output$posix, model_output$NPP, col = "blue")
legend("topright", legend = c("GPP", "NPP"), col = c("green", "blue"), lty = 1)
dev.off();

# Plot Total Live Biomass and Total Soil Carbon
png(filename = file.path(figs,"sipnet_SOC_LiveBiomass_by_time.png"), width = 800, height = 600, res=100)
par(mfrow=c(1,1), mar=c(4.2,5.3,1,0.4), oma=c(0, 0.1, 0, 0.2))
plot(model_output$posix, model_output$TotLivBiom,
  type = "l",
  col = "darkgreen",
  xlab = "Date",
  ylab = "Carbon Pool (kg C m-2)",
  main = "Carbon Pools Over Time"
)
lines(model_output$posix, model_output$TotSoilCarb, col = "brown")
legend("topright", legend = c("Total Live Biomass", "Total Soil Carbon"), col = c("darkgreen", "brown"), lty = 1)
dev.off();

## Plot Water Variables
# Plot Soil Moisture and Snow Water Equivalent
png(filename = file.path(figs,"sipnet_SM_SWE_by_time.png"), width = 800, height = 600, res=100)
par(mfrow=c(1,1), mar=c(4.2,5.3,1,0.4), oma=c(0, 0.1, 0, 0.2))
plot(model_output$posix, model_output$SoilMoist,
  type = "l",
  col = "blue",
  xlab = "Date",
  ylab = "Soil Moisture (kg m-2)",
  main = "Soil Moisture Over Time"
)
lines(model_output$posix, model_output$SWE, col = "lightblue")
legend("topright", legend = c("Soil Moisture", "Snow Water Equivalent"), col = c("blue", "lightblue"), lty = 1)
dev.off()

## Plot LAI and Biomass
# Plot Leaf Area Index (LAI) and Above Ground Wood
png(filename = file.path(figs,"sipnet_LAI_AGB_by_time.png"), width = 800, height = 600, res=100)
par(mfrow=c(1,1), mar=c(4.2,5.3,1,0.4), oma=c(0, 0.1, 0, 0.2))
plot(model_output$posix, model_output$LAI,
  type = "l",
  col = "darkgreen",
  xlab = "Date",
  ylab = "LAI (m2 m-2)",
  main = "Leaf Area Index Over Time"
)
lines(model_output$posix, model_output$AbvGrndWood, col = "brown")
legend("topright", legend = c("LAI", "Above Ground Wood"), col = c("darkgreen", "brown"), lty = 1)
dev.off()

### EOF
