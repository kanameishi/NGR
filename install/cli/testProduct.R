# Exercise the installed product without changing its selected R library.
runChecks <- function(root, library) {
  Requirements <- source(file.path(root, "install/requirements.R"), local = TRUE)$value
  Package <- read.dcf(file.path(root, "lib/DESCRIPTION"), fields = "Package")[1L, 1L]
  Runtime <- Requirements$runtime
  if (!length(Runtime)) Runtime <- Requirements$command
  Work <- tempfile("product CLI á ")
  dir.create(Work)
  on.exit(unlink(Work, recursive = TRUE), add = TRUE)
  WD <- getwd()
  on.exit(setwd(WD), add = TRUE, after = FALSE)
  setwd(Work)
  Environment <- Sys.getenv(c("R_LIBS", "R_ENVIRON_USER", "R_PROFILE_USER", "ZOTERO_API_KEY", "ZOTERO_LIBRARY_ID"), unset = NA_character_)
  on.exit({
    for (Name in names(Environment)) {
      if (is.na(Environment[[Name]])) Sys.unsetenv(Name)
      if (!is.na(Environment[[Name]])) do.call(Sys.setenv, setNames(list(Environment[[Name]]), Name))
    }
  }, add = TRUE)
  writeLines(character(), file.path(Work, "Renviron"))
  writeLines(character(), file.path(Work, "Rprofile"))
  Sys.setenv(R_LIBS = paste(c(library, .libPaths()), collapse = .Platform$path.sep),
             R_ENVIRON_USER = file.path(Work, "Renviron"), R_PROFILE_USER = file.path(Work, "Rprofile"),
             ZOTERO_API_KEY = "", ZOTERO_LIBRARY_ID = "")
  Prefix <- file.path(Work, "prefix")
  Windows <- .Platform$OS.type == "windows"
  Launcher <- file.path(Prefix, "bin", paste0(Requirements$command, if (Windows) ".cmd" else ""))
  runCommand <- function(command, args, status = 0L) {
    OUT <- suppressWarnings(system2(command, shQuote(args), stdout = TRUE, stderr = TRUE))
    Status <- attr(OUT, "status")
    if (is.null(Status)) Status <- 0L
    if (Status != status) stop(paste(OUT, collapse = "\n"))
    OUT
  }
  # Results and the renderer's lines apart, for the stream checks of the acceptance.
  runStreams <- function(command, args, status = 0L) {
    Streams <- tempfile(c("stdout-", "stderr-"), tmpdir = Work)
    Status <- system2(command, shQuote(args), stdout = Streams[1L], stderr = Streams[2L])
    OUT <- lapply(stats::setNames(Streams, c("stdout", "stderr")), readLines, warn = FALSE)
    if (Status != status) stop(paste(unlist(OUT), collapse = "\n"))
    OUT
  }
  runEntry <- function(name, args, status = 0L, libraryPath = library) {
    if (Windows) return(runCommand("powershell.exe", c("-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
      file.path(root, "install", paste0(name, ".ps1")), "-Yes", "-NoPath", "-Library", libraryPath, "-Prefix", Prefix, args), status = status))
    runCommand("bash", c(file.path(root, "install", paste0(name, ".sh")), "--yes", "--library", libraryPath, "--prefix", Prefix, args), status = status)
  }
  Files <- list.files(file.path(library, Package), recursive = TRUE, all.files = TRUE, full.names = TRUE)
  Hash <- tools::md5sum(Files)
  Rscript <- file.path(R.home("bin"), "Rscript")
  runCommand(Rscript, c("--vanilla", file.path(root, "install/cli/manage.R"), "check", Prefix))
  stopifnot(!dir.exists(Prefix))
  runCommand(Rscript, c("--vanilla", file.path(root, "install/cli/manage.R"), "install", Prefix))
  runCommand(Launcher, "--help")
  # One version per module: the first line of --version is the package and its version, and no
  # other line reports a version of the command.
  Version <- runCommand(Launcher, "--version")
  stopifnot(identical(Version[1L], paste(Package, utils::packageVersion(Package, lib.loc = library))),
            !any(grepl("\\bCLI\\b.*[0-9]+[.][0-9]+", Version)))
  Record <- jsonlite::read_json(file.path(Prefix, "libexec", Runtime, "install.json"), simplifyVector = TRUE)
  stopifnot(identical(unname(tools::md5sum(file.path(Prefix, Record$file))), Record$md5))
  Acceptance <- file.path(root, "install/acceptance.R")
  if (!file.exists(Acceptance)) stop("Missing product acceptance: ", Acceptance)
  # The acceptance runs in this process; its package calls must resolve from the
  # selected library, as the installed CLI does through R_LIBS. It reads this
  # harness through a child environment and cannot overwrite its locals.
  Libraries <- .libPaths()
  on.exit(.libPaths(Libraries), add = TRUE)
  .libPaths(c(library, Libraries))
  source(Acceptance, local = new.env(parent = environment()))
  runCommand(Rscript, c("--vanilla", file.path(root, "install/cli/manage.R"), "install", Prefix))
  stopifnot(identical(Hash, tools::md5sum(Files)))
  Foreign <- file.path(Prefix, "libexec", Runtime, "foreign.txt")
  writeLines("keep", Foreign)
  runEntry("uninstall", character())
  stopifnot(file.exists(Foreign), !file.exists(Launcher), identical(Hash, tools::md5sum(Files)))
  message("PASS ", Package, ": installed command, local operation, update, current R discovery, uninstall, library unchanged")
}
Args <- commandArgs(TRUE)
stopifnot(length(Args) == 2L)
runChecks(normalizePath(Args[1L], mustWork = TRUE), normalizePath(Args[2L], mustWork = TRUE))
