test_that("the print stamp names the date and ignores the provenance state", {
  Root <- tempfile("ngr-stamp-")
  dir.create(Root)
  on.exit(unlink(Root, recursive = TRUE), add = TRUE)
  FILE <- file.path(Root, "chapter.qmd")
  writeLines("chapter", FILE)
  Digest <- unname(tools::md5sum(FILE))
  Entry <- list(commit = "abcdef0123456789", dirty = FALSE, md5 = Digest)
  Manifest <- list(scaffolds = list(book = list(
    complete = TRUE, files = list("chapter.qmd" = Entry)
  )))
  Stamp <- paste0("Printed: ", format(Sys.Date(), "%d/%m/%Y"))
  expect_message(
    Out <- NGR::quartoRenderStamp(Manifest, root = Root),
    "^Render timestamp:", class = "moduleNote"
  )
  expect_identical(Out, Stamp)
  expect_identical(unname(tools::md5sum(FILE)), Digest)

  Manifest$scaffolds$book$files[["chapter.qmd"]]$dirty <- TRUE
  expect_identical(suppressMessages(NGR::quartoRenderStamp(Manifest, root = Root)), Stamp)
  Manifest$scaffolds$book$files[["chapter.qmd"]]$dirty <- FALSE
  writeLines("local change", FILE)
  expect_identical(suppressMessages(NGR::quartoRenderStamp(Manifest, root = Root)), Stamp)
  unlink(FILE)
  expect_identical(suppressMessages(NGR::quartoRenderStamp(Manifest, root = Root)), Stamp)
})

test_that("mixed revisions, incomplete coverage and empty manifests keep the same stamp", {
  Root <- tempfile("ngr-stamp-")
  dir.create(Root)
  on.exit(unlink(Root, recursive = TRUE), add = TRUE)
  FILE <- file.path(Root, "chapter.qmd")
  writeLines("chapter", FILE)
  Entry <- list(commit = "abcdef0123456789", dirty = FALSE,
                md5 = unname(tools::md5sum(FILE)))
  Manifest <- list(scaffolds = list(
    book = list(complete = TRUE, files = list("chapter.qmd" = Entry)),
    supplement = list(complete = TRUE, files = list("chapter.qmd" = Entry))
  ))
  Manifest$scaffolds$supplement$files[["chapter.qmd"]]$commit <- "123456789abcdef"
  Stamp <- paste0("Printed: ", format(Sys.Date(), "%d/%m/%Y"))
  expect_identical(suppressMessages(NGR::quartoRenderStamp(Manifest, root = Root)), Stamp)
  Manifest$scaffolds$book$complete <- FALSE
  expect_identical(suppressMessages(NGR::quartoRenderStamp(Manifest, root = Root)), Stamp)
  expect_identical(suppressMessages(NGR::quartoRenderStamp(list(), root = Root)), Stamp)
})

test_that("invalid provenance and escaping paths fail before use", {
  Root <- tempfile("ngr-stamp-")
  dir.create(Root)
  on.exit(unlink(Root, recursive = TRUE), add = TRUE)
  Entry <- list(commit = "abcdef0123456789", dirty = FALSE,
                md5 = "d41d8cd98f00b204e9800998ecf8427e")
  Manifest <- list(scaffolds = list(book = list(
    complete = TRUE, files = list("chapter.qmd" = Entry)
  )))
  Manifest$scaffolds$book$files[["chapter.qmd"]]$commit <- "invalid"
  expect_error(NGR::quartoRenderStamp(Manifest, root = Root),
               "Invalid scaffold provenance for chapter.qmd", fixed = TRUE)
  Manifest$scaffolds$book$files <- list("../outside.qmd" = Entry)
  expect_error(NGR::quartoRenderStamp(Manifest, root = Root),
               "Scaffold path escapes the project: ../outside.qmd", fixed = TRUE)
  Manifest$scaffolds$book$files <- list("/outside.qmd" = Entry)
  expect_error(NGR::quartoRenderStamp(Manifest, root = Root),
               "Scaffold path escapes the project: /outside.qmd", fixed = TRUE)
})
