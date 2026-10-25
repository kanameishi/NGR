test_that("outside an installed command every check reports its failure", {
  Report <- describeModule()
  expect_identical(vapply(Report$checks, `[[`, "", "name"),
                   c("library", "exports", "packages", "tools", "receipt", "optional"))
  expect_identical(vapply(Report$checks, `[[`, "", "status"), c(rep("fail", 5L), "warn"))
  expect_identical(Report$summary$status, "fail")
})

test_that("an intact installation passes, a missing optional tool warns and a changed file fails", {
  Prefix <- tempfile("describe-")
  Resources <- file.path(Prefix, "libexec/ngr")
  dir.create(file.path(Resources, "install"), recursive = TRUE)
  dir.create(file.path(Resources, "lib"))
  on.exit(unlink(Prefix, recursive = TRUE), add = TRUE)
  writeLines(paste("Version:", utils::packageVersion("NGR")), file.path(Resources, "lib/DESCRIPTION"))
  writeLines('list(exports = "describeModule", packages = character(), tools = character(), optional = "ngr-absent-tool")',
             file.path(Resources, "install/requirements.R"))
  Files <- c("libexec/ngr/install/requirements.R", "libexec/ngr/lib/DESCRIPTION")
  jsonlite::write_json(list(package = list(name = "NGR"), file = Files,
                            md5 = unname(tools::md5sum(file.path(Prefix, Files)))),
                       file.path(Resources, "install.json"), auto_unbox = TRUE)
  Report <- describeModule(Resources)
  expect_identical(vapply(Report$checks, `[[`, "", "status"), c(rep("ok", 5L), "warn"))
  expect_identical(Report$summary$status, "ok")
  write("# changed after installation", file.path(Resources, "install/requirements.R"), append = TRUE)
  Report <- describeModule(Resources)
  expect_identical(vapply(Report$checks, `[[`, "", "status"), c(rep("ok", 4L), "fail", "warn"))
  expect_identical(Report$summary$status, "fail")
})
