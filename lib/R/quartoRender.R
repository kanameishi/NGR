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
      stop("Input, profile, root and manifest must be non-empty strings.", call. = FALSE)
    }
  }
  if (!profile %in% c("book", "html", "revealjs", "docx")) {
    stop("Unknown render profile: ", profile, call. = FALSE)
  }
  if (!is.character(args) || anyNA(args)) {
    stop("Quarto arguments must be a character vector without missing values.", call. = FALSE)
  }
  Root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  if (.Platform$OS.type == "windows") input <- gsub("\\", "/", input, fixed = TRUE)
  if (grepl("^(/|[A-Za-z]:)", input)) {
    stop("Input must be project-relative: ", input, call. = FALSE)
  }
  input <- sub("^(\\./)+", "", input)
  Stem <- sub("\\.md$", "", sub("\\.qmd$", "", basename(input)))
  if (!nzchar(Stem) || Stem %in% c(".", "..")) {
    stop("Cannot derive an output name from: ", input, call. = FALSE)
  }
  if (is.null(output)) output <- if (profile == "docx") "docx" else paste0("html/", Stem)
  .checkRenderOutput(profile = profile, output = output)
  Profile <- paste0("_quarto-", profile, ".yml")
  for (FILE in c(input, "yml/_quarto.yml", file.path("yml", Profile))) {
    if (!file_test("-f", file.path(Root, FILE))) {
      stop("Render input not found: ", FILE, call. = FALSE)
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
    if (!file_test("-f", "params.yml")) stop("DOCX metadata file not found: params.yml", call. = FALSE)
    Spec <- .docxSpec(Frontmatter, params = yaml::read_yaml("params.yml"),
                      date = sub("^Printed: ", "", RenderStamp), fileName = paste0(Stem, ".docx"))
  }
  Stage <- tempfile("ngr-render-")
  if (!dir.create(Stage)) stop("Cannot create render directory: ", Stage, call. = FALSE)
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
        stop("Input resolves outside the project: ", input, call. = FALSE)
      }
      FILE <- basename(input)
      if (file.exists(FILE) || isTRUE(fs::is_link(FILE))) {
        stop("Cannot hoist ", input, ": ", FILE, " also exists at the project root.", call. = FALSE)
      }
      if (!file.rename(from = input, to = FILE)) {
        stop("Cannot stage master at project root: ", input, call. = FALSE)
      }
      DATA <- readLines(FILE, warn = FALSE)
      IDX <- utils::head(grep("\\]\\(\\.\\./|[\"']\\.\\./|:[[:space:]]*\\.\\./|include[[:space:]]+\\.\\./|=\\.\\./", DATA), 3L)
      if (length(IDX)) {
        message("[render] note: ", input, " mentions parent-relative paths; resources resolve from the project root:\n",
                paste(paste0(IDX, ":", DATA[IDX]), collapse = "\n"))
      }
      FILES <- list.files(DIR)
      FILES <- FILES[!grepl("\\.(qmd|md)$", FILES)]
      if (length(FILES)) {
        message("[render] note: ", FILES[[1L]], " is beside ", input,
                "; the master resolves resources from the project root.")
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
  message("[render] ", profile, if (Book && profile == "docx") " book", " -> ", output, "/")
  .runRenderCommand("quarto", args = c(Command, args))
  FILES <- list.files("_ngr-output", all.files = TRUE, no.. = TRUE, full.names = TRUE)
  if (!any(file_test("-f", FILES) & !fs::is_link(FILES))) {
    stop("Staged output has no file at its root; keeping existing ", output, "/", call. = FALSE)
  }
  if (profile == "docx") {
    FILES <- list.files("_ngr-output", pattern = "\\.docx$", recursive = TRUE, full.names = TRUE)
    if (!length(FILES)) stop("DOCX output not found in staged output.", call. = FALSE)
    for (FILE in FILES) {
      Candidate <- paste0(FILE, ".composed")
      .runRenderCommand(Python, args = c(Composer, "compose", "--template", Template,
                        "--content", FILE, "--spec", SpecPath, "--output", Candidate))
      if (!file.rename(Candidate, FILE)) stop("Cannot replace staged DOCX: ", FILE, call. = FALSE)
    }
  }
  Destination <- file.path(Root, output)
  if (profile != "docx" && (file.exists(Destination) || isTRUE(fs::is_link(Destination)))) {
    fs::file_delete(Destination)
  }
  if (!dir.exists(Destination) && !dir.create(Destination, recursive = TRUE)) {
    stop("Cannot create output directory: ", Destination, call. = FALSE)
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
    stop("Invalid render output path for profile ", profile, ".", call. = FALSE)
  }
  invisible(NULL)
}

# Base file.copy follows links; staging must keep links and source metadata.
.copyRenderPath <- function(from, to) {
  if (isTRUE(fs::is_link(from))) {
    if (file.exists(to) || isTRUE(fs::is_link(to))) {
      if (dir.exists(to)) stop("Cannot replace directory with link: ", to, call. = FALSE)
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
      stop("Cannot copy render link: ", from, call. = FALSE)
    }
    return(invisible(to))
  }
  if (dir.exists(from)) {
    if (file.access(from, 5L) != 0L) {
      stop("Cannot read render directory: ", from, call. = FALSE)
    }
    Info <- file.info(from)
    if (!dir.exists(to) && !dir.create(to)) stop("Cannot create directory: ", to, call. = FALSE)
    for (FILE in list.files(from, all.files = TRUE, no.. = TRUE)) {
      .copyRenderPath(from = file.path(from, FILE), to = file.path(to, FILE))
    }
    if (!Sys.chmod(to, mode = Info$mode, use_umask = FALSE) || !Sys.setFileTime(to, Info$mtime)) {
      stop("Cannot preserve directory metadata: ", to, call. = FALSE)
    }
    return(invisible(to))
  }
  if (!file.copy(from = from, to = to, overwrite = TRUE, copy.mode = TRUE, copy.date = TRUE)) {
    stop("Cannot copy render resource: ", from, call. = FALSE)
  }
  if (!Sys.chmod(to, mode = file.info(from)$mode, use_umask = FALSE)) {
    stop("Cannot preserve file permissions: ", to, call. = FALSE)
  }
  invisible(to)
}

.runRenderCommand <- function(command, args) {
  if (!nzchar(Sys.which(command))) stop("Render requires ", command, " on PATH.", call. = FALSE)
  Status <- system2(command, args = shQuote(args))
  if (Status != 0L) stop(command, " failed with status ", Status, ".", call. = FALSE)
  invisible(NULL)
}
