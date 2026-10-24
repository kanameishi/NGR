#' Register, publish or configure the Netlify sites of a manifest selection
#'
#' Manifest forms of [netlifyRegister()], [netlifyDeploy()] and
#' [netlifyDomain()]. Each reads the artifact manifest, applies the alias
#' selection and validates the whole selection before its first effect.
#' Registration and domains take each artifact's `siteSlug` and `domain`; those
#' values must be unique across the complete manifest, not only the selection,
#' and every selected artifact must declare the one in use. Publication uploads
#' each selected artifact's `path`: a missing `index.html` fails a required
#' artifact and skips an optional one with a message.
#'
#' @param manifest Path to a schema 1 or 2 artifact manifest, relative to `root`
#'   or absolute.
#' @param only Character vector of aliases to include; empty selects all.
#' @param except Character vector of aliases to exclude.
#' @inheritParams netlifyRegister
#' @inheritParams netlifyDeploy
#' @inheritParams netlifyDomain
#' @return Invisibly, the value of the direct operation for the artifacts it
#'   reached; an empty character vector when every selected upload was skipped.
#' @details Batches are sequential, not transactions; a later failure retains
#'   earlier effects. Dry runs contact no provider and write no registry.
#' @seealso [quartoRenderManifest()]
#' @export
netlifyRegisterManifest <- function(manifest, root = getwd(), only = character(),
                                    except = character(), create = FALSE,
                                    account = NULL, dryRun = FALSE) {
  Root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  Sites <- .publicationTargets(manifest, root = Root, only = only, except = except, field = "siteSlug")
  netlifyRegister(names(Sites), site = unname(Sites), root = Root, create = create,
                  account = account, dryRun = dryRun)
}

#' @rdname netlifyRegisterManifest
#' @export
netlifyDeployManifest <- function(manifest, root = getwd(), only = character(),
                                  except = character(), prod = FALSE, dryRun = FALSE) {
  Root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  Selected <- .selectArtifacts(.readArtifacts(manifest = manifest, root = Root),
                               only = only, except = except)
  if (!nzchar(Sys.which("netlify"))) .fail("Netlify CLI not found on PATH.")
  if (!dryRun && !file.exists(file.path(Root, ".netlify/sites.env"))) {
    .fail("Missing .netlify/sites.env; register aliases first.")
  }
  Present <- vapply(Selected, function(x) {
    file_test("-f", file.path(Root, x$path, "index.html"))
  }, logical(1L))
  for (Entry in Selected[!Present]) {
    if (Entry$required) {
      .fail("Missing required static site: ", Entry$alias, ": ", Entry$path, "/index.html")
    }
    .inform("moduleNote", "skip ", Entry$alias, " optional missing path=", Entry$path,
            operation = "deploy", phase = "upload", unit = Entry$alias, path = Entry$path)
  }
  Selected <- Selected[Present]
  if (!length(Selected)) return(invisible(character()))
  netlifyDeploy(vapply(Selected, `[[`, character(1L), "alias"),
                path = vapply(Selected, `[[`, character(1L), "path"),
                root = Root, prod = prod, dryRun = dryRun)
}

#' @rdname netlifyRegisterManifest
#' @export
netlifyDomainManifest <- function(manifest, root = getwd(), only = character(),
                                  except = character(), https = FALSE, dryRun = FALSE) {
  Root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  Domains <- .publicationTargets(manifest, root = Root, only = only, except = except, field = "domain")
  netlifyDomain(names(Domains), domain = unname(Domains), root = Root, https = https, dryRun = dryRun)
}

# Two aliases sharing one site name or domain would publish over each other, and
# a selection could hide that, so the claim is checked across the whole manifest.
.publicationTargets <- function(manifest, root, only, except, field) {
  Artifacts <- .readArtifacts(manifest = manifest, root = root)
  Selected <- .selectArtifacts(Artifacts, only = only, except = except)
  if (anyDuplicated(unlist(lapply(Artifacts, `[[`, field), use.names = FALSE))) {
    .fail("Duplicate ", field, " across manifest.")
  }
  if (any(vapply(Selected, function(x) is.null(x[[field]]), logical(1L)))) {
    .fail("Every selected artifact requires ", field, ".")
  }
  stats::setNames(vapply(Selected, `[[`, character(1L), field),
                  vapply(Selected, `[[`, character(1L), "alias"))
}
