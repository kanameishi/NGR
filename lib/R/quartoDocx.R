# Private contract between project metadata, Pandoc and the CAN compositor.
.docxSpec <- function(frontmatter, params, date, fileName) {
  Keys <- c(client = "params.client.name", company = "params.consultant.name", project = "params.project_id")
  Values <- list(title = frontmatter$title, date = date)
  for (Name in names(Keys)) {
    x <- params
    for (s in strsplit(Keys[[Name]], ".", fixed = TRUE)[[1L]]) {
      if (!is.list(x)) {
        x <- NULL
        break
      }
      x <- x[[s]]
    }
    Values[Name] <- list(x)
  }
  for (Name in names(Values)) {
    x <- Values[[Name]]
    if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(trimws(x)) || grepl("[[:cntrl:]]", x)) {
      Source <- paste0(Name, " in the DOCX master")
      if (Name %in% names(Keys)) Source <- paste0(Keys[[Name]], " in params.yml")
      if (Name == "date") Source <- "date in the render stamp"
      .fail("DOCX requires ", Source, " as a non-empty single-line string.")
    }
  }
  Language <- frontmatter$lang
  if (is.null(Language)) Language <- "en"
  if (!is.character(Language) || length(Language) != 1L || is.na(Language) || !grepl("^(en|es)(-|$)", Language)) {
    .fail("DOCX master lang must be en or es (a regional suffix is allowed).")
  }
  Cover <- list(title = Values$title, client = Values$client, company = Values$company,
                issue = Values$project, date = Values$date)
  TitlePage <- list(clientAddress = list(), companyAddress = list(),
                    clientWeb = "", companyWeb = "", fileName = fileName)
  for (Name in c("client", "consultant")) {
    Key <- if (Name == "client") "client" else "company"
    for (Field in c("address", "web")) {
      x <- params$params[[Name]][[Field]]
      if (is.null(x)) next
      if (Field == "web") x <- list(x)
      if (!(is.list(x) || is.character(x)) || any(!vapply(x, function(s) {
        is.character(s) && length(s) == 1L && !is.na(s) && !grepl("[[:cntrl:]]", s)
      }, logical(1L)))) {
        .fail("Invalid params.", Name, ".", Field, " in params.yml: expected single-line text",
              if (Field == "address") " entries." else ".")
      }
      if (Field == "address") TitlePage[[paste0(Key, "Address")]] <- as.list(x)
      if (Field == "web") TitlePage[[paste0(Key, "Web")]] <- x[[1L]]
    }
  }
  list(cover = Cover, headerFooter = Values[c("title", "date", "project", "company")],
       titlePage = TitlePage, appendices = list(), lang = sub("-.*$", "", Language))
}

.docxAppendices <- function(frontmatter) {
  OUT <- list()
  for (FILE in .quartoChapterFiles(frontmatter$appendices)) {
    Path <- normalizePath(FILE, winslash = "/", mustWork = TRUE)
    Root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
    if (!startsWith(Path, paste0(Root, "/"))) {
      .fail("Appendix resolves outside the staged project: ", FILE)
    }
    Json <- tempfile("ngr-appendix-", fileext = ".json")
    on.exit(unlink(Json), add = TRUE)
    .runRenderCommand("quarto", args = c("pandoc", FILE, "--from", "markdown-auto_identifiers", "--to", "json", "--output", Json))
    DATA <- jsonlite::fromJSON(Json, simplifyVector = FALSE)$blocks
    Headers <- Filter(function(x) identical(x$t, "Header") && identical(x$c[[1L]], 1L), DATA)
    if (length(Headers) != 1L || !nzchar(Headers[[1L]]$c[[2L]][[1L]])) {
      .fail("Each appendix file requires one level-1 heading with an explicit identifier: ", FILE)
    }
    if ("unnumbered" %in% unlist(Headers[[1L]]$c[[2L]][[2L]])) {
      .fail("Appendix heading must be numbered so Quarto can resolve its letter and references: ", FILE)
    }
    OUT[[length(OUT) + 1L]] <- list(bookmark = Headers[[1L]]$c[[2L]][[1L]])
    unlink(Json)
  }
  Ids <- vapply(OUT, function(x) x$bookmark, character(1L))
  if (anyDuplicated(Ids)) .fail("Appendix heading identifiers must be unique.")
  if (!length(OUT) && quartoHasBookManifest(frontmatter)) {
    .inform("moduleNote", "DOCX book: no appendices declared; CAN separators require appendices in the master.",
            operation = "render", phase = "docx")
  }
  OUT
}

.docxProfile <- function(profile, module, python) {
  Reference <- profile$format$docx$`reference-doc`
  if (!is.character(Reference) || length(Reference) != 1L || !nzchar(Reference)) {
    .fail("DOCX profile requires an explicit CAN-compatible reference-doc.")
  }
  Filters <- unlist(profile$format$docx$filters, use.names = FALSE)
  if (any(grepl("(^|/)appendix-style[.]lua$", Filters))) {
    .fail("The DOCX profile still uses appendix-style.lua. Migrate yml/_quarto-docx.yml before rendering CAN.")
  }
  .runRenderCommand(python, args = c(module, "check-reference", "--reference", Reference))
  if (!isTRUE(profile$format$docx$`number-sections`)) {
    .fail("CAN DOCX requires number-sections: true; Quarto owns heading and cross-reference numbers.")
  }
  profile$format$docx$filters <- c(profile$format$docx$filters, list(
    list(at = "pre-quarto", path = system.file("docx", "styles.lua", package = "NGR", mustWork = TRUE)),
    list(at = "post-quarto", path = system.file("docx", "layout.lua", package = "NGR", mustWork = TRUE))))
  profile
}
