## From the package root: Rscript inst/build.R OUTPUT_DIR.
## Builds with manual = TRUE and vignettes = TRUE, as devtools::submit_cran() does before its upload.
local({
  source("inst/package.R", local = TRUE)
  Args <- commandArgs(TRUE)
  if (length(Args) != 1L) stop("Required argument: OUTPUT_DIR", call. = FALSE)
  buildPackage(path = ".", output = Args[1L], documents = TRUE)
})
