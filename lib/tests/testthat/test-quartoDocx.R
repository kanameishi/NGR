test_that("DOCX metadata comes from project params and the render date", {
  Spec <- getFromNamespace(".docxSpec", "NGR")
  Master <- list(title = "Formato de informes SRK", lang = "es")
  Params <- list(params = list(client = list(name = "Verificación del formato documental"),
    consultant = list(name = "SRK Consulting (Argentina) S.A."), project_id = "NGR"))
  Date <- format(Sys.Date(), "%d/%m/%Y")
  OUT <- Spec(Master, params = Params, date = Date, fileName = "document.docx")
  expect_identical(OUT$cover, list(title = Master$title, client = Params$params$client$name,
    company = Params$params$consultant$name, issue = "NGR", date = Date))
  expect_identical(OUT$headerFooter$date, Date)
  expect_identical(OUT$lang, "es")
  expect_identical(OUT$appendices, list())
  expect_identical(OUT$titlePage, list(clientAddress = list(), companyAddress = list(),
    clientWeb = "", companyWeb = "", fileName = "document.docx"))
  DATA <- Params
  DATA$params$client$address <- c("Av. Emilio Civit 404", "Mendoza")
  DATA$params$consultant$web <- "https://www.srk.com"
  Details <- Spec(Master, params = DATA, date = Date, fileName = "document.docx")$titlePage
  expect_identical(Details$clientAddress, as.list(DATA$params$client$address))
  expect_identical(Details$companyWeb, DATA$params$consultant$web)
  for (x in list(123, list("line", NA_character_), list(list("nested")), "line\nbreak")) {
    DATA$params$client$address <- x
    expect_error(Spec(Master, params = DATA, date = Date, fileName = "document.docx"),
      "params.client.address", fixed = TRUE)
  }
  Master$srk <- list(title = "Ignored", client = "Ignored", date = "Ignored")
  expect_identical(Spec(Master, params = Params, date = Date, fileName = "document.docx"), OUT)
  Master$lang <- NULL
  expect_identical(Spec(Master, params = Params, date = Date, fileName = "document.docx")$lang, "en")
  Master$lang <- "es-AR"
  expect_identical(Spec(Master, params = Params, date = Date, fileName = "document.docx")$lang, "es")
  Master$lang <- "en-CA"
  expect_identical(Spec(Master, params = Params, date = Date, fileName = "document.docx")$lang, "en")
  for (x in list("unsupported", NA_character_, list("es"))) {
    Master$lang <- x
    expect_error(Spec(Master, params = Params, date = Date, fileName = "document.docx"), "lang must")
  }
  Master$lang <- "es"
  for (Key in list(c("client", "name"), c("consultant", "name"), "project_id")) {
    for (x in list(NULL, "", NA_character_, 123, list("value"), "line\nbreak")) {
      DATA <- Params
      DATA$params[[Key]] <- x
      expect_error(Spec(Master, params = DATA, date = Date, fileName = "document.docx"),
        paste0("params.", paste(Key, collapse = "."), " in params.yml"), fixed = TRUE)
    }
  }
  Master$title <- NULL
  expect_error(Spec(Master, params = Params, date = Date, fileName = "document.docx"), "title in the DOCX master", fixed = TRUE)
})

test_that("missing project metadata fails before staging or launching Quarto", {
  Root <- tempfile("ngr-docx-params-")
  dir.create(Root)
  on.exit(unlink(Root, recursive = TRUE), add = TRUE)
  dir.create(file.path(Root, "yml"))
  writeLines(c("---", "title: Formato de informes SRK", "---"), file.path(Root, "document.qmd"))
  for (Name in c("_quarto.yml", "_quarto-docx.yml")) writeLines("{}", file.path(Root, "yml", Name))
  testthat::local_mocked_bindings(
    .copyRenderPath = function(...) stop("Unexpected staging"),
    .runRenderCommand = function(...) stop("Unexpected process"), .package = "NGR")
  expect_error(NGR::quartoRender("document.qmd", profile = "docx", root = Root),
    "DOCX metadata file not found: params.yml", fixed = TRUE)
  for (Params in list(list(), list(params = list()), list(params = list(client = "invalid")))) {
    yaml::write_yaml(Params, file.path(Root, "params.yml"))
    expect_error(NGR::quartoRender("document.qmd", profile = "docx", root = Root),
      "params.client.name in params.yml", fixed = TRUE)
    expect_false(dir.exists(file.path(Root, "docx")))
  }
})

test_that("appendix identity uses Pandoc and flattens part entries", {
  skip_if(!nzchar(Sys.which("quarto")))
  Root <- tempfile("ngr-appendices-")
  dir.create(Root)
  Directory <- getwd()
  on.exit({setwd(Directory); unlink(Root, recursive = TRUE)}, add = TRUE)
  setwd(Root)
  writeLines("# Catálogo de objetos {#sec-apx-a}", "a.qmd")
  writeLines("# Tablas y notas {#sec-apx-b}", "b.qmd")
  Appendices <- getFromNamespace(".docxAppendices", "NGR")
  Master <- list(appendices = list(list(part = "Apéndices", chapters = list("a.qmd", "b.qmd"))))
  expect_identical(Appendices(Master), list(list(bookmark = "sec-apx-a"), list(bookmark = "sec-apx-b")))
  expect_identical(Appendices(list()), list())
  expect_message(Appendices(list(chapters = "index.qmd")), "no appendices declared", fixed = TRUE, class = "moduleNote")
  writeLines("# Tablas y notas {#sec-apx-a}", "b.qmd")
  expect_error(Appendices(Master), "unique")
  writeLines("# Tablas y notas {#sec-apx-b .unnumbered}", "b.qmd")
  expect_error(Appendices(Master), "must be numbered")
  writeLines("# Tablas y notas", "b.qmd")
  expect_error(Appendices(Master), "one level-1")
  writeLines(c("# One", "# Two"), "b.qmd")
  expect_error(Appendices(Master), "one level-1")
})

test_that("installed DOCX API composes a single master and fails without replacing output", {
  skip_if(!nzchar(Sys.which("quarto")))
  Root <- tempfile("ngr docx á ")
  dir.create(Root)
  on.exit(unlink(Root, recursive = TRUE), add = TRUE)
  dir.create(file.path(Root, "yml"))
  dir.create(file.path(Root, "styles"))
  dir.create(file.path(Root, "_master"))
  file.copy(system.file("docx", "reference.docx", package = "NGR", mustWork = TRUE),
            file.path(Root, "styles/reference.docx"))
  writeLines("project: {type: default}", file.path(Root, "yml/_quarto.yml"))
  writeLines(c("format:", "  docx:", "    reference-doc: styles/reference.docx", "    number-sections: true"),
             file.path(Root, "yml/_quarto-docx.yml"))
  Master <- c("---", "title: Formato de informes SRK", "lang: es", "---", "", "# Results", "", "A render sentinel.")
  Params <- c("params:", "  client: {name: Verificación del formato documental}",
    "  consultant: {name: SRK Consulting (Argentina) S.A.}", "  project_id: NGR")
  writeLines(Params, file.path(Root, "params.yml"))
  Input <- file.path(Root, "_master/document.qmd")
  writeLines(Master, Input)
  Directory <- getwd()
  Stamp <- Sys.getenv("NGR_RENDER_STAMP", unset = NA_character_)
  Stage <- list.files(tempdir(), pattern = "^ngr-render-")
  Before <- tools::md5sum(c(Input, file.path(Root, "params.yml")))
  OUT <- NGR::quartoRender("_master/document.qmd", profile = "docx", root = Root, args = "--quiet")
  Output <- file.path(Root, "docx/document.docx")
  expect_true(normalizePath(Output, winslash = "/") %in% OUT)
  expect_identical(tools::md5sum(c(Input, file.path(Root, "params.yml"))), Before)
  Parts <- unzip(Output, list = TRUE)$Name
  expect_true("word/srk-composition.json" %in% Parts)
  Connection <- unz(Output, "word/srk-composition.json")
  DATA <- jsonlite::fromJSON(paste(readLines(Connection), collapse = "\n"))
  close(Connection)
  expect_length(DATA$appendices, 0L)
  expect_true(DATA$titleRemoved)
  Connection <- unz(Output, "word/document.xml")
  Text <- paste(readLines(Connection, warn = FALSE), collapse = "\n")
  close(Connection)
  expect_match(Text, "Preparado para", fixed = TRUE)
  expect_match(Text, "Preparado por", fixed = TRUE)
  expect_match(Text, format(Sys.Date(), "%d/%m/%Y"), fixed = TRUE)
  Hash <- tools::md5sum(Output)
  writeLines(Params[-2L], file.path(Root, "params.yml"))
  expect_error(NGR::quartoRender("_master/document.qmd", profile = "docx", root = Root),
    "params.client.name in params.yml", fixed = TRUE)
  expect_identical(tools::md5sum(Output), Hash)
  writeLines(Params, file.path(Root, "params.yml"))
  # A real unsupported body section fails in Python after Quarto has rendered.
  writeLines(c(Master, "", "```{=openxml}", "<w:p><w:pPr><w:sectPr/></w:pPr></w:p>", "```"), Input)
  expect_error(NGR::quartoRender("_master/document.qmd", profile = "docx", root = Root, args = "--quiet"), "failed with status")
  expect_identical(tools::md5sum(Output), Hash)
  expect_identical(getwd(), Directory)
  expect_identical(Sys.getenv("NGR_RENDER_STAMP", unset = NA_character_), Stamp)
  expect_identical(list.files(tempdir(), pattern = "^ngr-render-"), Stage)
  writeLines(Master, Input)
  testthat::local_mocked_bindings(.runRenderCommand = function(command, args) stop("Python dependency absent"), .package = "NGR")
  expect_error(NGR::quartoRender("_master/document.qmd", profile = "docx", root = Root), "Python dependency absent")
  expect_identical(tools::md5sum(Output), Hash)
  expect_identical(getwd(), Directory)
  expect_identical(Sys.getenv("NGR_RENDER_STAMP", unset = NA_character_), Stamp)
  expect_identical(list.files(tempdir(), pattern = "^ngr-render-"), Stage)
})

test_that("DOCX delivery retains the previous file when the sibling copy fails", {
  Root <- tempfile("ngr-replace-")
  dir.create(Root)
  on.exit(unlink(Root, recursive = TRUE), add = TRUE)
  Target <- file.path(Root, "report.docx")
  writeLines("previous output", Target)
  expect_error(getFromNamespace(".replaceResource", "NGR")(
    from = file.path(Root, "missing.docx"), to = Target), "Cannot replace")
  expect_identical(readLines(Target), "previous output")
  expect_identical(list.files(Root, all.files = TRUE, no.. = TRUE), "report.docx")
})
