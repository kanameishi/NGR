#' Render a selection of project artifacts
#'
#' Validates the complete manifest's output claims before rendering selected
#' Quarto masters in manifest order. External products (`static` and legacy
#' `map` entries) are checked as existing outputs; their producers never run.
#'
#' @param manifest Path to a schema 1 or 2 artifact manifest, relative to `root`
#'   or absolute.
#' @param root Project directory. Defaults to the current working directory.
#' @param only Character vector of aliases to include; empty selects all.
#' @param except Character vector of aliases to exclude.
#' @param dryRun Validate selection, output claims and Quarto source paths
#'   without rendering or requiring existing output files.
#' @return Invisibly, the selected artifact records in manifest order.
#' @details Outputs are checked after the batch: required missing outputs fail,
#'   optional missing outputs are reported. Execution stops on the first render
#'   failure, retaining earlier successful outputs. This is not a transaction.
#' @seealso [quartoRender()]
#' @export
quartoRenderManifest <- function(manifest, root = getwd(), only = character(),
                                  except = character(), dryRun = FALSE) {
  if (!is.logical(dryRun) || length(dryRun) != 1L || is.na(dryRun)) {
    .fail("dryRun must be a boolean.")
  }
  Root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  Artifacts <- .readArtifacts(manifest = manifest, root = Root)
  Selected <- .selectArtifacts(Artifacts, only = only, except = except)
  Claims <- vapply(Artifacts, function(x) {
    if (x$kind == "quarto" && x$profile == "docx") return(.artifactOutput(x))
    x$path
  }, character(1L))
  Claims <- chartr("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz", Claims)
  if (anyDuplicated(Claims)) {
    .fail("Output already claimed by another artifact: ", Claims[[anyDuplicated(Claims)]])
  }
  for (Entry in Selected) {
    if (Entry$kind != "quarto") next
    .checkRenderOutput(profile = Entry$profile, output = Entry$path)
    if (!file_test("-f", file.path(Root, Entry$renderSource))) {
      .fail("Missing render source for ", Entry$alias, ": ", Entry$renderSource)
    }
  }
  for (Entry in Selected) {
    if (Entry$kind != "quarto") {
      .inform("moduleProgress", "skip external ", Entry$alias, " path=", Entry$path,
              operation = "render", phase = "manifest", unit = Entry$alias, path = Entry$path)
      next
    }
    .inform("moduleProgress", Entry$alias, " source=", Entry$renderSource, " profile=", Entry$profile,
            " path=", Entry$path, operation = "render", phase = "manifest", unit = Entry$alias, path = Entry$path)
    if (!dryRun) quartoRender(input = Entry$renderSource, profile = Entry$profile,
                              root = Root, output = Entry$path, manifest = manifest)
  }
  if (!dryRun) {
    Missing <- character()
    for (Entry in Selected) {
      Path <- .artifactOutput(Entry)
      if (file.exists(file.path(Root, Path))) next
      if (Entry$required) Missing <- c(Missing, paste0(Entry$alias, ": ", Path))
      if (!Entry$required) .inform("moduleNote", "optional missing output: ", Entry$alias, ": ", Path,
                                   operation = "render", phase = "manifest", unit = Entry$alias, path = Path)
    }
    if (length(Missing)) .fail("Missing required output: ", paste(Missing, collapse = "; "))
  }
  .inform("moduleNote", "manifest ", if (dryRun) "dry-run ok" else "complete", operation = "render", phase = "manifest")
  invisible(Selected)
}
