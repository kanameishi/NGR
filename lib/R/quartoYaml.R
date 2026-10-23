# nolint start
#' Read QMD YAML frontmatter
#'
#' Reads the YAML frontmatter block from a QMD/Markdown file. Files without a
#' complete frontmatter block return an empty list.
#'
#' @param path Character scalar. Path to a QMD/Markdown file.
#'
#' @return A list parsed from YAML frontmatter, or an empty list.
#' @rdname quartoYaml
#' @export
quartoReadFrontmatter <- function(path) {
  Path <- as.character(path)
  if (length(Path) != 1L || !nzchar(Path)) {
    stop("quartoReadFrontmatter: path must be one non-empty value.", call. = FALSE)
  }
  if (!file.exists(Path)) {
    stop("quartoReadFrontmatter: file not found: ", Path, call. = FALSE)
  }

  Lines <- readLines(Path, warn = FALSE)
  if (!length(Lines) || !identical(Lines[[1L]], "---")) return(list())

  End <- which(Lines[-1L] == "---")[1L] + 1L
  if (is.na(End) || End <= 2L) return(list())

  Text <- paste(Lines[2L:(End - 1L)], collapse = "\n")
  if (!nzchar(trimws(Text))) return(list())

  Out <- yaml::yaml.load(Text)
  if (is.null(Out)) list() else Out
}

#' Coerce a value to a YAML sequence list
#'
#' Converts NULL to an empty list and all other values to a list. This is useful
#' when writing Quarto YAML fields that must remain sequences even when they
#' contain a single entry.
#'
#' @param x Value to coerce.
#'
#' @return A list.
#' @rdname quartoYaml
#' @export
quartoAsSequence <- function(x) {
  if (is.null(x)) list() else as.list(x)
}

#' Test whether parsed frontmatter is a book manifest
#'
#' A qrt-style book manifest is frontmatter with at least one `chapters` or
#' `appendices` entry.
#'
#' @param frontmatter A list, usually from [quartoReadFrontmatter()].
#'
#' @return TRUE when the frontmatter declares chapters or appendices.
#' @rdname quartoYaml
#' @export
quartoHasBookManifest <- function(frontmatter) {
  Frontmatter <- .quartoRequireList(frontmatter, "frontmatter")
  length(quartoAsSequence(Frontmatter$chapters)) > 0L ||
    length(quartoAsSequence(Frontmatter$appendices)) > 0L
}

#' Set Quarto project render targets
#'
#' Sets `project.render` on a parsed Quarto YAML list while preserving the rest
#' of the config.
#'
#' @param base Parsed Quarto YAML list.
#' @param render Character vector or list of render targets.
#'
#' @return Modified Quarto YAML list.
#' @rdname quartoYaml
#' @export
quartoSetProjectRender <- function(base, render) {
  Base <- .quartoRequireList(base, "base")
  if (is.null(Base$project) || !is.list(Base$project)) Base$project <- list()
  Base$project$render <- quartoAsSequence(render)
  Base
}

#' Merge QMD book-manifest frontmatter into Quarto YAML
#'
#' Merges qrt-style manifest fields (`title`, `author`, `chapters`,
#' `appendices`, `bibliography`, `lang`, `language`, `toc-title`,
#' `footer-title`, `footer-meta` and `crossref`) into a parsed `_quarto.yml`
#' list and sets `project.render` to the declared chapters plus appendices.
#' Scalar keys of the master replace the configuration; `crossref` is merged
#' entry by entry over the configuration's block, so a master in another
#' language overrides the shared `yml/` declarations. `part:` entries are preserved in
#' `book.chapters`/`book.appendices` and flattened to their chapter files for
#' `project.render`, which only accepts paths.
#'
#' @param base Parsed base Quarto YAML list.
#' @param manifest Parsed QMD frontmatter list.
#'
#' @return Modified Quarto YAML list.
#' @rdname quartoYaml
#' @export
quartoMergeBookManifest <- function(base, manifest) {
  Base <- .quartoRequireList(base, "base")
  Manifest <- .quartoRequireList(manifest, "manifest")

  Book <- list()
  if (!is.null(Manifest$title)) Book$title <- Manifest$title
  if (!is.null(Manifest$author)) Book$author <- Manifest$author
  if (!is.null(Manifest$chapters)) Book$chapters <- .quartoBookEntries(Manifest$chapters)
  if (!is.null(Manifest$appendices)) Book$appendices <- .quartoBookEntries(Manifest$appendices)
  if (length(Book) > 0L) Base$book <- Book

  Render <- c(.quartoChapterFiles(Manifest$chapters), .quartoChapterFiles(Manifest$appendices))
  if (length(Render) > 0L) Base <- quartoSetProjectRender(Base, Render)

  if (!is.null(Manifest$bibliography)) Base$bibliography <- Manifest$bibliography
  if (!is.null(Manifest$lang)) Base$lang <- Manifest$lang
  for (Key in c("footer-title", "footer-meta", "toc-title", "language")) {
    if (!is.null(Manifest[[Key]])) Base[[Key]] <- Manifest[[Key]]
  }
  if (is.list(Manifest$crossref)) {
    Crossref <- if (is.list(Base$crossref)) Base$crossref else list()
    Base$crossref <- utils::modifyList(Crossref, Manifest$crossref)
  }
  Base
}

# Identity printed by lua/page-footer.lua. A declared footer-meta wins; otherwise
# the author and the organisation of params.yml, joined; otherwise nothing, so
# that no identity enters a document that declares none.
.quartoFooterMeta <- function(params, config) {
  Declared <- config[["footer-meta"]]
  if (is.character(Declared) && length(Declared) == 1L && nzchar(trimws(Declared))) return(Declared)
  Parts <- c(params$params$author, params$params$consultant$name)
  Parts <- Parts[vapply(Parts, function(x) is.character(x) && length(x) == 1L && nzchar(trimws(x)), logical(1L))]
  paste(Parts, collapse = ", ")
}

.quartoBookEntries <- function(chapters) {
  lapply(quartoAsSequence(chapters), function(Entry) {
    if (!is.list(Entry)) return(Entry)
    # A length-1 part serializes as a scalar unless kept a list; the
    # Quarto schema requires a sequence.
    Entry$chapters <- quartoAsSequence(Entry$chapters)
    Entry
  })
}

.quartoChapterFiles <- function(chapters) {
  OUT <- character()
  for (Entry in quartoAsSequence(chapters)) {
    if (is.list(Entry)) OUT <- c(OUT, unlist(.quartoChapterFiles(Entry$chapters)))
    else OUT <- c(OUT, as.character(Entry))
  }
  as.list(OUT)
}

#' Convert a DOCX profile into a book profile
#'
#' Sets `project.type = "book"` in a parsed DOCX profile and validates that the
#' profile declares `format.docx`.
#'
#' @param profile Parsed DOCX profile YAML list.
#'
#' @return Modified DOCX profile list.
#' @rdname quartoYaml
#' @export
quartoDocxBookProfile <- function(profile) {
  Profile <- .quartoRequireList(profile, "profile")
  if (is.null(Profile$project) || !is.list(Profile$project)) Profile$project <- list()
  Profile$project$type <- "book"

  if (is.null(Profile$format) || is.null(Profile$format$docx)) {
    stop("quartoDocxBookProfile: profile does not define format.docx.", call. = FALSE)
  }

  Profile
}

#' Convert a Quarto config list to YAML
#'
#' Serializes YAML with Quarto-compatible YAML 1.2 booleans (`true`/`false`) and
#' sequence indentation suitable for `project.render`, `chapters`, and
#' `appendices`.
#'
#' @param x R object to serialize.
#'
#' @return Character scalar containing YAML.
#' @rdname quartoYaml
#' @export
quartoAsYaml <- function(x) {
  yaml::as.yaml(
    x,
    indent.mapping.sequence = TRUE,
    handlers = list(logical = .quartoVerbatimLogical)
  )
}

#' Write or return Quarto YAML
#'
#' @param x R object to serialize.
#' @param path Optional output path. When NULL, returns the YAML text.
#'
#' @return YAML text when `path` is NULL; otherwise invisibly returns `path`.
#' @rdname quartoYaml
#' @export
quartoWriteYaml <- function(x, path = NULL) {
  Yaml <- quartoAsYaml(x)
  if (is.null(path)) return(Yaml)

  Path <- as.character(path)
  if (length(Path) != 1L || !nzchar(Path)) {
    stop("quartoWriteYaml: path must be one non-empty value.", call. = FALSE)
  }
  cat(Yaml, file = Path)
  invisible(Path)
}

.quartoRequireList <- function(x, name) {
  if (is.null(x)) return(list())
  if (!is.list(x)) {
    stop(sprintf("%s must be a list.", name), call. = FALSE)
  }
  x
}

.quartoVerbatimLogical <- function(x) {
  Out <- ifelse(x, "true", "false")
  class(Out) <- "verbatim"
  Out
}
# nolint end
