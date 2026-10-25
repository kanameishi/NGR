# The family console renderer. entry.R loads it after checking the bytes its
# installation recorded; the library signals classed conditions and only these
# handlers draw them, on stderr.
.consoleHandlers <- function(command, package, verbose, quiet, terminal, colour) {
  # The handlers run while entry.R sources main.R in the frame that computed these arguments, and a
  # main.R may rebind the names they read (Args, Record): the values are fixed here, not at first use.
  force(command); force(package); force(verbose); force(quiet); force(terminal); force(colour)
  # Symbol and ANSI colour of each level: blue, cyan, grey, yellow and red.
  Levels <- list(moduleNote = c("i", "34"), moduleProgress = c(">", "36"), moduleDetail = c(".", "90"),
                 warning = c("!", "33"), error = c("x", "31"))
  Fields <- c("operation", "phase", "unit", "path", "count", "total")
  textOf <- function(condition) sub("\n$", "", conditionMessage(condition))
  draw <- function(level, text, condition) {
    if (verbose && !quiet) {
      Values <- Filter(Negate(is.null), lapply(stats::setNames(Fields, Fields), function(x) condition[[x]]))
      if (length(Values)) text[1L] <- paste0(text[1L], " [", paste0(names(Values), "=",
        vapply(Values, paste, character(1L), collapse = ","), collapse = " "), "]")
    }
    if (terminal) {
      Symbol <- Levels[[level]][1L]
      if (colour) Symbol <- paste0("\033[", Levels[[level]][2L], "m", Symbol, "\033[39m")
      text[1L] <- paste(Symbol, text[1L])
    }
    if (!terminal && level == "warning") text[1L] <- paste0("warning: ", text[1L])
    writeLines(text, con = stderr())
  }
  list(
    message = function(condition) {
      Level <- intersect(class(condition), c("moduleNote", "moduleProgress", "moduleDetail"))[1L]
      # A message outside the family goes on to R's default handler, as before its module migrates.
      if (is.na(Level)) return(invisible(NULL))
      if (!quiet && (verbose || Level != "moduleDetail")) draw(Level, textOf(condition), condition)
      invokeRestart("muffleMessage")
    },
    warning = function(condition) {
      draw("warning", textOf(condition), condition)
      invokeRestart("muffleWarning")
    },
    error = function(condition) {
      Text <- paste0(command, ": ", textOf(condition))
      if (!inherits(condition, c("moduleFailure", "moduleUsage"))) {
        # A failure outside the family names R and the package version it found, never a library path.
        Found <- find.package(package, quiet = TRUE)
        Text <- c(Text, paste0("R: ", R.version.string, " at ", R.home()), paste0("Package found: ",
          if (length(Found)) paste(package, utils::packageVersion(package, lib.loc = dirname(Found))) else "none"))
      }
      draw("error", Text, condition)
      Status <- if (inherits(condition, "moduleUsage")) 2L else 1L
      # A code of the module's own travels in the status field that its help declares.
      if (is.numeric(condition[["status"]]) && length(condition[["status"]]) == 1L &&
          condition[["status"]] %in% 1:255) Status <- as.integer(condition[["status"]])
      quit(save = "no", status = Status)
    },
    interrupt = function(condition) quit(save = "no", status = 130L))
}
