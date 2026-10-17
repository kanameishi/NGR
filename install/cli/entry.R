local({
  File <- grep("^--file=", commandArgs(), value = TRUE)
  if (length(File) != 1L) stop("Run the installed command through its launcher")
  File <- gsub("~+~", " ", sub("^--file=", "", File), fixed = TRUE)
  CLI_RESOURCES <- normalizePath(file.path(dirname(File), "../.."), winslash = "/", mustWork = TRUE)
  # AOM's installation diagnostic must remain reachable when its package cannot load.
  Doctor <- identical(commandArgs(TRUE), "doctor") && identical(basename(CLI_RESOURCES), "AOM")
  OUT <- tryCatch({
    Record <- jsonlite::read_json(file.path(CLI_RESOURCES, "install.json"))
    if (!is.null(Record$binding) || Doctor) {
      Helper <- Filter(function(x) identical(x$installed, "install/cli/manifest.R"), Record$resources)
      if (length(Helper) != 1L || !identical(digest::digest(file = file.path(CLI_RESOURCES, "install/cli/manifest.R"), algo = "sha256"), Helper[[1L]]$sha256)) stop("Installed manifest reader hash mismatch")
      source(file.path(CLI_RESOURCES, "install/cli/manifest.R"), local = TRUE)
      if (!Doctor) {
        Record <- .verifyResources(CLI_RESOURCES)
        .libPaths(c(Record$package$library, .libPaths()))
        loadNamespace(Record$package$name, lib.loc = Record$package$library)
      }
    }
    if (Doctor) .doctorProduct(CLI_RESOURCES) else source(file.path(CLI_RESOURCES, "main.R"), local = TRUE)
  }, error = function(e) {
    if (!Doctor) stop(e)
    list(schema = 1L, package = "AOM", summary = list(status = "fail", ok = 0L, fail = 1L, skipped = 0L),
         checks = list(list(name = "bootstrap", status = "fail", detail = conditionMessage(e))))
  })
  if (Doctor) {
    if (!requireNamespace("jsonlite", quietly = TRUE)) {
      message("aom doctor: jsonlite is unavailable; the diagnostic cannot be serialized")
      quit(save = "no", status = 1L)
    }
    writeLines(jsonlite::toJSON(OUT, auto_unbox = TRUE, pretty = TRUE, null = "null"))
    quit(save = "no", status = if (identical(OUT$summary$status, "ok")) 0L else 1L)
  }
})
