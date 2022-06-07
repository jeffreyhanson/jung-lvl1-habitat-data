# Initialization
## load packages
library(aoh)
library(codetools)
library(raster)
library(terra)
library(sf)
library(rappdirs)
library(gdalUtilities)

## set variables
### set number of threads
n_threads <- max(1, parallel::detectCores() - 2)

## change this to where you want to save the raw data
input_dir <- "data"

### change this to where you want to save the outputs
output_dir <- "results"

### set version to process
version <- aoh:::latest_zenodo_version(
  x = "10.5281/zenodo.4058356",
  file = function(x) {
    any(
      startsWith(x, "iucn_habitatclassification_composite_lvl2") &
      endsWith(x, ".zip")
    )
  }
)

# Preliminary processing
## print version
cli::cli_alert_info(paste0("Version: ", version))
cli::cli_alert_info(paste0("GDAL_CACHEMAX: ", Sys.getenv("GDAL_CACHEMAX")))

## download data
archive_path <- aoh:::get_zenodo_data(
  x = version,
  dir = input_dir,
  force = FALSE,
  file = function(x) {
    any(
      startsWith(x, "iucn_habitatclassification_composite_lvl2") &
      endsWith(x, ".zip")
    )
  }
)

## unzip path
temp_dir <- tempfile()
dir.create(temp_dir, showWarnings = FALSE, recursive = TRUE)
utils::unzip(archive_path, exdir = temp_dir)
raw_path <- dir(temp_dir, "^.*\\.tif$", full.names = TRUE, recursive = TRUE)
assertthat::assert_that(
  length(raw_path) == 1,
  msg = "failed to find 100 m resolution composite layer"
)

## construct output path
output_path <- gsub(
  ".", "-", gsub("/", "_", version, fixed = TRUE), fixed = TRUE
)
output_path <- file.path(temp_dir, paste0("jung-lvl2-", output_path, ".tif"))
output_path <- gsub("\\", "/", output_path, fixed = TRUE)

# Main processing
## import habitat data
raw_data <- terra::rast(raw_path)

## import elevation data
elev_data <- get_global_elevation_data(
  dir = rappdirs::user_data_dir("aoh"),
  version = "latest",
  force = FALSE,
  verbose = TRUE
)

## project habitat data to match elevation data
habitat_data <- aoh:::terra_gdal_project(
  x = raw_data,
  y = elev_data,
  filename = output_path,
  method = "near",
  n_threads = n_threads,
  datatype = "INT2U",
  cache_limit = 5000,
  tiled = TRUE,
  bigtiff = TRUE,
  compress = "DEFLATE",
  verbose = TRUE
)

## verification
habitat_data <- terra::rast(output_path)
assertthat::assert_that(
  terra::compareGeom(habitat_data, elev_data, res = TRUE, stopiffalse = FALSE),
  msg = "GDAL processing didn't work correctly"
)

# Finished
message("Done!")
