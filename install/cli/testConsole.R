# The console renderer and the entry that loads it, in a disposable installed layout.
runChecks <- function(kit) {
  Work <- tempfile("console renderer á ")
  dir.create(Work)
  on.exit(unlink(Work, recursive = TRUE), add = TRUE)
  Prefix <- file.path(Work, "prefix")
  Runtime <- file.path(Prefix, "libexec/consoleprobe")
  dir.create(file.path(Runtime, "install/cli"), recursive = TRUE)
  stopifnot(file.copy(file.path(kit, "cli", c("entry.R", "console.R")), file.path(Runtime, "install/cli")))
  # A main.R may rebind the entry's names (hazard and xemd assign Args); the handlers keep their flags.
  writeLines(c(
    'Args <- CLI_ARGS; Record <- NULL',
    'family <- function(class, text, ...) message(messageCondition(text, ..., class = class))',
    'switch(CLI_ARGS[1L],',
    '  echo = writeLines(CLI_ARGS[-1L]),',
    '  levels = {',
    '    family("moduleNote", "a note", operation = "probe")',
    '    family("moduleProgress", "step 1 of 2", phase = "run", count = 1L, total = 2L)',
    '    family("moduleDetail", "a detail", unit = "site", path = "out/a b.csv")',
    '    message("plain message")',
    '    warning(warningCondition("a family warning", class = "moduleWarning"))',
    '    warning("a plain warning")',
    '    writeLines("result")',
    '  },',
    '  fail = stop(errorCondition("probe failed", class = c("probeFailure", "moduleFailure"))),',
    '  partial = stop(errorCondition("partly published", class = c("modulePartialPublication", "moduleFailure"))),',
    '  status = stop(errorCondition("rejected", status = 3L, class = "moduleFailure")),',
    '  field = stop(errorCondition("refused input", path = "in/a b.json", class = "moduleFailure")),',
    '  usage = stop(errorCondition("unknown operation", class = "moduleUsage")),',
    '  crash = stop("unexpected"),',
    '  interrupt = { file.create(CLI_ARGS[2L]); Sys.sleep(30) },',
    '  stop("unknown fixture case"))'), file.path(Runtime, "main.R"))
  Files <- file.path("libexec/consoleprobe", c("install/cli/entry.R", "install/cli/console.R", "main.R"))
  jsonlite::write_json(list(product = "consoleprobe-cli", schema = 4L, package = list(name = "consoleprobe"),
                            file = Files, md5 = unname(tools::md5sum(file.path(Prefix, Files)))),
                       file.path(Runtime, "install.json"), auto_unbox = TRUE)
  Rscript <- file.path(R.home("bin"), "Rscript")
  runStreams <- function(args, status = 0L) {
    Streams <- tempfile(c("stdout-", "stderr-"), tmpdir = Work)
    Status <- system2(Rscript, shQuote(args), stdout = Streams[1L], stderr = Streams[2L])
    OUT <- lapply(stats::setNames(Streams, c("stdout", "stderr")), readLines, warn = FALSE)
    if (Status != status) stop("Exit status ", Status, ":\n", paste(unlist(OUT), collapse = "\n"))
    OUT
  }
  runEntry <- function(args, status = 0L) runStreams(c("--vanilla", file.path(Runtime, "install/cli/entry.R"), args), status = status)
  Errors <- function(text) paste0("consoleprobe: ", text)
  Warnings <- paste0("warning: ", c("a family warning", "a plain warning"))

  # Off a terminal each line is the text alone; a message outside the family keeps R's default output.
  for (Variable in c("", "1")) {
    Previous <- Sys.getenv("NO_COLOR", unset = NA_character_)
    Sys.setenv(NO_COLOR = Variable)
    OUT <- runEntry("levels")
    if (is.na(Previous)) Sys.unsetenv("NO_COLOR") else Sys.setenv(NO_COLOR = Previous)
    stopifnot(identical(OUT$stdout, "result"),
              identical(OUT$stderr, c("a note", "step 1 of 2", "plain message", Warnings)))
  }
  OUT <- runEntry(c("--quiet", "levels"))
  stopifnot(identical(OUT$stdout, "result"), identical(OUT$stderr, c("plain message", Warnings)))
  OUT <- runEntry(c("levels", "--verbose"))
  stopifnot(identical(OUT$stdout, "result"),
            identical(OUT$stderr, c("a note [operation=probe]", "step 1 of 2 [phase=run count=1 total=2]",
                                    "a detail [unit=site path=out/a b.csv]", "plain message", Warnings)))
  # Only the long flags before `--` belong to the entry; main.R receives the rest.
  OUT <- runEntry(c("echo", "a", "--quiet", "--", "--verbose", "-q", "b"))
  stopifnot(identical(OUT$stdout, c("a", "--", "--verbose", "-q", "b")), !length(OUT$stderr))
  # Given together, --quiet prevails: its lines, without the fields --verbose adds.
  OUT <- runEntry(c("--quiet", "levels", "--verbose"))
  stopifnot(identical(OUT$stdout, "result"), identical(OUT$stderr, c("plain message", Warnings)))
  OUT <- runEntry(c("--verbose", "field"), status = 1L)
  stopifnot(identical(OUT$stderr, Errors("refused input [path=in/a b.json]")))
  OUT <- runEntry(c("--verbose", "--quiet", "field"), status = 1L)
  stopifnot(!length(OUT$stdout), identical(OUT$stderr, Errors("refused input")))

  # The error line and the exit status of each failure.
  for (Case in list(list("fail", 1L, "probe failed"), list("partial", 1L, "partly published"),
                    list("status", 3L, "rejected"), list("usage", 2L, "unknown operation"))) {
    OUT <- runEntry(c("--verbose", Case[[1L]]), status = Case[[2L]])
    stopifnot(!length(OUT$stdout), identical(OUT$stderr, Errors(Case[[3L]])))
  }
  OUT <- runEntry("crash", status = 1L)
  stopifnot(!length(OUT$stdout), identical(OUT$stderr, c(Errors("unexpected"),
    paste0("R: ", R.version.string, " at ", R.home()), "Package found: none")))
  if (.Platform$OS.type != "windows") {
    # A user interrupt exits with 130; job control lets the background process receive SIGINT.
    Ready <- file.path(Work, "ready")
    Script <- paste('set -m; "$0" --vanilla "$1" interrupt "$2" & pid=$!',
                    'for i in $(seq 300); do [ -f "$2" ] && break; sleep 0.1; done',
                    'kill -INT "$pid"; wait "$pid"', sep = "\n")
    Status <- system2("bash", shQuote(c("-c", Script, Rscript, file.path(Runtime, "install/cli/entry.R"), Ready)),
                      stdout = FALSE, stderr = FALSE)
    stopifnot(file.exists(Ready), Status == 130L)
  }

  # On a terminal the renderer draws the ASCII symbol, coloured unless NO_COLOR asks otherwise.
  Terminal <- file.path(Work, "terminal.R")
  writeLines(c('Args <- commandArgs(TRUE)',
               'source(Args[1L], local = TRUE)',
               'Console <- .consoleHandlers(command = "consoleprobe", package = "consoleprobe", verbose = TRUE,',
               '  quiet = FALSE, terminal = TRUE, colour = identical(Args[3L], "colour"))',
               'CLI_ARGS <- Args[-(1:3)]',
               'tryCatch(withCallingHandlers(source(Args[2L], local = TRUE), message = Console$message,',
               '  warning = Console$warning), error = Console$error, interrupt = Console$interrupt)'), Terminal)
  runTerminal <- function(colour, case, status = 0L) {
    runStreams(c("--vanilla", Terminal, file.path(Runtime, c("install/cli/console.R", "main.R")), colour, case), status = status)
  }
  paint <- function(code, symbol) paste0("\033[", code, "m", symbol, "\033[39m")
  Lines <- c("a note [operation=probe]", "step 1 of 2 [phase=run count=1 total=2]", "a detail [unit=site path=out/a b.csv]")
  OUT <- runTerminal("colour", "levels")
  stopifnot(identical(OUT$stdout, "result"), identical(OUT$stderr, c(
    paste(c(paint("34", "i"), paint("36", ">"), paint("90", ".")), Lines), "plain message",
    paste(paint("33", "!"), c("a family warning", "a plain warning")))))
  OUT <- runTerminal("plain", "levels")
  stopifnot(identical(OUT$stderr, c(paste(c("i", ">", "."), Lines), "plain message",
                                    paste("!", c("a family warning", "a plain warning")))))
  OUT <- runTerminal("colour", "fail", status = 1L)
  stopifnot(identical(OUT$stderr, paste(paint("31", "x"), Errors("probe failed"))))
  OUT <- runTerminal("plain", "usage", status = 2L)
  stopifnot(identical(OUT$stderr, paste("x", Errors("unknown operation"))))

  # The entry refuses a renderer whose bytes differ from the installation record.
  write("# changed after installation", file.path(Runtime, "install/cli/console.R"), append = TRUE)
  OUT <- runEntry("echo", status = 1L)
  stopifnot(!length(OUT$stdout), any(grepl("Installed console renderer hash mismatch", OUT$stderr, fixed = TRUE)))
  message("PASS console: levels, quiet, verbose fields, flags kept when main.R rebinds Args, NO_COLOR off a terminal, flags before --, --quiet over --verbose, error lines and fields, exit statuses 1, 2, 3 and 130, terminal symbols and colours, renderer hash")
}
runChecks(normalizePath(commandArgs(TRUE)[1L], mustWork = TRUE))
