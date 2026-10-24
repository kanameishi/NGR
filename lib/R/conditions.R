# The library signals the classed conditions of the AOM family; the ngr command
# draws them on stderr through its renderer, and an R session shows them as
# ordinary messages and errors.

# level is moduleNote or moduleProgress; operation, phase, unit and path are the
# fields the renderer adds with --verbose. The final newline keeps the text a
# complete line under R's default message handler.
.inform <- function(level, ..., operation, phase = NULL, unit = NULL, path = NULL) {
  message(messageCondition(.makeMessage(..., appendLF = TRUE), class = level, operation = operation,
                           phase = phase, unit = unit, path = path))
}

# A deliberate failure: the renderer writes its line without the R and package lines.
.fail <- function(...) stop(errorCondition(.makeMessage(...), class = "moduleFailure"))
