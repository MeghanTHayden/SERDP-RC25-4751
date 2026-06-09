# Demo 03 SDA starter workflow
# This script is intentionally minimal and uses explicit paths.

library("PEcAn.all")
library("here")

base_dir <- here::here("documentation", "tutorials", "Demo_03_SDA")
setwd(base_dir)

# ---- USER SETTINGS ---------------------------------------------------------
pecan_xml <- file.path(base_dir, "pecan.xml")
if (!file.exists(pecan_xml)) {
  stop("Missing initial PEcAn settings file: ", pecan_xml, "\n",
       "Create this file first and configure it for UNDERC / NARR / 1979-2015.")
}

settings <- PEcAn.settings::read.settings(pecan_xml)
settings <- PEcAn.settings::prepare.settings(settings)

cat("Loaded settings from:", pecan_xml, "\n")
cat("settings$ensemble$size:", settings$ensemble$size, "\n")
cat("settings$outdir:", settings$outdir, "\n")

# ---- OUTPUT DIRECTORY ------------------------------------------------------
demo_outdir <- file.path("demo_outdir")
if (dir.exists(demo_outdir)) {
  unlink(demo_outdir, recursive = TRUE, force = TRUE)
}
dir.create(demo_outdir, recursive = TRUE)

# ---- WRITE CONFIGS ---------------------------------------------------------
settings <- PEcAn.workflow::runModule.run.write.configs(settings)

# ---- LAUNCH MODEL RUNS -----------------------------------------------------
PEcAn.workflow::runModule_start_model_runs(settings)

# ---- WAIT FOR MODEL OUTPUT --------------------------------------------------
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

# ---- PROCESS RESULTS -------------------------------------------------------
if (PEcAn.utils::status.check("OUTPUT") == 0) {
  PEcAn.utils::status.start("OUTPUT")
  runModule.get.results(settings)
  PEcAn.utils::status.end()
}

message("Demo 03 initial run complete.\n",
        "If you are preparing SDA, create pecan.SDA.xml in this directory and use it for the SDA workflow.")
