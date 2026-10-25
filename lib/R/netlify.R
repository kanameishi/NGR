#' Register local aliases for Netlify sites
#'
#' Queries the installed Netlify CLI and records associations in
#' `.netlify/sites.env` under `root`. Existing aliases cannot be retargeted.
#' All requested associations are checked before creating or registering sites.
#'
#' @param alias Character vector of local aliases.
#' @param site Character vector of provider site names, aligned with `alias`.
#' @param root Project directory. Defaults to the current working directory.
#' @param create Permit creating missing sites. Defaults to `FALSE`.
#' @param account Optional Netlify account slug.
#' @param dryRun Describe the request without provider calls or registry writes.
#' @return Invisibly, UUIDs named by alias; a dry run returns the requested names.
#' @details Requires an installed and authenticated Netlify CLI. Batches are
#'   sequential, not transactions; a later failure retains earlier effects.
#' @export
netlifyRegister <- function(alias, site, root = getwd(), create = FALSE,
                            account = NULL, dryRun = FALSE) {
  .checkNetlifyArguments(alias, values = site, flags = list(create, dryRun))
  if (!is.null(account) && (!is.character(account) || length(account) != 1L ||
                            is.na(account) || !nzchar(account))) {
    .fail("Account must be one non-empty slug.")
  }
  Root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  Directory <- getwd()
  setwd(Root)
  on.exit(setwd(Directory), add = TRUE)
  Registry <- file.path(Root, ".netlify/sites.env")
  if (dryRun) {
    for (i in seq_along(alias)) {
      .inform("moduleNote", alias[[i]], " siteSlug=", site[[i]], " create=", create,
              operation = "deploy", phase = "init", unit = alias[[i]])
    }
    return(invisible(stats::setNames(site, alias)))
  }
  Ids <- stats::setNames(rep("", length(alias)), alias)
  for (i in seq_along(alias)) {
    Ids[[i]] <- .findNetlifySite(site[[i]], account = account)
    Current <- .readNetlifyAlias(alias[[i]], registry = Registry)
    if (!nzchar(Ids[[i]]) && !create) .fail("Netlify site not found: ", site[[i]], "; use --create.")
    if (nzchar(Ids[[i]])) .checkNetlifyId(Ids[[i]])
    if (nzchar(Current) && Current != Ids[[i]]) {
      .fail("Alias ", alias[[i]], " already points to ", Current, "; refusing retarget.")
    }
  }
  for (i in seq_along(alias)) {
    if (!nzchar(Ids[[i]])) {
      Args <- c("sites:create", "--manual", "--disable-linking", "--name", site[[i]])
      if (!is.null(account)) Args <- c(Args, "--account-slug", .netlifyFold(account))
      .netlifyCommand(Args)
      Ids[[i]] <- tryCatch({
        Id <- .findNetlifySite(site[[i]], account = account)
        .checkNetlifyId(Id)
        Id
      }, error = function(e) {
        .fail("Site creation completed but alias was not registered; reconcile with ngr deploy init ",
              alias[[i]], " ", site[[i]], ". Cause: ", conditionMessage(e))
      })
    }
    .writeNetlifyAlias(alias[[i]], id = Ids[[i]], registry = Registry)
    .inform("moduleNote", alias[[i]], " -> ", Ids[[i]], operation = "deploy", phase = "init", unit = alias[[i]])
  }
  invisible(Ids)
}

#' Upload existing directories to Netlify
#'
#' Validates all directories and registered sites before uploading. Never builds
#' a site; passes `--no-build` to Netlify. Draft deployments are the default.
#' @inheritParams netlifyRegister
#' @param path Character vector of directories aligned with `alias`, relative to
#'   `root` or absolute.
#' @param prod Publish to production instead of creating a draft.
#' @return Invisibly, the provider UUIDs named by alias. After uploads, its
#'   attribute `response` holds, by alias, the lines the Netlify CLI returned
#'   for each upload; a dry run has no such attribute.
#' @details Uploads are sequential, not a transaction. A failure after a
#'   completed upload signals a condition of class `ngrPartialPublication`,
#'   which inherits from `modulePartialPublication` and `moduleFailure`: its
#'   `effects` holds the UUIDs of the completed uploads with their `response`,
#'   and its `cause` the failure. A failure before the first completed upload
#'   reaches the caller unchanged.
#' @export
netlifyDeploy <- function(alias, path, root = getwd(), prod = FALSE, dryRun = FALSE) {
  .checkNetlifyArguments(alias, values = path, flags = list(prod, dryRun))
  Root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  Directory <- getwd()
  setwd(Root)
  on.exit(setwd(Directory), add = TRUE)
  if (!nzchar(Sys.which("netlify"))) .fail("Netlify CLI not found on PATH.")
  for (Path in path) if (!dir.exists(Path)) .fail("Deploy directory not found: ", Path)
  Ids <- .netlifyAliases(alias, registry = file.path(Root, ".netlify/sites.env"))
  if (!dryRun) for (Id in Ids) .netlifyApi("getSite", list(site_id = Id))
  Response <- list()
  for (i in seq_along(alias)) {
    .inform("moduleProgress", alias[[i]], " path=", path[[i]], " prod=", prod,
            operation = "deploy", phase = "upload", unit = alias[[i]], path = path[[i]])
    if (dryRun) next
    Args <- c("deploy", paste0("--dir=", path[[i]]), paste0("--site=", Ids[[i]]), "--no-build")
    if (prod) Args <- c(Args, "--prod")
    # Earlier uploads stay live after a later failure; the condition carries them.
    Response[[alias[[i]]]] <- tryCatch(.netlifyCommand(Args), error = function(e) {
      if (!length(Response)) stop(e)
      stop(errorCondition(
        paste0("Upload of ", alias[[i]], " failed after ", length(Response), " completed upload(s): ",
               conditionMessage(e), "\nuploaded: ", paste(names(Response), collapse = ", "),
               "\nnot uploaded: ", paste(alias[seq(i, length(alias))], collapse = ", ")),
        class = c("ngrPartialPublication", "modulePartialPublication", "moduleFailure"),
        effects = structure(Ids[names(Response)], response = Response), cause = e))
    })
  }
  if (!dryRun) attr(Ids, "response") <- Response
  invisible(Ids)
}

#' Configure domains for registered Netlify sites
#'
#' Checks every current domain before changing any. A different existing domain
#' is rejected unless `rebind = TRUE`. DNS diagnostics do not change DNS records.
#' @inheritParams netlifyRegister
#' @param domain Character vector of host names aligned with `alias`.
#' @param https Enable HTTPS, including certificate provisioning if needed.
#' @param rebind Explicitly clear the current custom domain before binding.
#' @return Invisibly, the provider UUIDs named by alias.
#' @export
netlifyDomain <- function(alias, domain, root = getwd(), https = FALSE,
                          rebind = FALSE, dryRun = FALSE) {
  .checkNetlifyArguments(alias, values = domain, flags = list(https, rebind, dryRun))
  if (any(!grepl("^[A-Za-z0-9.-]+$", domain) | !grepl(".", domain, fixed = TRUE))) {
    .fail("Invalid domain or URL.")
  }
  Root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  Ids <- .netlifyAliases(alias, registry = file.path(Root, ".netlify/sites.env"))
  Directory <- getwd()
  setwd(Root)
  on.exit(setwd(Directory), add = TRUE)
  if (!dryRun && !rebind) {
    for (i in seq_along(alias)) .checkNetlifyDomain(id = Ids[[i]], domain = domain[[i]])
  }
  for (i in seq_along(alias)) {
    .inform("moduleProgress", alias[[i]], " domain=", domain[[i]], " https=", https, " rebind=", rebind,
            operation = "deploy", phase = "domain", unit = alias[[i]])
    if (dryRun) next
    if (rebind) .netlifyApi("updateSite", list(site_id = Ids[[i]], body = list(custom_domain = NULL)))
    .checkNetlifyDomain(id = Ids[[i]], domain = domain[[i]])
    .netlifyApi("updateSite", list(site_id = Ids[[i]], body = list(custom_domain = domain[[i]])))
    if (https) .enableNetlifyHttps(Ids[[i]])
    .checkNetlifyDns(id = Ids[[i]], domain = domain[[i]])
  }
  invisible(Ids)
}

#' Remove a local Netlify alias association
#'
#' Changes only `.netlify/sites.env`. Does not contact or delete provider sites.
#' @param alias One local alias.
#' @inheritParams netlifyRegister
#' @return Invisibly, the removed UUID.
#' @export
netlifyUnbind <- function(alias, root = getwd()) {
  .checkNetlifyArguments(alias, values = alias, flags = list())
  if (length(alias) != 1L) .fail("Unbind requires one alias.")
  Registry <- file.path(normalizePath(root, winslash = "/", mustWork = TRUE), ".netlify/sites.env")
  Id <- .readNetlifyAlias(alias, registry = Registry)
  if (!nzchar(Id)) .fail("Alias not registered: ", alias)
  .writeNetlifyAlias(alias, id = NULL, registry = Registry)
  .inform("moduleNote", "removed ", alias, " -> ", Id, operation = "deploy", phase = "unbind", unit = alias)
  invisible(Id)
}

.checkNetlifyArguments <- function(alias, values, flags) {
  for (x in list(alias, values)) {
    if (!is.character(x) || !length(x) || anyNA(x) || any(!nzchar(x))) {
      .fail("Aliases and their values must be non-empty character vectors.")
    }
  }
  if (length(alias) != length(values) || anyDuplicated(alias)) {
    .fail("Each unique alias must have one corresponding value.")
  }
  for (x in flags) {
    if (!is.logical(x) || length(x) != 1L || is.na(x)) .fail("Netlify flags must be boolean.")
  }
}

.netlifyFold <- function(x) chartr("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz", x)

.netlifyCommand <- function(args) {
  Command <- Sys.which("netlify")
  if (!nzchar(Command)) .fail("Netlify CLI not found on PATH.")
  Output <- tempfile("ngr-netlify-")
  Error <- tempfile("ngr-netlify-")
  on.exit(unlink(c(Output, Error)), add = TRUE)
  Status <- system2(Command, args = shQuote(args), stdout = Output, stderr = Error)
  OUT <- readLines(Output, warn = FALSE)
  if (Status != 0L) {
    stop(errorCondition(paste0("Netlify ", args[[1L]], " failed (", Status, "): ",
                               paste(c(OUT, readLines(Error, warn = FALSE)), collapse = "\n")),
                         class = c("ngrNetlifyFailure", "moduleFailure")))
  }
  OUT
}

.netlifyApi <- function(method, data) {
  OUT <- .netlifyCommand(c("api", method, "--data", jsonlite::toJSON(data, auto_unbox = TRUE, null = "null")))
  if (!length(OUT) || !nzchar(paste(OUT, collapse = ""))) return(invisible(list()))
  jsonlite::fromJSON(paste(OUT, collapse = "\n"), simplifyVector = FALSE)
}

.findNetlifySite <- function(site, account) {
  Sites <- jsonlite::fromJSON(paste(.netlifyCommand(c("sites:list", "--json")), collapse = "\n"), simplifyVector = FALSE)
  for (Site in Sites) {
    if (!identical(.netlifyFold(Site$name), .netlifyFold(site))) next
    if (!is.null(account) && !identical(.netlifyFold(Site$account_slug), .netlifyFold(account))) next
    Id <- Site$id
    if (is.null(Id)) Id <- Site$site_id
    if (!is.null(Id) && nzchar(Id)) return(Id)
  }
  ""
}

.readNetlifyAlias <- function(alias, registry) {
  if (!file.exists(registry)) return("")
  Lines <- readLines(registry, warn = FALSE)
  IDX <- match(alias, sub("=.*$", "", Lines))
  if (is.na(IDX) || !grepl("=", Lines[[IDX]], fixed = TRUE)) return("")
  sub("^[^=]*=([^=]*).*$", "\\1", Lines[[IDX]])
}

.writeNetlifyAlias <- function(alias, id, registry) {
  Current <- .readNetlifyAlias(alias, registry = registry)
  if (!is.null(id) && nzchar(Current) && Current != id) .fail("Refusing alias retarget: ", alias)
  Lines <- character()
  if (file.exists(registry)) Lines <- readLines(registry, warn = FALSE)
  Lines <- Lines[sub("=.*$", "", Lines) != alias]
  if (!is.null(id)) Lines <- c(Lines, paste0(alias, "=", id))
  if (!dir.exists(dirname(registry)) && !dir.create(dirname(registry), recursive = TRUE)) {
    .fail("Cannot create registry directory.")
  }
  Path <- tempfile(".ngr-registry-", tmpdir = dirname(registry))
  on.exit(unlink(Path), add = TRUE)
  writeLines(Lines, Path, useBytes = TRUE)
  if (!file.rename(Path, registry)) .fail("Cannot replace registry: ", registry)
}

.checkNetlifyId <- function(id) {
  if (!is.character(id) || length(id) != 1L || is.na(id) ||
      !grepl("^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$", id)) {
    .fail("Invalid Netlify UUID: ", id)
  }
}

.netlifyAliases <- function(alias, registry) {
  Ids <- vapply(alias, .readNetlifyAlias, character(1L), registry = registry)
  if (any(!nzchar(Ids))) .fail("Alias not registered: ", paste(alias[!nzchar(Ids)], collapse = ", "))
  for (Id in Ids) .checkNetlifyId(Id)
  Ids
}

.checkNetlifyDomain <- function(id, domain) {
  Current <- .netlifyApi("getSite", list(site_id = id))$custom_domain
  if (!is.null(Current) && nzchar(Current) && Current != domain) {
    .fail("Site already has custom domain ", Current, "; refusing replace with ", domain)
  }
}

.enableNetlifyHttps <- function(id) {
  probe <- function(method, data) tryCatch(.netlifyApi(method, data), ngrNetlifyFailure = function(e) NULL)
  ready <- function(site) isTRUE(site$ssl) && isTRUE(site$force_ssl)
  Data <- list(site_id = id)
  if (ready(probe("getSite", Data))) return(invisible(NULL))
  probe("updateSite", list(site_id = id, body = list(force_ssl = TRUE)))
  if (ready(probe("getSite", Data))) return(invisible(NULL))
  tryCatch(.netlifyApi("provisionSiteTLSCertificate", Data), ngrNetlifyFailure = function(e) {
    if (!ready(probe("getSite", Data))) stop(e)
  })
  invisible(NULL)
}

.checkNetlifyDns <- function(id, domain) {
  if (!nzchar(Sys.which("dig"))) {
    .inform("moduleNote", "dig not found; verify DNS for ", domain, ".",
            operation = "deploy", phase = "domain", unit = domain)
    return(invisible(NULL))
  }
  Data <- tryCatch(.netlifyApi("getSite", list(site_id = id)), ngrNetlifyFailure = function(e) NULL)
  if (is.null(Data$dns_zone_id) || !nzchar(Data$dns_zone_id)) {
    .inform("moduleNote", "zone is not Netlify-managed; verify DNS for ", domain, ".",
            operation = "deploy", phase = "domain", unit = domain)
    return(invisible(NULL))
  }
  Data <- tryCatch(.netlifyApi("getDnsZone", list(zone_id = Data$dns_zone_id)), ngrNetlifyFailure = function(e) NULL)
  if (!length(Data$dns_servers) || !nzchar(Data$dns_servers[[1L]])) {
    .inform("moduleNote", "cannot read zone nameservers; verify DNS for ", domain, ".",
            operation = "deploy", phase = "domain", unit = domain)
    return(invisible(NULL))
  }
  for (i in seq_len(6L)) {
    OUT <- suppressWarnings(system2("dig", shQuote(c("+short", domain, "A", paste0("@", Data$dns_servers[[1L]]))),
                                    stdout = TRUE, stderr = FALSE))
    if (length(OUT) && nzchar(OUT[[1L]]) && is.null(attr(OUT, "status"))) {
      .inform("moduleNote", domain, " is served by ", Data$dns_servers[[1L]],
              operation = "deploy", phase = "domain", unit = domain)
      return(invisible(NULL))
    }
    Sys.sleep(10)
  }
  .inform("moduleNote", "authoritative DNS does not serve ", domain,
          " yet; verify DNS and the site edge before announcing it.",
          operation = "deploy", phase = "domain", unit = domain)
  invisible(NULL)
}
