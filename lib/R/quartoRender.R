#' Render a Quarto document in a disposable project copy
#'
#' Uses `yml/_quarto.yml` and `yml/_quarto-<profile>.yml` from the project.
#' Book masters supply chapters and appendices through their frontmatter.
#' Single-file masters are moved to the root of the disposable copy so their
#' resource paths resolve from the project root. Source files are not changed.
#'
#' @param input Project-relative QMD or Markdown master.
#' @param profile One of `book`, `html`, `revealjs` or `docx`.
#' @param root Project directory. Defaults to the current working directory.
#' @param output Output directory relative to `root`. HTML formats require
#'   `html/<name>`; DOCX requires `docx`. When `NULL`, uses `html/<master stem>`
#'   or `docx`, respectively.
#' @param args Character vector of additional arguments passed to Quarto.
#' @param manifest Path to the project provenance manifest, relative to `root`
#'   or absolute. An absent manifest produces a draft publication stamp.
#'
#' @return Invisibly, a character vector of delivered file paths.
#' @details Requires Quarto on `PATH`; DOCX also requires Python 3.9 or later
#'   with `lxml` in that interpreter (`python3`, or `python` on Windows).
#'   DOCX uses the master's `title` and `lang` (English when absent), and reads
#'   `params.client.name`, `params.consultant.name` and `params.project_id` from
#'   the project's `params.yml`. Required values are non-empty single-line
#'   strings; missing values fail before Quarto. The date is calculated for the
#'   render in `dd/mm/yyyy`, matching the print stamp. Cover labels follow
#'   English or Spanish. A master `srk` block is not read. Other Word metadata
#'   is left blank for editing in Word. The CAN inner title page uses optional
#'   `address` lists and `web` strings from the client and consultant blocks,
#'   together with the output filename. The project DOCX profile must use a
#'   CAN-compatible reference and `number-sections: true`. Each appendix file
#'   declared in `appendices` needs one numbered level-1 heading with an explicit
#'   identifier (`{#sec-...}`), which selects its separator. A book without
#'   `appendices` emits a diagnostic and receives no CAN appendix separators.
#'   Input DOCX sections within the body are currently unsupported.
#'   Preliminaries before the first Heading1 use Roman numbering; the body
#'   starts at page 1. The profile enables a Word table of contents, which may
#'   need a manual update. No field-update request is set on document opening.
#'   The installed library owns the Python compositor and semantic filters.
#'   Quarto resolves citations and cross-references once for the complete book.
#'   Rendering and composition finish before publication begins. HTML output
#'   replaces the selected directory; each DOCX replaces its destination through
#'   a sibling temporary file, keeping other documents. Publication of multiple
#'   files is not a transaction. Temporary files, the working directory and the
#'   publication-stamp environment variable are restored on ordinary exit.
#' @export
quartoRender <- function(input, profile, root = getwd(), output = NULL,
                         args = character(), manifest = "manifest.json") {
  for (x in list(input, profile, root, manifest)) {
    if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
      .fail("Input, profile, root and manifest must be non-empty strings.")
    }
  }
  if (!profile %in% c("book", "html", "revealjs", "docx")) {
    .fail("Unknown render profile: ", profile)
  }
  if (!is.character(args) || anyNA(args)) {
    .fail("Quarto arguments must be a character vector without missing values.")
  }
  Root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  if (.Platform$OS.type == "windows") input <- gsub("\\", "/", input, fixed = TRUE)
  if (grepl("^(/|[A-Za-z]:)", input)) {
    .fail("Input must be project-relative: ", input)
  }
  input <- sub("^(\\./)+", "", input)
  Stem <- sub("\\.md$", "", sub("\\.qmd$", "", basename(input)))
  if (!nzchar(Stem) || Stem %in% c(".", "..")) {
    .fail("Cannot derive an output name from: ", input)
  }
  if (is.null(output)) output <- if (profile == "docx") "docx" else paste0("html/", Stem)
  .checkRenderOutput(profile = profile, output = output)
  Profile <- paste0("_quarto-", profile, ".yml")
  for (FILE in c(input, "yml/_quarto.yml", file.path("yml", Profile))) {
    if (!file_test("-f", file.path(Root, FILE))) {
      .fail("Render input not found: ", FILE)
    }
  }

  Directory <- getwd()
  Stamp <- Sys.getenv("NGR_RENDER_STAMP", unset = NA_character_)
  setwd(Root)
  on.exit({
    setwd(Directory)
    if (is.na(Stamp)) Sys.unsetenv("NGR_RENDER_STAMP")
    if (!is.na(Stamp)) Sys.setenv(NGR_RENDER_STAMP = Stamp)
  }, add = TRUE)
  DATA <- list()
  if (file.exists(manifest)) DATA <- jsonlite::fromJSON(manifest, simplifyVector = FALSE)
  RenderStamp <- quartoRenderStamp(DATA, root = Root)
  Sys.setenv(NGR_RENDER_STAMP = RenderStamp)
  Frontmatter <- list()
  if (profile %in% c("book", "docx")) Frontmatter <- quartoReadFrontmatter(input)
  if (profile == "docx") {
    if (!file_test("-f", "params.yml")) .fail("DOCX metadata file not found: params.yml")
    Spec <- .docxSpec(Frontmatter, params = yaml::read_yaml("params.yml"),
                      date = sub("^Printed: ", "", RenderStamp), fileName = paste0(Stem, ".docx"))
  }
  Stage <- tempfile("ngr-render-")
  if (!dir.create(Stage)) .fail("Cannot create render directory: ", Stage)
  on.exit(fs::dir_delete(Stage), add = TRUE)
  for (FILE in list.files(Root, all.files = TRUE, no.. = TRUE)) {
    if (FILE %in% c("html", "docx", ".quarto", "_freeze", "_ngr-output", ".git",
                    "_quarto.yml", ".quartoignore") || grepl("^_quarto-.*\\.yml$", FILE)) next
    .copyRenderPath(from = file.path(Root, FILE), to = file.path(Stage, FILE))
  }
  writeLines(c("html/", "docx/", ".quarto/", "_freeze/", "_ngr-output/"),
             file.path(Stage, ".quartoignore"))
  setwd(Stage)
  if (profile == "docx") {
    Python <- if (.Platform$OS.type == "windows") "python" else "python3"
    Composer <- system.file("docx", "compose_docx.py", package = "NGR", mustWork = TRUE)
    Template <- system.file("docx", "srk-template.zip", package = "NGR", mustWork = TRUE)
    DocxProfile <- .docxProfile(yaml::read_yaml(file.path("yml", Profile)), module = Composer, python = Python)
    Spec$appendices <- .docxAppendices(Frontmatter)
    SpecPath <- file.path(Stage, "_ngr-docx.json")
    jsonlite::write_json(Spec, path = SpecPath, auto_unbox = TRUE, pretty = TRUE)
  }
  Book <- profile == "book" || (profile == "docx" && quartoHasBookManifest(Frontmatter))
  Config <- yaml::read_yaml("yml/_quarto.yml")
  Params <- list()
  if (file_test("-f", "params.yml")) Params <- yaml::read_yaml("params.yml")
  Command <- c("render", "--profile", profile, "--output-dir", "_ngr-output")
  if (Book) Config <- quartoMergeBookManifest(base = Config, manifest = Frontmatter)
  Identity <- .quartoFooterMeta(params = Params, config = Config)
  if (nzchar(Identity)) Config[["footer-meta"]] <- Identity
  if (Book && profile == "docx") {
    quartoWriteYaml(quartoDocxBookProfile(DocxProfile), path = Profile)
    Command <- c(Command, "--to", "docx", "--output", paste0(Stem, ".docx"))
  }
  if (!Book) {
    if (grepl("/", input, fixed = TRUE)) {
      DIR <- normalizePath(dirname(input), winslash = "/", mustWork = TRUE)
      Path <- normalizePath(Stage, winslash = "/", mustWork = TRUE)
      if (DIR != Path && !startsWith(DIR, paste0(Path, "/"))) {
        .fail("Input resolves outside the project: ", input)
      }
      FILE <- basename(input)
      if (file.exists(FILE) || isTRUE(fs::is_link(FILE))) {
        .fail("Cannot hoist ", input, ": ", FILE, " also exists at the project root.")
      }
      if (!file.rename(from = input, to = FILE)) {
        .fail("Cannot stage master at project root: ", input)
      }
      DATA <- readLines(FILE, warn = FALSE)
      IDX <- utils::head(grep("\\]\\(\\.\\./|[\"']\\.\\./|:[[:space:]]*\\.\\./|include[[:space:]]+\\.\\./|=\\.\\./", DATA), 3L)
      if (length(IDX)) {
        .inform("moduleNote", input, " mentions parent-relative paths; resources resolve from the project root:\n",
                paste(paste0(IDX, ":", DATA[IDX]), collapse = "\n"), operation = "render", path = input)
      }
      FILES <- list.files(DIR)
      FILES <- FILES[!grepl("\\.(qmd|md)$", FILES)]
      if (length(FILES)) {
        .inform("moduleNote", FILES[[1L]], " is beside ", input,
                "; the master resolves resources from the project root.", operation = "render", path = input)
      }
      input <- FILE
    }
    Config <- quartoSetProjectRender(base = Config, render = input)
    Command <- c("render", input, "--profile", profile, "--to", profile,
                 "--output-dir", "_ngr-output")
  }
  quartoWriteYaml(Config, path = "_quarto.yml")
  if (profile == "docx" && !Book) quartoWriteYaml(DocxProfile, path = Profile)
  if (profile != "docx") {
    .copyRenderPath(from = file.path("yml", Profile), to = Profile)
  }
  .inform("moduleProgress", "Rendering ", profile, if (Book && profile == "docx") " book", " -> ", output, "/",
          operation = "render", path = output)
  .runRenderCommand("quarto", args = c(Command, args))
  FILES <- list.files("_ngr-output", all.files = TRUE, no.. = TRUE, full.names = TRUE)
  if (!any(file_test("-f", FILES) & !fs::is_link(FILES))) {
    .fail("Staged output has no file at its root; keeping existing ", output, "/")
  }
  if (profile == "docx") {
    FILES <- list.files("_ngr-output", pattern = "\\.docx$", recursive = TRUE, full.names = TRUE)
    if (!length(FILES)) .fail("DOCX output not found in staged output.")
    for (FILE in FILES) {
      Candidate <- paste0(FILE, ".composed")
      .runRenderCommand(Python, args = c(Composer, "compose", "--template", Template,
                        "--content", FILE, "--spec", SpecPath, "--output", Candidate))
      if (!file.rename(Candidate, FILE)) .fail("Cannot replace staged DOCX: ", FILE)
    }
  }
  Destination <- file.path(Root, output)
  if (profile != "docx" && (file.exists(Destination) || isTRUE(fs::is_link(Destination)))) {
    fs::file_delete(Destination)
  }
  if (!dir.exists(Destination) && !dir.create(Destination, recursive = TRUE)) {
    .fail("Cannot create output directory: ", Destination)
  }
  for (FILE in list.files("_ngr-output", all.files = TRUE, no.. = TRUE)) {
    if (profile == "docx" && grepl("[.]docx$", FILE)) {
      .replaceResource(from = file.path("_ngr-output", FILE), to = file.path(Destination, FILE))
    }
    if (!(profile == "docx" && grepl("[.]docx$", FILE))) {
      .copyRenderPath(from = file.path("_ngr-output", FILE), to = file.path(Destination, FILE))
    }
  }
  FILES <- list.files("_ngr-output", all.files = TRUE, recursive = TRUE)
  invisible(file.path(Destination, FILES))
}

.checkRenderOutput <- function(profile, output) {
  if (!is.character(output) || length(output) != 1L || is.na(output) ||
      (profile == "docx" && output != "docx") ||
      (profile != "docx" && (!grepl("^html/[^/\\\\]+$", output) ||
                             basename(output) %in% c(".", "..")))) {
    .fail("Invalid render output path for profile ", profile, ".")
  }
  invisible(NULL)
}

# Base file.copy follows links; staging must keep links and source metadata.
.copyRenderPath <- function(from, to) {
  if (isTRUE(fs::is_link(from))) {
    if (file.exists(to) || isTRUE(fs::is_link(to))) {
      if (dir.exists(to)) .fail("Cannot replace directory with link: ", to)
      fs::file_delete(to)
    }
    if (.Platform$OS.type == "windows") {
      # R cannot request unprivileged Windows symlinks; fs creates junctions.
      .runRenderCommand("python", args = c("-c", paste0(
        "import os, stat, sys; os.symlink(os.readlink(sys.argv[1]), sys.argv[2], ",
        "target_is_directory=bool(os.lstat(sys.argv[1]).st_file_attributes & stat.FILE_ATTRIBUTE_DIRECTORY))"
      ), from, to))
    }
    if (.Platform$OS.type != "windows" && !file.symlink(from = fs::link_path(from), to = to)) {
      .fail("Cannot copy render link: ", from)
    }
    return(invisible(to))
  }
  if (dir.exists(from)) {
    if (file.access(from, 5L) != 0L) {
      .fail("Cannot read render directory: ", from)
    }
    Info <- file.info(from)
    if (!dir.exists(to) && !dir.create(to)) .fail("Cannot create directory: ", to)
    for (FILE in list.files(from, all.files = TRUE, no.. = TRUE)) {
      .copyRenderPath(from = file.path(from, FILE), to = file.path(to, FILE))
    }
    if (!Sys.chmod(to, mode = Info$mode, use_umask = FALSE) || !Sys.setFileTime(to, Info$mtime)) {
      .fail("Cannot preserve directory metadata: ", to)
    }
    return(invisible(to))
  }
  if (!file.copy(from = from, to = to, overwrite = TRUE, copy.mode = TRUE, copy.date = TRUE)) {
    .fail("Cannot copy render resource: ", from)
  }
  if (!Sys.chmod(to, mode = file.info(from)$mode, use_umask = FALSE)) {
    .fail("Cannot preserve file permissions: ", to)
  }
  invisible(to)
}

.runRenderCommand <- function(command, args) {
  if (!nzchar(Sys.which(command))) .fail("Render requires ", command, " on PATH.")
  Status <- system2(command, args = shQuote(args))
  if (Status != 0L) .fail(command, " failed with status ", Status, ".")
  invisible(NULL)
}
