#' Resolve the print stamp of a render from scaffold provenance
#'
#' Validates the per-file scaffold provenance recorded in a project manifest
#' and returns the print stamp of the render: the print date alone. The
#' technical revisions and the draft state of the resources stay in the
#' manifest receipts and are not shown to readers. This function reads files
#' without changing them.
#'
#' @param manifest Parsed project manifest as a list. An empty list represents
#'   a project without recorded scaffold provenance.
#' @param root Project directory containing the recorded relative file paths.
#'   Defaults to the current working directory.
#'
#' @return A character scalar `Printed: dd/mm/yyyy` with the current local
#'   date, which is also reported through a message condition.
#' @export
quartoRenderStamp <- function(manifest, root = getwd()) {
  Root <- normalizePath(root, winslash = "/")
  for (Source in manifest$scaffolds) {
    for (FILE in names(Source$files)) {
      if (startsWith(FILE, "/") || ".." %in% strsplit(FILE, "/", fixed = TRUE)[[1L]]) {
        .fail("Scaffold path escapes the project: ", FILE)
      }
      Entry <- Source$files[[FILE]]
      if (!is.character(Entry$commit) || length(Entry$commit) != 1L ||
          !grepl("^([0-9a-f]{7,64}|unknown)$", Entry$commit) ||
          !is.logical(Entry$dirty) || length(Entry$dirty) != 1L ||
          !is.character(Entry$md5) || length(Entry$md5) != 1L ||
          !grepl("^[0-9a-f]{32}$", Entry$md5)) {
        .fail("Invalid scaffold provenance for ", FILE)
      }
      Path <- file.path(Root, FILE)
      if (file.exists(Path)) {
        Path <- normalizePath(Path, winslash = "/")
        if (!startsWith(Path, paste0(Root, "/"))) {
          .fail("Scaffold path escapes the project: ", FILE)
        }
      }
    }
  }
  Timestamp <- Sys.time()
  .inform("moduleNote", "Render timestamp: ", format(Timestamp, "%Y-%m-%d %H:%M:%S %Z"), operation = "render")
  paste0("Printed: ", format(Timestamp, "%d/%m/%Y"))
}
