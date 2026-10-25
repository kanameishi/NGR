local({
  File <- grep("^--file=", commandArgs(), value = TRUE)
  if (length(File) != 1L) stop("Run the installed command through its launcher")
  File <- gsub("~+~", " ", sub("^--file=", "", File), fixed = TRUE)
  CLI_RESOURCES <- normalizePath(file.path(dirname(File), "../.."), winslash = "/", mustWork = TRUE)
  Args <- commandArgs(TRUE)
  # The console flags count only before `--`; main.R reads the other arguments from CLI_ARGS.
  Flags <- Args %in% c("--verbose", "--quiet") & seq_along(Args) < match("--", Args, nomatch = length(Args) + 1L)
  CLI_ARGS <- Args[!Flags]
  # AOM's installation diagnostic must remain reachable when its package cannot load.
  Doctor <- identical(CLI_ARGS, "doctor") && identical(basename(CLI_RESOURCES), "AOM")
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
    if (Doctor) .doctorProduct(CLI_RESOURCES)
  }, error = function(e) {
    if (!Doctor) stop(e)
    list(schema = 1L, package = "AOM", version = NULL, summary = list(status = "fail", ok = 0L, fail = 1L),
         checks = list(list(name = "bootstrap", required = TRUE, status = "fail", detail = conditionMessage(e))))
  })
  if (Doctor) {
    if (!requireNamespace("jsonlite", quietly = TRUE)) {
      message("aom doctor: jsonlite is unavailable; the diagnostic cannot be serialized")
      quit(save = "no", status = 1L)
    }
    writeLines(jsonlite::toJSON(OUT, auto_unbox = TRUE, pretty = TRUE, null = "null"))
    quit(save = "no", status = if (identical(OUT$summary$status, "ok")) 0L else 1L)
  }
  # The renderer runs only with the bytes its installation recorded, bound or not.
  Renderer <- file.path("libexec", basename(CLI_RESOURCES), "install/cli/console.R")
  if (!identical(unname(tools::md5sum(file.path(CLI_RESOURCES, "install/cli/console.R"))),
                 unlist(Record$md5)[match(Renderer, unlist(Record$file))])) stop("Installed console renderer hash mismatch")
  source(file.path(CLI_RESOURCES, "install/cli/console.R"), local = TRUE)
  # The command is the one install/requirements.R declares, as the installer recorded it.
  Console <- .consoleHandlers(command = sub("-cli$", "", Record$product), package = Record$package$name,
                              verbose = "--verbose" %in% Args[Flags], quiet = "--quiet" %in% Args[Flags],
                              terminal = isatty(stderr()), colour = !nzchar(Sys.getenv("NO_COLOR")))
  # R tries the most recent handlers first: those main.R establishes act before the renderer's.
  tryCatch(withCallingHandlers(source(file.path(CLI_RESOURCES, "main.R"), local = TRUE),
    message = Console$message, warning = Console$warning), error = Console$error, interrupt = Console$interrupt)
})
