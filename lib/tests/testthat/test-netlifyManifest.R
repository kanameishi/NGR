manifestFixture <- function() {
  Root <- tempfile("netlify-manifest-")
  dir.create(file.path(Root, "html/one"), recursive = TRUE)
  writeLines("one", file.path(Root, "html/one/index.html"))
  dir.create(file.path(Root, ".netlify"))
  writeLines(c("one=11111111-1111-1111-1111-111111111111", "two=22222222-2222-2222-2222-222222222222"),
             file.path(Root, ".netlify/sites.env"))
  list(root = Root, artifacts = list(
    list(alias = "one", kind = "static", path = "html/one", siteSlug = "site-one",
         domain = "one.example.invalid", required = TRUE),
    list(alias = "two", kind = "static", path = "html/two", siteSlug = "site-two",
         domain = "two.example.invalid", required = FALSE)
  ))
}

writeArtifacts <- function(fixture) {
  jsonlite::write_json(list(schemaVersion = 2L, artifacts = fixture$artifacts),
                       file.path(fixture$root, "manifest.json"), auto_unbox = TRUE)
}

test_that("manifest registration and domains check their claims across the whole manifest", {
  Fixture <- manifestFixture()
  on.exit(unlink(Fixture$root, recursive = TRUE), add = TRUE)
  writeArtifacts(Fixture)
  expect_message(OUT <- netlifyRegisterManifest("manifest.json", root = Fixture$root, only = "two", dryRun = TRUE),
                 "^two siteSlug=site-two", class = "moduleNote")
  expect_identical(OUT, c(two = "site-two"))
  expect_message(netlifyDomainManifest("manifest.json", root = Fixture$root, except = "one", dryRun = TRUE),
                 "^two domain=two.example.invalid", class = "moduleProgress")
  Fixture$artifacts[[2L]]$siteSlug <- "site-one"
  writeArtifacts(Fixture)
  expect_error(netlifyRegisterManifest("manifest.json", root = Fixture$root, only = "one", dryRun = TRUE),
               "Duplicate siteSlug", class = "moduleFailure")
  Fixture$artifacts[[2L]]$siteSlug <- NULL
  writeArtifacts(Fixture)
  expect_error(netlifyRegisterManifest("manifest.json", root = Fixture$root, dryRun = TRUE), "requires siteSlug")
  expect_message(netlifyRegisterManifest("manifest.json", root = Fixture$root, only = "one", dryRun = TRUE), "^one siteSlug",
                 class = "moduleNote")
})

test_that("a dry-run registration signals its plan as a family note with its fields", {
  Fixture <- manifestFixture()
  on.exit(unlink(Fixture$root, recursive = TRUE), add = TRUE)
  writeArtifacts(Fixture)
  Note <- tryCatch(netlifyRegisterManifest("manifest.json", root = Fixture$root, only = "two", dryRun = TRUE),
                   message = function(m) m)
  expect_s3_class(Note, "moduleNote")
  expect_identical(conditionMessage(Note), "two siteSlug=site-two create=FALSE\n")
  expect_identical(Note[c("operation", "phase", "unit")], list(operation = "deploy", phase = "init", unit = "two"))
})

test_that("manifest publication skips optional missing sites and fails required ones", {
  skip_if(!nzchar(Sys.which("netlify")), "The Netlify CLI is required even to plan a publication")
  Fixture <- manifestFixture()
  on.exit(unlink(Fixture$root, recursive = TRUE), add = TRUE)
  writeArtifacts(Fixture)
  expect_message(OUT <- netlifyDeployManifest("manifest.json", root = Fixture$root, dryRun = TRUE),
                 "^skip two optional missing path=html/two", class = "moduleNote")
  expect_identical(names(OUT), "one")
  Fixture$artifacts[[2L]]$required <- TRUE
  writeArtifacts(Fixture)
  expect_error(netlifyDeployManifest("manifest.json", root = Fixture$root, dryRun = TRUE),
               "Missing required static site: two")
  expect_identical(netlifyDeployManifest("manifest.json", root = Fixture$root, only = "one", dryRun = TRUE),
                   c(one = "11111111-1111-1111-1111-111111111111"))
})
