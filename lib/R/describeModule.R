#' Describe the installed module
#'
#' Diagnoses the installation of the ngr command without repairs; the
#' installed command prints this report for `ngr doctor`. Every check runs
#' even when another one fails, so the report is always complete.
#' @param resources The resource directory of the installed command,
#'   `PREFIX/libexec/ngr`, or `NULL` outside an installed product, where the
#'   checks that read it fail.
#' @return A list with `schema` (1), `package`, `version` (the version that
#'   loads), `summary` and `checks`. Each check has `name`, `required`,
#'   `status` (`ok`, `warn` or `fail`) and `detail`, its result or the reason
#'   it failed. The required checks are `library` (the version that loads is
#'   the one of `lib/DESCRIPTION`), `exports` (the exports that
#'   `install/requirements.R` declares exist), `packages` (the packages it
#'   declares load), `tools` (the tools it declares are on `PATH`) and
#'   `receipt` (the files that the receipt `install.json` records keep their
#'   MD5). `optional` (the optional tools it declares are on `PATH`) is not
#'   required: it gives `warn` where a required check gives `fail`. `summary`
#'   holds `status`, `fail` when a required check fails and `ok` otherwise.
#'   Reads `resources` and the files of its receipt; writes nothing.
#' @examples
#' # Outside an installed command the checks of the installation fail with
#' # their reason, and the report stays complete.
#' Report <- describeModule()
#' Report$summary$status
#' vapply(Report$checks, function(x) paste(x$name, x$status), "")
#' @export
describeModule <- function(resources = NULL) {
  Checks <- list()
  # A failing check reports its condition as the detail, so the report is
  # always complete; a check that is not required warns instead of failing.
  check <- function(name, required, expr) {
    Checks[[length(Checks) + 1L]] <<- tryCatch(
      list(name = name, required = required, status = "ok", detail = force(expr)),
      error = function(e) {
        list(name = name, required = required, status = if (required) "fail" else "warn", detail = conditionMessage(e))
      })
  }
  # The installed command supplies its resource directory; an R call outside
  # it has none.
  runtime <- function(path) {
    if (is.null(resources)) stop("no installed resources: run the installed command")
    FILE <- file.path(resources, path)
    if (!file.exists(FILE)) stop("missing installed resource ", FILE)
    FILE
  }
  listed <- function(x) if (length(x)) paste(x, collapse = ", ") else "(none declared)"
  declared <- function(field) {
    as.character(source(runtime("install/requirements.R"), local = new.env(parent = baseenv()))$value[[field]])
  }
  onPath <- function(field) {
    Tools <- declared(field)
    Missing <- Tools[!nzchar(Sys.which(Tools))]
    if (length(Missing)) stop("not on PATH: ", listed(Missing))
    paste("on PATH:", listed(Tools))
  }
  Version <- as.character(utils::packageVersion("NGR"))
  check("library", TRUE, {
    Declared <- unname(read.dcf(runtime("lib/DESCRIPTION"), fields = "Version")[1L, 1L])
    if (!identical(Version, Declared)) stop("NGR ", Version, " loads; lib/DESCRIPTION declares ", Declared)
    paste("NGR", Version, "loads")
  })
  check("exports", TRUE, {
    Exports <- declared("exports")
    Missing <- setdiff(Exports, getNamespaceExports("NGR"))
    if (length(Missing)) stop("missing: ", listed(Missing))
    paste(length(Exports), "declared exports present")
  })
  check("packages", TRUE, {
    Packages <- declared("packages")
    Missing <- Packages[!vapply(Packages, requireNamespace, logical(1L), quietly = TRUE)]
    if (length(Missing)) stop("do not load: ", listed(Missing))
    paste("load:", listed(Packages))
  })
  check("tools", TRUE, onPath("tools"))
  check("receipt", TRUE, {
    Record <- jsonlite::read_json(runtime("install.json"), simplifyVector = TRUE)
    if (!identical(Record$package$name, "NGR")) stop("the receipt names ", Record$package$name)
    # The receipt records each path relative to the prefix, two levels above
    # resources, with the MD5 of its bytes.
    Sums <- unname(tools::md5sum(file.path(dirname(dirname(resources)), Record$file)))
    Changed <- Record$file[is.na(Sums) | Sums != Record$md5]
    if (length(Changed)) stop("changed or missing: ", listed(Changed))
    paste(length(Record$file), "files keep their recorded MD5")
  })
  check("optional", FALSE, onPath("optional"))
  Failed <- vapply(Checks, function(x) x$required && x$status == "fail", logical(1L))
  list(schema = 1L, package = "NGR", version = Version,
       summary = list(status = if (any(Failed)) "fail" else "ok"), checks = Checks)
}
