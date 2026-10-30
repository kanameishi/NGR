#!/usr/bin/env Rscript
# ngr: command-line interface of the installed NGR package. This file reads its
# arguments from CLI_ARGS, writes results to stdout and returns the exit status of
# a completed command; every operation is an exported NGR function. Errors and
# the library's conditions go to the renderer of install/cli/console.R.

.failUsage <- function(...) stop(errorCondition(paste0(...), class = c("ngrUsageError", "moduleUsage")))

.splitAliases <- function(value) Filter(nzchar, strsplit(value, ",", fixed = TRUE)[[1L]])

.loadLibrary <- function() {
  if (!suppressPackageStartupMessages(requireNamespace("NGR", quietly = TRUE))) {
    stop("the NGR R package is not installed in the active R library", call. = FALSE)
  }
  invisible(NULL)
}

.showVersion <- function(runtime) {
  # One version per module, in two lines: the installed package's, then the
  # build (owner rulings of 2026-10-12 and 2026-10-25).
  .loadLibrary()
  writeLines(c(paste("NGR", utils::packageVersion("NGR")), .buildLine(runtime)))
  0L
}

# The installer records the commit of the installed sources in BUILD_INFO; the
# tag in git_describe would name a past version, so the line keeps the commit.
.buildLine <- function(runtime) {
  File <- file.path(runtime, "BUILD_INFO")
  if (!file.exists(File)) return("build: unknown")
  Info <- readLines(File, warn = FALSE)
  Values <- sub("^[^=]*=", "", Info)
  names(Values) <- sub("=.*", "", Info)
  if (!grepl("^[0-9a-f]{7,}$", Values["git_commit"])) return("build: unknown")
  paste0("build: ", substr(Values[["git_commit"]], 1L, 7L), if (identical(unname(Values["dirty"]), "true")) "-dirty")
}

.showHelp <- function() {
  writeLines(c("ngr - resources, reports and publication", "",
               "Run from the project directory, or select it with --root DIR.",
               "DIR must exist; relative paths use the selected project.", "",
               "Commands:",
               "  pull   --from <manifest.json> [paths...]      Bring resources from a source into the project",
               "  pull   [--force] [--dry-run] [paths...]       Update the project from its recorded sources",
               "  status [--check] [paths...]                   Compare the project with its sources",
               "  check  [--source ID]                          Check the project against its declared checks",
               "  doctor                                        Diagnose this installation and print one JSON report",
               "  render <input.qmd> --profile <profile>        Render through yml/_quarto*.yml (book|html|revealjs|docx)",
               "  render --manifest <file> [--dry-run]          Render or plan the manifest artifacts",
               "  deploy                                        Publish artifacts and register Netlify sites", "",
               "  --version                                     Show the package version and the build commit", "",
               "Results go to stdout; notes, progress, warnings and errors go to stderr.",
               "--verbose adds the condition fields to the stderr lines; --quiet hides notes and progress.",
               "Given together, --quiet prevails. Both count only before --.",
               "Exit: 0 success; 1 failure, or drift found by status --check; 2 invalid usage; 130 interrupted.", "",
               "Run 'ngr <command> --help' for command-specific help."))
  0L
}

.runResources <- function(args, runtime) {
  Command <- args[[1L]]
  Args <- args[-1L]
  Flags <- c("--source", "--help")
  if (Command %in% c("pull", "status")) Flags <- c(Flags, "--from")
  if (Command == "pull") Flags <- c(Flags, "--force", "--dry-run")
  if (Command == "status") Flags <- c(Flags, "--check")
  Values <- list(from = NULL, source = NULL, paths = character())
  Force <- DryRun <- Check <- Help <- FALSE
  Positional <- FALSE
  i <- 1L
  while (i <= length(Args)) {
    Arg <- Args[[i]]
    i <- i + 1L
    if (!Positional && Arg == "--") {
      Positional <- TRUE
      next
    }
    if (!Positional && Arg == "-h") Arg <- "--help"
    if (!Positional && startsWith(Arg, "-")) {
      Flag <- sub("=.*$", "", Arg)
      Matches <- Flags[startsWith(Flags, Flag)]
      if (length(Matches) != 1L) .failUsage("Unknown or ambiguous argument: ", Arg)
      Flag <- Matches[[1L]]
      if (Flag %in% c("--source", "--from")) {
        Value <- NULL
        if (grepl("=", Arg, fixed = TRUE)) Value <- substring(Arg, regexpr("=", Arg, fixed = TRUE) + 1L)
        if (is.null(Value)) {
          if (i > length(Args) || startsWith(Args[[i]], "-")) .failUsage(Flag, " requires a value")
          Value <- Args[[i]]
          i <- i + 1L
        }
        Name <- substring(Flag, 3L)
        Values[[Name]] <- c(Values[[Name]], Value)
        next
      }
      if (grepl("=", Arg, fixed = TRUE)) .failUsage(Flag, " takes no value")
      if (Flag == "--help") Help <- TRUE
      if (Flag == "--force") Force <- TRUE
      if (Flag == "--dry-run") DryRun <- TRUE
      if (Flag == "--check") Check <- TRUE
      next
    }
    if (Command == "check") .failUsage("Unknown argument: ", Arg)
    Values$paths <- c(Values$paths, Arg)
  }
  if (Help) {
    writeLines(paste0("usage: ngr ", Command, " [--source ID] ",
                      if (Command %in% c("pull", "status")) "[--from MANIFEST] ",
                      if (Command == "pull") "[--force] [--dry-run] ",
                      if (Command == "status") "[--check] ",
                      "[--root DIR] [--help]",
                      if (Command %in% c("pull", "status")) " [TARGETS ...]"))
    return(0L)
  }
  .loadLibrary()
  Values$from[Values$from == "ngr"] <- file.path(runtime, "scaffold/manifest.json")
  if (Command == "pull") {
    Result <- NGR::pullResources(from = Values$from, source = Values$source, paths = Values$paths,
                                 force = Force, dryRun = DryRun)
    writeLines(paste(Result$actions$source, Result$actions$action, Result$actions$path, sep = "\t"))
    writeLines(paste0("[pull] ", if (DryRun) "plan" else "complete", ": ", nrow(Result$actions), " resource contributions"))
    return(0L)
  }
  if (Command == "status") {
    Result <- NGR::compareResources(from = Values$from, source = Values$source, paths = Values$paths)
    writeLines(paste0(paste(Result$files$source, Result$files$state, Result$files$path, sep = "\t"),
                      ifelse(Result$files$modified, "\tlocally-modified", "")))
    return(as.integer(Check && Result$changed))
  }
  message(messageCondition(paste0("NGR ", utils::packageVersion("NGR"), "\n"), class = "moduleNote", operation = "check"))
  NGR::checkResources(source = Values$source)
  writeLines("[check] declared checks passed")
  0L
}

# doctor diagnoses this installation and repairs nothing (owner ruling of
# 2026-10-25); the checks the project's sources declare run under check.
.runDoctor <- function(args, runtime) {
  if (length(args) == 1L && args %in% c("--help", "-h")) {
    writeLines(c("Usage: ngr doctor",
                 "Diagnoses this installation without repairs, takes no arguments and prints one JSON report on stdout;",
                 "exits 0 when every required check passes and 1 otherwise.",
                 "Required checks:",
                 "  library   the library loads with the version of lib/DESCRIPTION",
                 "  exports   the exports declared in install/requirements.R exist",
                 "  packages  the packages declared in install/requirements.R load",
                 "  tools     the tools declared in install/requirements.R are on PATH",
                 "  receipt   the files of the installation receipt keep their recorded MD5",
                 "Checks that warn instead of failing:",
                 "  optional  the optional tools declared in install/requirements.R are on PATH"))
    return(0L)
  }
  if (length(args)) .failUsage("doctor takes no arguments: ", paste(args, collapse = " "))
  .loadLibrary()
  Report <- NGR::describeModule(runtime)
  writeLines(jsonlite::toJSON(Report, auto_unbox = TRUE, pretty = TRUE))
  if (identical(Report$summary$status, "ok")) 0L else 1L
}

.runRender <- function(args, runtime) {
  Values <- list(manifest = NULL, profile = NULL, only = "", except = "")
  Input <- NULL
  Extra <- character()
  DryRun <- FALSE
  i <- 1L
  while (i <= length(args)) {
    Arg <- args[[i]]
    i <- i + 1L
    if (Arg %in% c("-h", "--help")) {
      writeLines(c("Usage: ngr render <input.qmd> --profile <book|revealjs|docx|html> [Quarto args...]",
                   "       ngr render --manifest <file> [--dry-run] [--only <aliases>] [--except <aliases>]", "",
                   "--root DIR selects an existing project directory; default is the working directory.",
                   "Uses yml/_quarto.yml and yml/_quarto-<profile>.yml from the project.",
                   "Book masters supply chapters and appendices through frontmatter.",
                   "DOCX uses master title/lang and params.client.name, params.consultant.name,",
                   "  params.project_id from params.yml; the render date is automatic (dd/mm/yyyy).",
                   "  No srk block or manual date is required.",
                   "Output: html/<stem>/, the manifest's HTML path, or docx/.",
                   "Run ngr pull --from ngr first if yml/ does not exist."))
      return(0L)
    }
    if (Arg %in% paste0("--", names(Values))) {
      if (i > length(args)) .failUsage(Arg, " requires a value.")
      Values[[substring(Arg, 3L)]] <- args[[i]]
      i <- i + 1L
      next
    }
    if (Arg == "--dry-run") {
      DryRun <- TRUE
      next
    }
    if (grepl("\\.(qmd|md)$", Arg)) {
      if (!is.null(Input)) .failUsage("Multiple render inputs.")
      Input <- Arg
      next
    }
    Extra <- c(Extra, Arg)
  }
  if (!is.null(Values$manifest)) {
    if (!is.null(Input) || !is.null(Values$profile)) .failUsage("--manifest cannot be combined with input/--profile.")
    if (length(Extra)) .failUsage("Unsupported arguments with --manifest: ", paste(Extra, collapse = " "))
    .loadLibrary()
    NGR::quartoRenderManifest(Values$manifest, only = .splitAliases(Values$only),
                              except = .splitAliases(Values$except), dryRun = DryRun)
    return(0L)
  }
  if (DryRun || nzchar(Values$only) || nzchar(Values$except)) {
    .failUsage("--dry-run/--only/--except require --manifest.")
  }
  .loadLibrary()
  NGR::quartoRender(input = Input, profile = Values$profile, args = Extra)
  0L
}

.runDeploy <- function(args, runtime) {
  Action <- "upload"
  if (length(args) && args[[1L]] %in% c("init", "domain", "unbind")) {
    Action <- args[[1L]]
    args <- args[-1L]
  }
  if (!length(args) || args[[1L]] %in% c("-h", "--help")) {
    writeLines(c("Usage:",
                 "  ngr deploy <alias> <dir> [--prod]",
                 "  ngr deploy --manifest <file> [--dry-run] [--prod] [--only <aliases>] [--except <aliases>]",
                 "  ngr deploy init <alias> <site-name> [--create] [--account <slug>]",
                 "  ngr deploy init --manifest <file> [--dry-run] [--create] [--account <slug>] [--only <aliases>] [--except <aliases>]",
                 "  ngr deploy domain <alias> <domain> [--https] [--rebind] [--dry-run]",
                 "  ngr deploy domain --manifest <file> [--https] [--dry-run] [--only <aliases>] [--except <aliases>]",
                 "  ngr deploy unbind <alias>", "",
                 "--root DIR selects the project and its .netlify/sites.env registry."))
    return(0L)
  }
  Values <- list(manifest = NULL, only = "", except = "", account = NULL)
  Flags <- list(prod = FALSE, create = FALSE, https = FALSE, rebind = FALSE, dryRun = FALSE)
  Supplied <- character()
  Positional <- character()
  i <- 1L
  while (i <= length(args)) {
    Arg <- args[[i]]
    i <- i + 1L
    if (Arg %in% paste0("--", names(Values))) {
      if (i > length(args)) .failUsage(Arg, " requires a value.")
      Values[[substring(Arg, 3L)]] <- args[[i]]
      i <- i + 1L
      Supplied <- c(Supplied, Arg)
      next
    }
    if (Arg %in% c("--prod", "--create", "--https", "--rebind", "--dry-run")) {
      Name <- substring(Arg, 3L)
      if (Arg == "--dry-run") Name <- "dryRun"
      Flags[[Name]] <- TRUE
      Supplied <- c(Supplied, Arg)
      next
    }
    if (startsWith(Arg, "-")) .failUsage("Unknown deploy argument: ", Arg)
    Positional <- c(Positional, Arg)
  }
  Allowed <- switch(Action, upload = "--prod", init = c("--create", "--account"),
                    domain = c("--https", "--rebind", "--dry-run"), unbind = character())
  if (!is.null(Values$manifest) && Action != "unbind") {
    Allowed <- c(setdiff(Allowed, "--rebind"), "--manifest", "--dry-run", "--only", "--except")
  }
  if (any(!Supplied %in% Allowed)) .failUsage("Unsupported deploy argument: ", paste(setdiff(Supplied, Allowed), collapse = " "))
  if (is.null(Values$manifest)) {
    Expected <- 2L
    if (Action == "unbind") Expected <- 1L
    if (length(Positional) != Expected) .failUsage("Missing or extra deploy arguments; see ngr deploy --help.")
    .loadLibrary()
    if (Action == "unbind") NGR::netlifyUnbind(Positional[[1L]])
    if (Action == "init") NGR::netlifyRegister(Positional[[1L]], site = Positional[[2L]], create = Flags$create, account = Values$account)
    if (Action == "upload") .writeResponses(NGR::netlifyDeploy(Positional[[1L]], path = Positional[[2L]], prod = Flags$prod))
    if (Action == "domain") NGR::netlifyDomain(Positional[[1L]], domain = Positional[[2L]], https = Flags$https, rebind = Flags$rebind, dryRun = Flags$dryRun)
    return(0L)
  }
  if (length(Positional)) .failUsage("--manifest cannot be combined with positional arguments.")
  .loadLibrary()
  Only <- .splitAliases(Values$only)
  Except <- .splitAliases(Values$except)
  if (Action == "init") {
    NGR::netlifyRegisterManifest(Values$manifest, only = Only, except = Except, create = Flags$create,
                                 account = Values$account, dryRun = Flags$dryRun)
    return(0L)
  }
  if (Action == "domain") {
    NGR::netlifyDomainManifest(Values$manifest, only = Only, except = Except, https = Flags$https,
                               dryRun = Flags$dryRun)
    return(0L)
  }
  if (Action == "upload") {
    .writeResponses(NGR::netlifyDeployManifest(Values$manifest, only = Only, except = Except, prod = Flags$prod,
                                               dryRun = Flags$dryRun))
    return(0L)
  }
  stop("Unsupported deploy operation: ", Action, call. = FALSE)
}

# What the Netlify CLI returned for each upload is a result: the lines of the
# returned UUIDs' response attribute, in upload order.
.writeResponses <- function(ids) {
  for (Lines in attr(ids, "response")) writeLines(Lines)
}

# The record of a partial publication: the output of the completed uploads, or
# one line per completed registration or domain effect with its alias, action
# and value, separated by tabs as pull lists its actions.
.writeEffects <- function(effects) {
  if (is.data.frame(effects)) writeLines(paste(effects$alias, effects$action, effects$value, sep = "\t"))
  if (!is.data.frame(effects)) .writeResponses(effects)
}

.runCommand <- function(args, runtime) {
  IDX <- which((args == "--root" | startsWith(args, "--root=")) &
                 seq_along(args) < match("--", args, nomatch = length(args) + 1L))
  if (length(IDX) > 1L) .failUsage("--root may be supplied only once")
  if (length(IDX)) {
    i <- IDX[[1L]]
    Root <- sub("^--root=", "", args[[i]])
    if (args[[i]] == "--root") {
      if (i == length(args) || startsWith(args[[i + 1L]], "-")) .failUsage("--root requires a directory")
      Root <- args[[i + 1L]]
      IDX <- c(i, i + 1L)
    }
    if (!nzchar(Root) || !dir.exists(Root)) .failUsage("--root must be an existing directory: ", Root)
    # Resolve the launcher payload before changing the base of relative paths.
    force(runtime)
    Directory <- getwd()
    on.exit(setwd(Directory), add = TRUE)
    setwd(Root)
    args <- args[-IDX]
  }
  if (!length(args) || args[[1L]] %in% c("--help", "-h")) return(.showHelp())
  Command <- args[[1L]]
  if (Command == "--version") {
    if (length(args) != 1L) .failUsage("--version takes no arguments")
    return(.showVersion(runtime))
  }
  if (Command %in% c("pull", "status", "check")) return(.runResources(args, runtime = runtime))
  if (Command == "doctor") return(.runDoctor(args[-1L], runtime = runtime))
  if (Command == "render") return(.runRender(args[-1L], runtime = runtime))
  if (Command == "deploy") return(.runDeploy(args[-1L], runtime = runtime))
  .failUsage("Unknown command: ", Command, "; use ngr --help")
}

Path <- Sys.getenv("NGR_COMMAND_PATH", unset = NA_character_)
if (!is.na(Path)) Sys.setenv(PATH = Path)
Sys.unsetenv("NGR_COMMAND_PATH")
# entry.R passes the installed payload root; run from a checkout, the root is
# this file's directory.
Runtime <- if (exists("CLI_RESOURCES")) CLI_RESOURCES else {
  File <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1L]])
  # R encodes spaces as ~+~ in --file= on Unix; decode before resolving.
  dirname(normalizePath(gsub("~+~", " ", File, fixed = TRUE), winslash = "/", mustWork = TRUE))
}
# After a failure that follows completed effects, their record goes to stdout
# before the error reaches the renderer, which exits 1.
quit(save = "no", status = withCallingHandlers(
  .runCommand(if (exists("CLI_ARGS")) CLI_ARGS else commandArgs(trailingOnly = TRUE), runtime = Runtime),
  ngrPartialPublication = function(e) .writeEffects(e$effects)))
