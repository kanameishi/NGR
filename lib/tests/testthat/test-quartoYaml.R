test_that("quartoReadFrontmatter reads qrt-style manifest fields", {
  Fixture <- testthat::test_path("fixtures", "qrt-yaml")
  Frontmatter <- quartoReadFrontmatter(file.path(Fixture, "book-single.qmd"))

  expect_identical(Frontmatter$title, "Single Chapter")
  expect_identical(Frontmatter$chapters, "_chapters/intro.qmd")
  expect_identical(Frontmatter$bibliography, "bib/references.bib")
  expect_true(quartoHasBookManifest(Frontmatter))
})

test_that("quartoReadFrontmatter returns empty list for non-manifest files", {
  Fixture <- testthat::test_path("fixtures", "qrt-yaml")

  expect_identical(quartoReadFrontmatter(file.path(Fixture, "plain.qmd")), list())
  expect_false(quartoHasBookManifest(quartoReadFrontmatter(file.path(Fixture, "title-only.qmd"))))
})

test_that("quartoMergeBookManifest preserves single-entry sequences", {
  Fixture <- testthat::test_path("fixtures", "qrt-yaml")
  Base <- yaml::read_yaml(file.path(Fixture, "base.yml"))
  Manifest <- quartoReadFrontmatter(file.path(Fixture, "book-single.qmd"))
  Merged <- quartoMergeBookManifest(Base, Manifest)

  expect_true(is.list(Merged$book$chapters))
  expect_length(Merged$book$chapters, 1)
  expect_identical(Merged$book$chapters[[1]], "_chapters/intro.qmd")
  expect_true(is.list(Merged$project$render))
  expect_identical(Merged$project$render[[1]], "_chapters/intro.qmd")

  Yaml <- quartoAsYaml(Merged)
  expect_match(Yaml, "preview: false", fixed = TRUE)
  expect_match(Yaml, "echo: true", fixed = TRUE)
  expect_match(Yaml, "chapters:\n    - _chapters/intro.qmd")
  expect_match(Yaml, "render:\n    - _chapters/intro.qmd")
  expect_false(grepl(": yes($|\\n)|: no($|\\n)", Yaml))
})

test_that("quartoMergeBookManifest merges chapters, appendices, and bibliography", {
  Fixture <- testthat::test_path("fixtures", "qrt-yaml")
  Base <- yaml::read_yaml(file.path(Fixture, "base.yml"))
  Manifest <- quartoReadFrontmatter(file.path(Fixture, "book-multi.qmd"))
  Merged <- quartoMergeBookManifest(Base, Manifest)

  expect_identical(Merged$book$title, "Multi Chapter")
  expect_equal(unlist(Merged$book$chapters, use.names = FALSE), c(
    "_chapters/intro.qmd",
    "_chapters/methods.qmd"
  ))
  expect_equal(unlist(Merged$book$appendices, use.names = FALSE), "_appendices/data.qmd")
  expect_equal(unlist(Merged$project$render, use.names = FALSE), c(
    "_chapters/intro.qmd",
    "_chapters/methods.qmd",
    "_appendices/data.qmd"
  ))
  expect_equal(Merged$bibliography, c("bib/main.bib", "bib/extra.bib"))
})

test_that("quartoMergeBookManifest keeps parts in book.chapters and flattens render", {
  Fixture <- testthat::test_path("fixtures", "qrt-yaml")
  Base <- yaml::read_yaml(file.path(Fixture, "base.yml"))
  Manifest <- quartoReadFrontmatter(file.path(Fixture, "book-parts.qmd"))
  Merged <- quartoMergeBookManifest(Base, Manifest)

  expect_identical(Merged$book$chapters[[1]], "index.qmd")
  expect_identical(Merged$book$chapters[[2]]$part, "Part I")
  expect_equal(unlist(Merged$book$chapters[[2]]$chapters, use.names = FALSE), c(
    "_chapters/intro.qmd",
    "_chapters/methods.qmd"
  ))
  expect_true(is.list(Merged$book$chapters[[3]]$chapters))
  expect_length(Merged$book$chapters[[3]]$chapters, 1)
  expect_equal(unlist(Merged$project$render, use.names = FALSE), c(
    "index.qmd",
    "_chapters/intro.qmd",
    "_chapters/methods.qmd",
    "_chapters/results.qmd",
    "_appendices/data.qmd"
  ))

  expect_true(all(vapply(Merged$project$render, is.character, logical(1))))

  Yaml <- quartoAsYaml(Merged)
  expect_match(Yaml, "chapters:\n        - _chapters/results.qmd")
})

test_that("quartoSetProjectRender sets render targets without touching other fields", {
  Fixture <- testthat::test_path("fixtures", "qrt-yaml")
  Base <- yaml::read_yaml(file.path(Fixture, "base.yml"))
  Rendered <- quartoSetProjectRender(Base, "report.qmd")

  expect_identical(Rendered$project$type, "default")
  expect_true(is.list(Rendered$project$render))
  expect_identical(Rendered$project$render[[1]], "report.qmd")
})

test_that("book language survives excluding the master from rendered chapters", {
  Base <- list(lang = "en", project = list(type = "book"))
  Manifest <- list(title = "Informe", lang = "es-AR", chapters = "index.qmd")
  Merged <- quartoMergeBookManifest(Base, Manifest)
  expect_identical(Merged$lang, "es-AR")
  expect_identical(Merged$project$render, list("index.qmd"))
  Manifest$lang <- NULL
  expect_identical(quartoMergeBookManifest(Base, Manifest)$lang, "en")
})

test_that("quartoDocxBookProfile sets book type and validates docx format", {
  Fixture <- testthat::test_path("fixtures", "qrt-yaml")
  Profile <- yaml::read_yaml(file.path(Fixture, "docx.yml"))
  Out <- quartoDocxBookProfile(Profile)

  expect_identical(Out$project$type, "book")
  expect_true(Out$format$docx$toc)
  expect_false(Out$format$docx$`number-sections`)

  Bad <- yaml::read_yaml(file.path(Fixture, "docx-missing-format.yml"))
  expect_error(quartoDocxBookProfile(Bad), "format.docx")
})

test_that("quartoWriteYaml returns or writes exact YAML text", {
  X <- list(project = list(preview = FALSE, render = list("report.qmd")))
  Text <- quartoWriteYaml(X)
  File <- tempfile("ngr-quarto-yaml-", fileext = ".yml")

  expect_match(Text, "preview: false", fixed = TRUE)
  expect_match(Text, "render:\n    - report.qmd")
  quartoWriteYaml(X, File)
  expect_identical(readChar(File, file.info(File)$size), Text)
})

test_that("quartoMergeBookManifest carries the author and the footer keys of the master", {
  Fixture <- testthat::test_path("fixtures", "qrt-yaml")
  Base <- yaml::read_yaml(file.path(Fixture, "base.yml"))
  Manifest <- quartoReadFrontmatter(file.path(Fixture, "book-multi.qmd"))
  Manifest$author <- "A. Author"
  Manifest[["footer-meta"]] <- "Declared identity"
  Merged <- quartoMergeBookManifest(Base, Manifest)
  expect_identical(Merged$book$author, "A. Author")
  expect_identical(Merged[["footer-meta"]], "Declared identity")
  expect_null(Merged[["footer-title"]])
})

test_that(".quartoFooterMeta prefers a declared footer-meta, then params.yml, then nothing", {
  Params <- list(params = list(author = "A. Author", consultant = list(name = "An Institution")))
  expect_identical(.quartoFooterMeta(params = Params, config = list(`footer-meta` = "Declared identity")),
                   "Declared identity")
  expect_identical(.quartoFooterMeta(params = Params, config = list()), "A. Author, An Institution")
  expect_identical(.quartoFooterMeta(params = list(params = list(consultant = list(name = "A Company"))), config = list()),
                   "A Company")
  expect_identical(.quartoFooterMeta(params = list(params = list(author = "A. Author")), config = list()), "A. Author")
  expect_identical(.quartoFooterMeta(params = list(), config = list(`footer-meta` = "")), "")
  expect_identical(.quartoFooterMeta(params = list(params = list(author = "")), config = list()), "")
})

test_that("quartoMergeBookManifest lets the master override language keys and merge crossref", {
  Base <- list(lang = "es", `toc-title` = "Contenido", language = "styles/_language-es.yml",
               crossref = list(`tbl-title` = "Tabla", `fig-title` = "Figura"))
  Manifest <- list(title = "Mathematical Basis", lang = "en", `toc-title` = "Contents",
                   language = "styles/_language-en.yml",
                   crossref = list(`tbl-title` = "Table"), chapters = list("index.en.qmd"))
  Merged <- quartoMergeBookManifest(base = Base, manifest = Manifest)
  expect_identical(Merged$lang, "en")
  expect_identical(Merged[["toc-title"]], "Contents")
  expect_identical(Merged$language, "styles/_language-en.yml")
  expect_identical(Merged$crossref, list(`tbl-title` = "Table", `fig-title` = "Figura"))
  Untouched <- quartoMergeBookManifest(base = Base, manifest = list(chapters = list("a.qmd")))
  expect_identical(Untouched[["toc-title"]], "Contenido")
  expect_identical(Untouched$crossref, Base$crossref)
})
