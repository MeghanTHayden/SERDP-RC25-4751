# Demo 03: State-Variable Data Assimilation (SDA)

This folder is a scaffold for the SDA tutorial using SIPNET and PEcAn.

## Purpose

- Store the initial `pecan.xml` settings for the UNDERC/NARR run.
- Store the SDA settings in `pecan.SDA.xml`.
- Provide a starter `workflow.R`.

## Files

- `workflow.R` — starter R workflow for running the initial PEcAn simulation.
- `pecan.xml.template` — a minimal settings template for the initial run.
- `pecan.SDA.xml.template` — a placeholder template for SDA settings.

## How to use

1. Copy or create your initial run settings to `pecan.xml`.
   - site: `UNDERC`
   - met: `NARR`
   - start date: `1979-01-01`
   - end date: `2015-12-31`
   - confirm the `outdir` path after the run

2. Run the initial SIPNET simulation:

```bash
cd /efs/home/mhayden/SERDP-RC25-4751
Rscript documentation/tutorials/Demo_03_SDA/workflow.R
```

3. After the initial run completes, copy the PDA `<pfts>` block from the saved PDA settings file into `pecan.SDA.xml`.

4. Add the `<state.data.assimilation>...</state.data.assimilation>` block to `pecan.SDA.xml` as shown in the tutorial.

5. Use the PalEON `workflow.treering.R` script from your cloned Camp2016 repository to load the tree-ring data and prepare the SDA inputs.

6. When the SDA settings are ready, update `workflow.R` to point to `pecan.SDA.xml` or create a separate `workflow_sda.R`.

## Notes

- The workflow script uses `here::here()` and explicit folder names to avoid loading the wrong XML file.
- If `pecan.xml` or `pecan.SDA.xml` does not exist, the script stops immediately with a clear message.
- Keep this folder dedicated to Demo 03 so the tutorial files do not conflict with Demo 01 or Demo 02.
