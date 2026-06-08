library("PEcAn.all")

# outdir needs to be fresh each time for the slurm job to process correctly
demo_outdir <- file.path("demo_outdir")
if (dir.exists(demo_outdir)) {
  unlink(demo_outdir, recursive = TRUE, force = TRUE)
}
dir.create(demo_outdir, recursive = TRUE)

settings_path <- here::here("pecan_slurm.xml")
settings <- PEcAn.settings::read.settings(settings_path)
settings <- PEcAn.settings::prepare.settings(settings)

settings$info <- list(
  author = "serdp",
  date = Sys.Date(),
  description = "Demo run of PEcAn using SIPNET"
)

# 1) write configs
settings <- PEcAn.workflow::runModule.run.write.configs(settings)

# 2) launch model runs
PEcAn.workflow::runModule_start_model_runs(settings)

# 3) wait for raw model output to appear
wait_for_model_output <- function(settings, timeout = 60 * 60 * 4, poll = 30) {
  start_time <- Sys.time()
  repeat {
    run_dirs <- list.dirs(file.path(settings$outdir, "run"), recursive = FALSE, full.names = FALSE)
    ens_dirs <- run_dirs[grepl("^ENS-", basename(run_dirs))]
    if (length(ens_dirs) >= settings$ensemble$size) {
      message("Found ", length(ens_dirs), " ensemble run directories.")
      break
    }
    if (as.numeric(difftime(Sys.time(), start_time, units = "secs")) > timeout) {
      stop("Timed out waiting for model run output directories.")
    }
    message("Waiting for model output; found ", length(ens_dirs), " / ", settings$ensemble$size, " ensemble dirs.")
    Sys.sleep(poll)
  }
}
wait_for_model_output(settings)

# 4) convert results once output is present
if (PEcAn.utils::status.check("OUTPUT") == 0) {
  PEcAn.utils::status.start("OUTPUT")
  runModule.get.results(settings)
  PEcAn.utils::status.end()
}

# 5) do the ensemble and sensitivity analysis
runModule.run.ensemble.analysis(settings)
runModule.run.sensitivity.analysis(settings)

# 6) fetch model outputs
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

# 7) plot results
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