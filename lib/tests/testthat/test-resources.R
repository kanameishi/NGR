resourceFixture <- function() {
  Root <- tempfile("resources-")
  dir.create(Root)
  Project <- file.path(Root, "project with spaces")
  Source <- file.path(Root, "source with spaces")
  dir.create(Project)
  dir.create(Source)
  writeLines("one", file.path(Source, "first.txt"))
  writeLines("two", file.path(Source, "second.txt"))
  Manifest <- file.path(Source, "manifest.json")
  jsonlite::write_json(list(schemaVersion = 1L, id = "fixture", resources = list(
    list(from = "first.txt", to = "nested/first.txt", ownership = "managed"),
    list(from = "second.txt", to = "nested/second.txt", ownership = "managed")
  )), Manifest, auto_unbox = TRUE)
  list(root = Root, project = Project, source = Source, manifest = Manifest)
}

test_that("public resource operations preserve receipt shapes and project metadata", {
  Fixture <- resourceFixture()
  on.exit(unlink(Fixture$root, recursive = TRUE), add = TRUE)
  Result <- pullResources(from = Fixture$manifest, root = Fixture$project, dryRun = TRUE)
  expect_identical(Result$actions$action, c("create", "create"))
  expect_length(list.files(Fixture$project, all.files = TRUE, no.. = TRUE), 0L)
  pullResources(from = Fixture$manifest, root = Fixture$project)
  Manifest <- file.path(Fixture$project, "manifest.json")
  Project <- jsonlite::fromJSON(Manifest, simplifyVector = FALSE)
  expect_identical(Project$artifacts, list())
  expect_identical(Project$scaffolds$fixture$selection, list())
  expect_identical(Project$scaffolds$fixture$checks, list())
  Project$owner <- list(unused = NULL, precision = 1.12345678901234,
                         nested = list(array = list("x"), object = stats::setNames(list(), character())))
  jsonlite::write_json(Project, Manifest, auto_unbox = TRUE, digits = NA, null = "null")
  pullResources(root = Fixture$project)
  Result <- jsonlite::fromJSON(Manifest, simplifyVector = FALSE)
  expect_identical(Result$owner, Project$owner)
  expect_identical(Result$scaffolds$fixture$files, Project$scaffolds$fixture$files)
  expect_false(compareResources(root = Fixture$project)$changed)
})

test_that("a failed write restores all project bytes and leaves inputs intact", {
  Fixture <- resourceFixture()
  on.exit(unlink(Fixture$root, recursive = TRUE), add = TRUE)
  pullResources(from = Fixture$manifest, root = Fixture$project)
  Paths <- list.files(Fixture$project, recursive = TRUE, full.names = TRUE)
  Before <- tools::md5sum(Paths)
  writeLines("changed", file.path(Fixture$source, "first.txt"))
  writeLines("changed too", file.path(Fixture$source, "second.txt"))
  Replace <- .replaceResource
  local_mocked_bindings(.package = "NGR", .replaceResource = function(from, to) {
    if (basename(to) == "second.txt") stop("injected write failure")
    Replace(from = from, to = to)
  })
  expect_error(pullResources(root = Fixture$project, force = TRUE), "injected write failure")
  expect_identical(tools::md5sum(Paths), Before)
  expect_identical(list.files(Fixture$project, recursive = TRUE, full.names = TRUE), Paths)
  expect_identical(readLines(file.path(Fixture$source, "first.txt")), "changed")
})

test_that("failed incorporation removes only newly created paths", {
  Fixture <- resourceFixture()
  on.exit(unlink(Fixture$root, recursive = TRUE), add = TRUE)
  writeLines("keep", file.path(Fixture$project, "extra.txt"))
  Replace <- .replaceResource
  local_mocked_bindings(.package = "NGR", .replaceResource = function(from, to) {
    if (basename(to) == "second.txt") stop("injected write failure")
    Replace(from = from, to = to)
  })
  expect_error(pullResources(from = Fixture$manifest, root = Fixture$project), "injected write failure")
  expect_identical(list.files(Fixture$project, all.files = TRUE, no.. = TRUE), "extra.txt")
  expect_identical(readLines(file.path(Fixture$project, "extra.txt")), "keep")
})

test_that("declared checks use argument vectors and restore the caller directory", {
  Fixture <- resourceFixture()
  on.exit(unlink(Fixture$root, recursive = TRUE), add = TRUE)
  Manifest <- jsonlite::fromJSON(Fixture$manifest, simplifyVector = FALSE)
  Script <- file.path(Fixture$root, "check resources.R")
  writeLines('stopifnot(file.exists("nested/first.txt"), identical(commandArgs(TRUE), "a b;$(bad)"))', Script)
  Manifest$checks <- list(list(file.path(R.home("bin"), "Rscript"), Script, "a b;$(bad)"))
  jsonlite::write_json(Manifest, Fixture$manifest, auto_unbox = TRUE)
  pullResources(from = Fixture$manifest, root = Fixture$project)
  WD <- getwd()
  expect_message(Result <- checkResources(root = Fixture$project), "^fixture: ", class = "moduleProgress")
  expect_identical(Result[[1L]]$status, 0L)
  expect_identical(getwd(), WD)
  writeLines('stop("declared failure")', Script)
  expect_error(suppressMessages(checkResources(root = Fixture$project)), "Source check failed", class = "moduleFailure")
  expect_identical(getwd(), WD)
})

test_that("Unicode claims and exact artifact metadata follow source compatibility", {
  Fixture <- resourceFixture()
  on.exit(unlink(Fixture$root, recursive = TRUE), add = TRUE)
  Manifest <- jsonlite::fromJSON(Fixture$manifest, simplifyVector = FALSE)
  Manifest$resources[[1L]]$to <- "stra\u00dfe.txt"
  Manifest$resources[[2L]]$to <- "STRASSE.txt"
  jsonlite::write_json(Manifest, Fixture$manifest, auto_unbox = TRUE)
  expect_error(pullResources(from = Fixture$manifest, root = Fixture$project), "Source conflict")
  expect_length(list.files(Fixture$project, all.files = TRUE, no.. = TRUE), 0L)
  expect_true(.sameResourceValue(list(a = list(x = 1, y = "z")), list(a = list(y = "z", x = 1))))
  expect_false(.sameResourceValue(list(x = 1), list(x = 1 + 1e-12)))
  expect_false(.sameResourceValue(list(), stats::setNames(list(), character())))
})

test_that("an explicit source manifest re-points an associated source", {
  Fixture <- resourceFixture()
  on.exit(unlink(Fixture$root, recursive = TRUE), add = TRUE)
  pullResources(from = Fixture$manifest, root = Fixture$project)
  Copy <- file.path(Fixture$root, "relocated source")
  dir.create(Copy)
  file.copy(list.files(Fixture$source, full.names = TRUE), Copy)
  writeLines("relocated", file.path(Copy, "first.txt"))
  Manifest <- file.path(Copy, "manifest.json")
  expect_error(pullResources(from = Manifest, root = Fixture$project), "require --force")
  expect_message(pullResources(from = Manifest, root = Fixture$project, force = TRUE), "fixture")
  expect_identical(readLines(file.path(Fixture$project, "nested/first.txt")), "relocated")
  Project <- jsonlite::fromJSON(file.path(Fixture$project, "manifest.json"), simplifyVector = FALSE)
  expect_identical(Project$scaffolds$fixture$manifest, normalizePath(Manifest, winslash = "/"))
  expect_false(compareResources(root = Fixture$project)$changed)
  unlink(Copy, recursive = TRUE)
  expect_error(compareResources(root = Fixture$project), "fixture.*--from")
  pullResources(from = Fixture$manifest, root = Fixture$project, force = TRUE)
  expect_identical(readLines(file.path(Fixture$project, "nested/first.txt")), "one")
})

test_that("a file entry overrides the ownership given by its directory entry", {
  Fixture <- resourceFixture()
  on.exit(unlink(Fixture$root, recursive = TRUE), add = TRUE)
  dir.create(file.path(Fixture$source, "masters"))
  writeLines("deck", file.path(Fixture$source, "masters/deck.qmd"))
  writeLines("book", file.path(Fixture$source, "masters/book.qmd"))
  Entries <- list(
    list(from = "masters", to = "_master", ownership = "managed"),
    list(from = "masters/book.qmd", to = "_master/book.qmd", ownership = "seed")
  )
  for (Resources in list(Entries, rev(Entries))) {
    jsonlite::write_json(list(schemaVersion = 1L, id = "fixture", resources = Resources),
                         Fixture$manifest, auto_unbox = TRUE)
    Files <- .readResourceSource(Fixture$manifest)$files
    expect_identical(Files[["_master/deck.qmd"]]$ownership, "managed")
    expect_identical(Files[["_master/book.qmd"]]$ownership, "seed")
  }
  pullResources(from = Fixture$manifest, root = Fixture$project)
  writeLines("project deck", file.path(Fixture$project, "_master/deck.qmd"))
  writeLines("project book", file.path(Fixture$project, "_master/book.qmd"))
  expect_true(compareResources(root = Fixture$project)$changed)
  pullResources(root = Fixture$project, force = TRUE)
  expect_identical(readLines(file.path(Fixture$project, "_master/deck.qmd")), "deck")
  expect_identical(readLines(file.path(Fixture$project, "_master/book.qmd")), "project book")
  Resources <- c(Entries, list(list(from = "first.txt", to = "_master/book.qmd", ownership = "seed")))
  jsonlite::write_json(list(schemaVersion = 1L, id = "fixture", resources = Resources),
                       Fixture$manifest, auto_unbox = TRUE)
  expect_error(.readResourceSource(Fixture$manifest), "Duplicate destination")
  Resources <- c(Entries, Entries[2L])
  jsonlite::write_json(list(schemaVersion = 1L, id = "fixture", resources = Resources),
                       Fixture$manifest, auto_unbox = TRUE)
  expect_error(.readResourceSource(Fixture$manifest), "Duplicate destination")
})

test_that("artifact seeds resolve {project_id} once the project declares its own id", {
  Fixture <- resourceFixture()
  on.exit(unlink(Fixture$root, recursive = TRUE), add = TRUE)
  writeLines(c("params:", "  project_id: \"PROJECT_ID\""), file.path(Fixture$source, "params.yml"))
  jsonlite::write_json(list(schemaVersion = 1L, id = "fixture", resources = list(
    list(from = "first.txt", to = "nested/first.txt", ownership = "managed"),
    list(from = "params.yml", to = "params.yml", ownership = "seed")
  ), artifacts = list(list(alias = "toc", kind = "static", path = "html/toc", required = TRUE,
                           siteSlug = "{project_id}-toc", domain = "{project_id}-toc.example.org"))),
    Fixture$manifest, auto_unbox = TRUE)
  Manifest <- file.path(Fixture$project, "manifest.json")
  expect_message(pullResources(from = Fixture$manifest, root = Fixture$project), "^artifacts not seeded", class = "moduleNote")
  expect_identical(jsonlite::fromJSON(Manifest, simplifyVector = FALSE)$artifacts, list())
  expect_message(pullResources(root = Fixture$project), "project_id")
  expect_identical(jsonlite::fromJSON(Manifest, simplifyVector = FALSE)$artifacts, list())
  writeLines(c("params:", "  project_id: \"AR-TEST0\""), file.path(Fixture$project, "params.yml"))
  pullResources(root = Fixture$project)
  Artifact <- jsonlite::fromJSON(Manifest, simplifyVector = FALSE)$artifacts[[1L]]
  expect_identical(Artifact$siteSlug, "artest0-toc")
  expect_identical(Artifact$domain, "artest0-toc.example.org")
  expect_identical(Artifact$path, "html/toc")
  writeLines(c("params:", "  project_id: \"OTHER\""), file.path(Fixture$project, "params.yml"))
  pullResources(root = Fixture$project)
  expect_identical(jsonlite::fromJSON(Manifest, simplifyVector = FALSE)$artifacts[[1L]]$siteSlug, "artest0-toc")
})

test_that("a source outside Git takes its revision from the record beside its manifest", {
  Fixture <- resourceFixture()
  on.exit(unlink(Fixture$root, recursive = TRUE), add = TRUE)
  Record <- file.path(Fixture$source, "BUILD_INFO")
  expect_identical(.resourceRevision(Fixture$manifest), list(commit = "unknown", dirty = TRUE))
  writeLines(c("git_commit=0123456789abcdef0123456789abcdef01234567", "git_describe=0123456"), Record)
  expect_identical(.resourceRevision(Fixture$manifest),
                   list(commit = "0123456789abcdef0123456789abcdef01234567", dirty = FALSE))
  pullResources(from = Fixture$manifest, root = Fixture$project)
  Project <- jsonlite::fromJSON(file.path(Fixture$project, "manifest.json"), simplifyVector = FALSE)
  expect_false(file.exists(file.path(Fixture$project, "BUILD_INFO")))
  expect_identical(quartoRenderStamp(Project, root = Fixture$project),
                   paste0("Printed: ", format(Sys.time(), "%d/%m/%Y")))
  writeLines(c("git_commit=0123456789abcdef0123456789abcdef01234567", "git_describe=0123456-dirty"), Record)
  expect_true(.resourceRevision(Fixture$manifest)$dirty)
  writeLines("git_commit=not-a-commit", Record)
  expect_error(.resourceRevision(Fixture$manifest), "BUILD_INFO")
})

test_that("a source cannot supply a destination the project owns", {
  Fixture <- resourceFixture()
  on.exit(unlink(Fixture$root, recursive = TRUE), add = TRUE)
  Owned <- c("oq/data/UHSTable.Rds", "gmsp/match/target.json", "manifest.json",
             "data/hazard/UHSTable.Rds", "data/newmark/DnTable.Rds",
             "run/_remote/record.json", "hazard.json", "newmark.json")
  for (Destination in Owned) {
    jsonlite::write_json(list(schemaVersion = 1L, id = "fixture", resources = list(
      list(from = "first.txt", to = Destination, ownership = "managed")
    )), Fixture$manifest, auto_unbox = TRUE)
    expect_error(pullResources(from = Fixture$manifest, root = Fixture$project, dryRun = TRUE),
                 "Project-owned destination cannot be supplied", fixed = TRUE)
  }
})

test_that("a project's contracts protect the roots they declare, whatever their names", {
  Fixture <- resourceFixture()
  on.exit(unlink(Fixture$root, recursive = TRUE), add = TRUE)
  jsonlite::write_json(list(path = list(data = "tables/hazard", uhs = "per-site")),
                       file.path(Fixture$project, "hazard.json"), auto_unbox = TRUE)
  jsonlite::write_json(list(path = list(data = "tables/newmark")),
                       file.path(Fixture$project, "newmark.json"), auto_unbox = TRUE)
  for (Destination in c("tables/hazard/UHSTable.Rds", "tables/newmark/DnTable.Rds",
                        "per-site/S2C1R/ANTPY/UHSRock.Rds", "TABLES/case.Rds")) {
    jsonlite::write_json(list(schemaVersion = 1L, id = "fixture", resources = list(
      list(from = "first.txt", to = Destination, ownership = "managed")
    )), Fixture$manifest, auto_unbox = TRUE)
    expect_error(pullResources(from = Fixture$manifest, root = Fixture$project, dryRun = TRUE),
                 "cannot be supplied", fixed = TRUE)
  }
  # A key the contract does not declare is not protected by a restated default.
  jsonlite::write_json(list(schemaVersion = 1L, id = "fixture", resources = list(
    list(from = "first.txt", to = "mce/scenario.Rds", ownership = "managed")
  )), Fixture$manifest, auto_unbox = TRUE)
  Result <- pullResources(from = Fixture$manifest, root = Fixture$project, dryRun = TRUE)
  expect_identical(Result$actions$action, "create")
})

for (Kind in c("relative", "dot", "absolute", "missing", "project", "parent")) {
  test_that(paste("declared root protects bytes with force:", Kind), {
    Fixture <- resourceFixture()
    on.exit(unlink(Fixture$root, recursive = TRUE), add = TRUE)
    pullResources(from = Fixture$manifest, root = Fixture$project)
    writeLines("project data", file.path(Fixture$project, "nested/first.txt"))
    Value <- switch(Kind,
      relative = "nested",
      dot = "./nested",
      absolute = file.path(Fixture$project, "nested"),
      missing = file.path(Fixture$project, "nested/not-produced-yet"),
      project = ".",
      parent = Fixture$root
    )
    jsonlite::write_json(list(path = list(data = Value)),
                         file.path(Fixture$project, "hazard.json"), auto_unbox = TRUE)
    Files <- list.files(Fixture$project, recursive = TRUE, full.names = TRUE)
    Before <- tools::md5sum(Files)
    expect_error(pullResources(root = Fixture$project, force = TRUE),
                 "Destination declared by hazard.json cannot be supplied", fixed = TRUE,
                 info = Kind)
    expect_identical(tools::md5sum(Files), Before, info = Kind)
    expect_identical(list.files(Fixture$project, recursive = TRUE, full.names = TRUE),
                     Files, info = Kind)
  })
}

test_that("external declared roots do not reserve an unrelated project directory", {
  Fixture <- resourceFixture()
  on.exit(unlink(Fixture$root, recursive = TRUE), add = TRUE)
  External <- file.path(Fixture$root, "external")
  dir.create(External)
  writeLines("external data", file.path(External, "first.txt"))
  jsonlite::write_json(list(path = list(data = External)),
                       file.path(Fixture$project, "hazard.json"), auto_unbox = TRUE)
  pullResources(from = Fixture$manifest, root = Fixture$project)
  expect_identical(readLines(file.path(Fixture$project, "nested/first.txt")), "one")
  expect_identical(readLines(file.path(External, "first.txt")), "external data")
})
