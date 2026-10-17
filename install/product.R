# Product installation composes package maintenance and the CLI publisher.

.installationPath <- function(path, writable = TRUE) {
  path <- path.expand(path)
  if (!nzchar(path) || grepl("[\r\n]", path)) stop("Invalid installation path", call. = FALSE)
  if (.Platform$OS.type == "windows") path <- chartr("\\", "/", path)
  if (.Platform$OS.type == "windows" && grepl("^[A-Za-z]:($|[^/])", path)) {
    stop("Use an absolute drive path, not a drive-relative path: ", path, call. = FALSE)
  }
  Absolute <- startsWith(path, "/") ||
    (.Platform$OS.type == "windows" && grepl("^[A-Za-z]:/", path))
  if (!Absolute) path <- file.path(getwd(), path)
  Parent <- path
  Parts <- character()
  while (!file.exists(Parent) && !dir.exists(Parent)) {
    Link <- Sys.readlink(Parent)
    if (!is.na(Link) && nzchar(Link)) stop("Broken symlink: ", Parent, call. = FALSE)
    # A drive that does not exist is its own parent on Windows: the walk would not end.
    if (identical(Parent, dirname(Parent))) stop("Installation parent does not exist: ", Parent, call. = FALSE)
    Parts <- c(basename(Parent), Parts)
    Parent <- dirname(Parent)
  }
  if (!dir.exists(Parent)) stop("Directory path is occupied by a file: ", Parent, call. = FALSE)
  if (writable && file.access(Parent, 2L) != 0L) stop("Directory is not writable: ", Parent, call. = FALSE)
  Path <- normalizePath(Parent, winslash = "/", mustWork = TRUE)
  for (Part in Parts) {
    if (Part == "..") Path <- dirname(Path)
    if (!(Part %in% c(".", ".."))) Path <- file.path(Path, Part)
  }
  Path
}

.runInstaller <- function(command, path, args = character()) {
  WD <- getwd()
  on.exit(setwd(WD), add = TRUE)
  setwd(path)
  Status <- system2(command[1L], args = shQuote(c(command[-1L], args)))
  if (Status != 0L) stop("Installer command failed (", Status, "): ",
                         paste(command, collapse = " "), call. = FALSE)
  invisible(NULL)
}

.verifyInstallation <- function(package, library, version, packages, exports, helper) {
  Script <- c(
    "Args <- commandArgs(TRUE)",
    ".libPaths(c(Args[1L], .libPaths()))",
    "tryCatch({",
    "source(Args[4L], local = TRUE)",
    "Count <- as.integer(Args[5L])",
    ".verifyPackage(Args[2L], Args[1L], Args[3L], Args[5L + seq_len(Count)], Args[-seq_len(5L + Count)])",
    "message('Verified installed package: ', Args[2L], ' ', Args[3L])",
    "}, error = function(e) stop(conditionMessage(e), '\\nR: ', R.version.string, ' at ', R.home(), '\\nLibraries: ', paste(.libPaths(), collapse = .Platform$path.sep), '\\nPackage found: ', paste(find.package(Args[2L], quiet = TRUE), collapse = ', '), call. = FALSE))"
  )
  .runInstaller(c(file.path(R.home("bin"), "Rscript"), "--vanilla", "-e",
                  paste(Script, collapse = "\n")), path = tempdir(),
                args = c(library, package, version, helper, length(packages), packages, exports))
}

installProduct <- function(root, args, system = FALSE, check = FALSE) {
  if (!length(args) || identical(args, "--help")) {
    writeLines(c(
      "Install the selected R package and CLI from this repository.",
      "Internal kit entry point; users invoke install/install.sh or install/install.ps1.",
      "Usage: Rscript install/installProduct.R [--system-cli] ROOT",
      "       --library DIR --prefix DIR",
      "       [--tarball FILE | --build DIR] [--dependency FILE ...]",
      "Options:",
      "  --library DIR           Target R library, resolved by the caller",
      "  --prefix DIR            CLI prefix; required when installing a CLI",
      "  --tarball FILE          Selected package archive and adjacent .rds record",
      "  --build DIR             Build from lib/ into this directory, without manual/vignettes",
      "  --dependency FILE       Additional recorded package archive; repeat in dependency order",
      "CLI conflict checks run before R installation. Existing CLI replacement follows its manager.",
      "R and external tools must be available. No Git, publishing or legacy-tool removal."
    ))
    return(invisible(NULL))
  }
  if (.Platform$OS.type != "windows" && identical(Sys.info()[["effective_user"]], "root")) {
    stop("R installation must run as the invoking user; use install/install.sh", call. = FALSE)
  }
  # system: an elevated shell (install/install.sh under sudo) runs the manager
  # and the launcher itself after this unprivileged pass; nothing here may
  # call sudo, whose credentials do not survive the drop to the invoking user.
  if (system && .Platform$OS.type == "windows") {
    stop("Unix CLI elevation is not a Windows installation mode", call. = FALSE)
  }
  Options <- list(dependency = character())
  while (length(args)) {
    Key <- sub("^--", "", args[1L])
    if (!startsWith(args[1L], "--") ||
        !(Key %in% c("library", "prefix", "tarball", "build", "dependency"))) {
      stop("Unknown installation argument: ", args[1L], call. = FALSE)
    }
    if (length(args) < 2L || !nzchar(args[2L]) || startsWith(args[2L], "--")) {
      stop("Missing value for ", args[1L], call. = FALSE)
    }
    if (Key == "dependency") Options$dependency <- c(Options$dependency, args[2L])
    if (Key != "dependency") {
      if (!is.null(Options[[Key]])) stop("Repeated option: ", Key, call. = FALSE)
      Options[[Key]] <- args[2L]
    }
    args <- args[-c(1L, 2L)]
  }
  if (is.null(Options$library)) stop("--library is required", call. = FALSE)
  Library <- .installationPath(Options$library)
  Libraries <- .libPaths()
  Environment <- Sys.getenv("R_LIBS", unset = NA_character_, names = TRUE)
  on.exit({
    .libPaths(Libraries)
    for (Name in names(Environment)) {
      if (is.na(Environment[[Name]])) Sys.unsetenv(Name)
      if (!is.na(Environment[[Name]])) do.call(Sys.setenv, setNames(list(Environment[[Name]]), Name))
    }
  }, add = TRUE)
  .libPaths(unique(c(Library, Libraries)))
  Sys.setenv(R_LIBS = paste(unique(c(Library, Libraries)), collapse = .Platform$path.sep))
  message("R executable: ", file.path(R.home("bin"), "Rscript"),
          "\nR user: ", Sys.info()[["effective_user"]], "\nR library: ", Library)
  Package <- .packageInfo(file.path(root, "lib"))
  Cli <- source(file.path(root, "install/requirements.R"), local = TRUE)$value
  if (!is.list(Cli)) stop("requirements.R must declare the CLI", call. = FALSE)
  if (is.null(Options$prefix)) stop("--prefix is required", call. = FALSE)
  Packages <- Cli$packages
  if (is.null(Packages)) Packages <- character()
  if (!is.character(Packages) || !is.null(names(Packages)) || anyNA(Packages) ||
      any(!grepl("^[A-Za-z][A-Za-z0-9.]*$", Packages))) {
    stop("requirements.R packages must be an unnamed vector of package names; dependencies belong in DESCRIPTION", call. = FALSE)
  }
  if ((!check && is.null(Options$build) && is.null(Options$tarball)) ||
      (!is.null(Options$build) && !is.null(Options$tarball))) {
    stop("Select exactly one of --tarball or --build", call. = FALSE)
  }
  Manager <- file.path(root, "install", "cli", "manage.R")
  Rscript <- file.path(R.home("bin"), "Rscript")
  Prefix <- .installationPath(Options$prefix, writable = !system)
  if (!file.exists(Manager)) stop("Missing CLI manager: ", Manager, call. = FALSE)
  Missing <- Cli$tools[!nzchar(Sys.which(Cli$tools))]
  if (length(Missing)) stop("Required executable(s) unavailable: ", paste(Missing, collapse = ", "), call. = FALSE)
  if (system) {
    .runInstaller(c(Rscript, "--vanilla", Manager, "inspect"), path = tempdir(), args = Prefix)
    message("CLI publication belongs to the elevated Bash caller: ", Prefix)
  }
  if (!system) .runInstaller(c(Rscript, "--vanilla", Manager, "check"), path = tempdir(), args = Prefix)
  Output <- NULL
  if (!is.null(Options$build)) {
    Output <- .installationPath(Options$build)
    FILE <- file.path(Output, paste0(Package$package, "_", Package$version, ".tar.gz"))
    if (file.exists(FILE) || file.exists(paste0(FILE, ".rds"))) stop("Build destination already exists: ", FILE, call. = FALSE)
    if (Output == Package$path || startsWith(Output, paste0(Package$path, "/"))) {
      stop("Build output must be outside the package source", call. = FALSE)
    }
  }
  Files <- c(Options$dependency, Options$tarball)
  for (File in Files) {
    if (!file.exists(File) || dir.exists(File) ||
        !file.exists(paste0(File, ".rds")) || dir.exists(paste0(File, ".rds"))) {
      stop("Archive and adjacent .rds record are required: ", File, call. = FALSE)
    }
  }
  if (check) return(invisible(NULL))
  # Hashing is needed before modifying the selected library. Bootstrap only
  # this verifier in scratch when it is absent; runtime resolution excludes it.
  if (length(Files) && !requireNamespace("digest", quietly = TRUE)) {
    Scratch <- tempfile("product-verifier-")
    dir.create(Scratch)
    on.exit(unlink(Scratch, recursive = TRUE), add = TRUE)
    utils::install.packages("digest", lib = Scratch, repos = "https://cloud.r-project.org")
    loadNamespace("digest", lib.loc = Scratch)
  }
  if (!is.null(Options$tarball)) {
    Artifact <- .readArtifact(Options$tarball)
    if (!identical(Artifact$files, .sourceHashes(Package$path))) {
      stop("Selected archive was built from different library sources; use its matching checkout", call. = FALSE)
    }
  }
  Installed <- installLibrary(path = Package$path, library = Library, build = Output,
                              tarball = Options$tarball, dependencies = Options$dependency)
  Version <- Installed$version
  installRequirements(path = Package$path, library = Library, packages = Packages, dependencies = FALSE)
  .verifyInstallation(package = Package$package, library = Library, version = Version,
                       packages = Packages, exports = Cli$exports,
                       helper = file.path(root, "install/cli/manifest.R"))
  if (!system) {
    tryCatch(.runInstaller(c(Rscript, "--vanilla", Manager, "install"), path = tempdir(),
                           args = Prefix),
             error = function(e) stop(conditionMessage(e), "\nR package remains installed at ",
                                       file.path(Library, Package$package), call. = FALSE))
  }
  message("R library for future CLI invocations: ", Library,
          "\nKeep it in the invoking shell's R_LIBS/R_LIBS_USER; no shell profile was changed.")
  invisible(list(package = Package$package, version = Version, library = Library, prefix = Prefix))
}
