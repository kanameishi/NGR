#' @importFrom utils file_test
NULL

.isResourceObject <- function(x) is.list(x) && !is.null(names(x))

.sameResourceValue <- function(x, y) {
  if (!is.list(x) && !is.list(y)) return(isTRUE(all.equal(x, y, tolerance = 0)))
  if (!is.list(x) || !is.list(y) || length(x) != length(y)) return(FALSE)
  if (.isResourceObject(x) != .isResourceObject(y)) return(FALSE)
  if (.isResourceObject(x)) {
    if (!setequal(names(x), names(y))) return(FALSE)
    y <- y[names(x)]
  }
  all(vapply(seq_along(x), function(i) .sameResourceValue(x[[i]], y[[i]]), logical(1L)))
}

.relativeResource <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path) ||
      grepl("\\\\|[\\x01-\\x1f]", path, perl = TRUE) || startsWith(path, "/") ||
      endsWith(path, "/") || grepl("//|(^|/)\\.{1,2}(/|$)", path)) {
    .fail("Invalid relative resource path: ", path)
  }
  path
}

.confinedResource <- function(root, path) {
  Path <- file.path(root, .relativeResource(path))
  DIR <- Path
  while (!identical(DIR, root)) {
    if (isTRUE(fs::is_link(DIR))) .fail("Symlink is not a resource path: ", DIR)
    DIR <- dirname(DIR)
  }
  Path
}

.selectedResource <- function(path, paths) {
  !length(paths) || any(path == paths | startsWith(path, paste0(paths, "/")))
}

.readResourceSource <- function(path) {
  Path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  Source <- jsonlite::fromJSON(Path, simplifyVector = FALSE)
  if (!.isResourceObject(Source) || !isTRUE(Source$schemaVersion == 1)) {
    .fail("Expected source schemaVersion 1: ", path)
  }
  if (!is.character(Source$id) || length(Source$id) != 1L ||
      !grepl("^[A-Za-z0-9][A-Za-z0-9._-]*$", Source$id)) {
    .fail("Invalid source id: ", path)
  }
  if (!is.list(Source$resources) || !length(Source$resources) ||
      !is.null(names(Source$resources))) .fail("Source resources must be a nonempty array")
  Files <- stats::setNames(list(), character())
  Exact <- logical()
  Root <- dirname(Path)
  for (Resource in Source$resources) {
    if (!.isResourceObject(Resource) ||
        !setequal(names(Resource), c("from", "to", "ownership")) ||
        !is.character(Resource$ownership) || length(Resource$ownership) != 1L ||
        !Resource$ownership %in% c("managed", "seed")) {
      .fail("Resource requires from, to and managed/seed ownership")
    }
    Input <- .confinedResource(Root, Resource$from)
    Target <- .relativeResource(Resource$to)
    if (!file.exists(Input)) .fail("Missing source resource: ", Input)
    Paths <- Input
    Files.input <- character()
    while (length(Paths)) {
      FILE <- Paths[[1L]]
      Paths <- Paths[-1L]
      if (isTRUE(fs::is_link(FILE))) .fail("Symlink in source: ", FILE)
      if (dir.exists(FILE)) {
        Paths <- c(Paths, list.files(FILE, all.files = TRUE, no.. = TRUE, full.names = TRUE))
        next
      }
      if (!file_test("-f", FILE)) .fail("Not a regular resource: ", FILE)
      Files.input <- c(Files.input, FILE)
    }
    Single <- !dir.exists(Input)
    for (FILE in sort(enc2utf8(Files.input), method = "radix")) {
      Name <- Target
      if (!Single) Name <- paste0(Target, "/", substring(FILE, nchar(Input) + 2L))
      .relativeResource(Name)
      # A file entry may restate one file of a directory entry to change its ownership.
      Peer <- Files[[Name]]
      if (!is.null(Peer) && (!identical(Peer$path, FILE) || identical(Exact[[Name]], Single))) {
        .fail("Duplicate destination in source: ", Name)
      }
      if (!is.null(Peer) && !Single) next
      # Project-owned roots and declarations: the scientific data of both
      # generations, the producers' run records, and the contracts that name
      # them. A scaffold supplies documents, never a producer's input or output.
      if (stringi::stri_trans_casefold(strsplit(Name, "/", fixed = TRUE)[[1L]][1L]) %in%
          c(".git", ".ngr", "oq", "gmsp", "data", "run",
            "manifest.json", "qrt.manifest.json", "hazard.json", "newmark.json")) {
        .fail("Project-owned destination cannot be supplied: ", Name)
      }
      Files[[Name]] <- list(path = FILE, sha256 = digest::digest(file = FILE, algo = "sha256"),
                            ownership = Resource$ownership)
      Exact[[Name]] <- Single
    }
  }
  for (Field in intersect(c("checks", "artifacts"), names(Source))) {
    if (!is.list(Source[[Field]]) || !is.null(names(Source[[Field]]))) {
      .fail("Source ", Field, " must be an array")
    }
  }
  for (Check in Source$checks) {
    if (!is.list(Check) || !is.null(names(Check)) || !length(Check) ||
        !all(vapply(Check, function(x) is.character(x) && length(x) == 1L &&
                      !is.na(x) && nzchar(x), logical(1L)))) {
      .fail("Source check must be an argv array")
    }
  }
  Source$files <- Files
  Source$manifest <- Path
  Source
}

.readResourceProject <- function(root) {
  Path <- .confinedResource(root, "manifest.json")
  if (!file.exists(Path)) {
    return(list(schemaVersion = 2L, artifacts = list(),
                scaffolds = stats::setNames(list(), character())))
  }
  Project <- jsonlite::fromJSON(Path, simplifyVector = FALSE)
  if (!.isResourceObject(Project) || !isTRUE(Project$schemaVersion %in% c(1, 2)) ||
      !is.list(Project$artifacts) || !is.null(names(Project$artifacts))) {
    .fail("Invalid project manifest: ", Path)
  }
  if (!"scaffolds" %in% names(Project)) Project$scaffolds <- stats::setNames(list(), character())
  if (!.isResourceObject(Project$scaffolds)) .fail("Invalid scaffold records")
  for (Name in names(Project$scaffolds)) {
    Entry <- Project$scaffolds[[Name]]
    if (!.isResourceObject(Entry)) .fail("Invalid source record: ", Name)
    for (Field in intersect(c("files", "claims"), names(Entry))) {
      if (!.isResourceObject(Entry[[Field]])) .fail("Invalid source ", Field, ": ", Name)
      for (Path in names(Entry[[Field]])) {
        .relativeResource(Path)
        Receipt <- Entry[[Field]][[Path]]
        if (!.isResourceObject(Receipt)) .fail("Invalid resource receipt: ", Path)
        Hash <- Receipt$md5
        Pattern <- "^[0-9a-f]{32}$"
        if (Field == "claims") {
          Hash <- Receipt$sha256
          Pattern <- "^[0-9a-f]{64}$"
          if (!isTRUE(Receipt$ownership %in% c("managed", "seed"))) {
            .fail("Invalid claim ownership: ", Path)
          }
        }
        if (!is.character(Hash) || length(Hash) != 1L || !grepl(Pattern, Hash)) {
          .fail("Invalid resource digest: ", Path)
        }
      }
    }
  }
  Project
}

# An installed source has no Git checkout; its installer records the revision
# it was taken from in a BUILD_INFO file beside the source manifest.
.recordedRevision <- function(path) {
  FILE <- file.path(dirname(path), "BUILD_INFO")
  if (!file_test("-f", FILE)) return(list(commit = "unknown", dirty = TRUE))
  AUX <- readLines(FILE, warn = FALSE)
  Commit <- sub("^git_commit=", "", AUX[startsWith(AUX, "git_commit=")])
  if (length(Commit) != 1L || !grepl("^[0-9a-f]{7,64}$", Commit)) {
    .fail("Invalid revision record: ", FILE)
  }
  list(commit = Commit, dirty = any(endsWith(AUX[startsWith(AUX, "git_describe=")], "-dirty")))
}

.resourceRevision <- function(path) {
  if (!nzchar(Sys.which("git"))) return(.recordedRevision(path))
  # Non-Git sources are supported; rev-parse's nonzero exit is the expected test.
  Commit <- suppressWarnings(system2("git", c("-C", shQuote(dirname(path)), "rev-parse", "HEAD"),
                                     stdout = TRUE, stderr = FALSE))
  if (!length(Commit) || !is.null(attr(Commit, "status"))) {
    return(.recordedRevision(path))
  }
  Status <- system2("git", c("-C", shQuote(dirname(path)), "status", "--porcelain", "--", "."),
                    stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(Status, "status"))) .fail("Cannot inspect source Git status: ", path)
  list(commit = trimws(Commit[[1L]]), dirty = length(Status) > 0L)
}

.loadResourceSources <- function(from, source, paths, project) {
  if (length(from) && length(source)) .fail("--source and --from cannot be combined")
  Sources <- stats::setNames(list(), character())
  for (Path in from) {
    Source <- .readResourceSource(Path)
    if (Source$id %in% names(Sources)) .fail("Duplicate source: ", Source$id)
    Sources[[Source$id]] <- Source
  }
  if (!length(from)) {
    Names <- source
    if (!length(Names)) Names <- names(project$scaffolds)
    for (Name in Names) {
      if (!Name %in% names(project$scaffolds)) .fail("Unknown registered source: ", Name)
      Entry <- project$scaffolds[[Name]]
      if (is.null(Entry$manifest) || !nzchar(Entry$manifest)) {
        .fail("Source ", Name, " has legacy provenance but no association; use --from its source manifest")
      }
      if (!file.exists(Entry$manifest)) {
        .fail("Source ", Name, " is registered at ", Entry$manifest,
              ", which does not exist here; use --from its source manifest")
      }
      Source <- .readResourceSource(Entry$manifest)
      if (!identical(Source$id, Name)) .fail("Source identity changed: ", Name)
      Sources[[Name]] <- Source
    }
  }
  if (!length(Sources)) .fail("No registered sources; start with pull --from <manifest>")
  for (Path in paths) {
    .relativeResource(Path)
    if (!any(vapply(Sources, function(x) any(vapply(names(x$files), .selectedResource,
                         logical(1L), paths = Path)), logical(1L)))) {
      .fail("Unknown resource target: ", Path)
    }
  }
  Sources
}

.checkResourceClaims <- function(project) {
  Claims <- list()
  for (Name in names(project$scaffolds)) {
    for (Path in names(project$scaffolds[[Name]]$claims)) {
      .relativeResource(Path)
      Claim <- project$scaffolds[[Name]]$claims[[Path]]
      Key <- stringi::stri_trans_casefold(Path)
      Peer <- Claims[[Key]]
      if (!is.null(Peer) && (!identical(Peer$path, Path) || !.sameResourceValue(Peer$claim, Claim))) {
        .fail("Source conflict at ", Path, ": ", Peer$source, " vs ", Name,
              "; --force cannot resolve it")
      }
      Claims[[Key]] <- list(source = Name, path = Path, claim = Claim)
    }
  }
  for (Key in names(Claims)) {
    DIR <- dirname(Key)
    while (DIR != ".") {
      if (DIR %in% names(Claims)) .fail("File/directory source conflict: ", Key)
      DIR <- dirname(DIR)
    }
  }
  invisible(NULL)
}

.readProjectId <- function(path) {
  if (!file_test("-f", path)) return("")
  Id <- yaml::read_yaml(path)$params$project_id
  if (!is.character(Id) || length(Id) != 1L || is.na(Id)) return("")
  gsub("[^a-z0-9]", "", chartr("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz", Id))
}

# Artifact seeds may name the project through {project_id}: the lowercase
# alphanumeric form of params.project_id in the project's params.yml. An id
# still equal to the one a source ships in its params.yml seed is a placeholder,
# so nothing is seeded until the project declares its own.
.seedArtifacts <- function(artifacts, root, sources) {
  if (!any(grepl("{project_id}", unlist(artifacts), fixed = TRUE))) return(artifacts)
  Id <- .readProjectId(file.path(root, "params.yml"))
  Placeholders <- vapply(sources, function(x) {
    if (is.null(x$files[["params.yml"]])) return("")
    .readProjectId(x$files[["params.yml"]]$path)
  }, character(1L))
  if (!nzchar(Id) || Id %in% Placeholders) {
    .inform("moduleNote", "artifacts not seeded: set params.project_id in params.yml and pull again",
            operation = "pull", path = "params.yml")
    return(list())
  }
  rapply(artifacts, function(x) gsub("{project_id}", Id, x, fixed = TRUE),
         classes = "character", how = "replace")
}

# The roots a producer contract declares for this project, by their first
# segment. A scaffold supplies documents; a producer's inputs and outputs belong
# to the project, whatever it decided to call them. Only declared paths are
# protected: a contract that omits a key declares nothing there, and this engine
# does not restate a producer's defaults.
.declaredRoots <- function(root) {
  OUT <- stats::setNames(character(), character())
  Root <- stringi::stri_trans_casefold(root)
  Prefix <- paste0(sub("/$", "", Root), "/")
  for (Product in c("hazard", "newmark")) {
    FILE <- file.path(root, paste0(Product, ".json"))
    if (!file_test("-f", FILE)) next
    DATA <- tryCatch(jsonlite::fromJSON(FILE, simplifyVector = TRUE), error = function(e) NULL)
    if (!is.list(DATA$path) && !is.character(DATA$path)) next
    for (Value in as.list(DATA$path)) {
      if (!is.character(Value) || length(Value) != 1L || is.na(Value) || !nzchar(Value)) next
      Path <- path.expand(Value)
      if (!fs::is_absolute_path(Path)) Path <- file.path(root, Path)
      # Outputs need not exist yet. Resolve the existing parent first so an
      # absolute path through an alias (for example /var on macOS) still matches.
      DIR <- Path
      Parts <- character()
      while (!file.exists(DIR) && dirname(DIR) != DIR) {
        Parts <- c(basename(DIR), Parts)
        DIR <- dirname(DIR)
      }
      if (!file.exists(DIR)) next
      Path <- fs::path_norm(file.path(normalizePath(DIR, winslash = "/", mustWork = TRUE),
                                      paste(Parts, collapse = "/")))
      Path <- stringi::stri_trans_casefold(Path)
      if (Path == Root || startsWith(Root, paste0(sub("/$", "", Path), "/"))) {
        OUT[["."]] <- basename(FILE)
        next
      }
      if (!startsWith(Path, Prefix)) next
      Segment <- strsplit(substring(Path, nchar(Prefix) + 1L), "/", fixed = TRUE)[[1L]][1L]
      OUT[[Segment]] <- basename(FILE)
    }
  }
  OUT
}

.planResources <- function(root, project, sources, paths, from, force) {
  Actions <- list()
  Artifacts <- list()
  Declared <- .declaredRoots(root)
  for (Name in names(sources)) {
    Source <- sources[[Name]]
    Entry <- project$scaffolds[[Name]]
    if (is.null(Entry)) Entry <- list(files = stats::setNames(list(), character()),
                                    claims = stats::setNames(list(), character()))
    if (!is.null(Entry$manifest) && !identical(Entry$manifest, Source$manifest)) {
      .inform("moduleNote", "source ", Name, " now at ", Source$manifest, " (was ", Entry$manifest, ")",
              operation = "pull", unit = Name, path = Source$manifest)
    }
    Paths <- paths
    if (!length(Paths) && !length(from)) Paths <- unlist(Entry$selection, use.names = FALSE)
    Entry$manifest <- Source$manifest
    Entry$checks <- Source$checks
    if (is.null(Entry$checks)) Entry$checks <- list()
    if (is.null(Entry$claims)) Entry$claims <- stats::setNames(list(), character())
    if (is.null(Entry$files)) Entry$files <- stats::setNames(list(), character())
    if (!"selection" %in% names(Entry)) Entry$selection <- as.list(Paths)
    if (length(Entry$selection) && length(Paths)) {
      Entry$selection <- as.list(sort(unique(c(unlist(Entry$selection), Paths)), method = "radix"))
    }
    if (!length(Paths)) Entry$selection <- list()
    Revision <- .resourceRevision(Source$manifest)
    for (Path in names(Source$files)) {
      if (!.selectedResource(Path, Paths)) next
      Resource <- Source$files[[Path]]
      Owner <- Declared["."]
      if (is.na(Owner)) {
        Owner <- Declared[stringi::stri_trans_casefold(strsplit(Path, "/", fixed = TRUE)[[1L]][1L])]
      }
      if (!is.na(Owner)) {
        .fail("Destination declared by ", Owner, " cannot be supplied: ", Path)
      }
      Target <- .confinedResource(root, Path)
      if (file.exists(Target) && !file_test("-f", Target)) {
        .fail("Destination is not a regular file: ", Path)
      }
      DIR <- dirname(Target)
      while (DIR != root) {
        if (file.exists(DIR) && !dir.exists(DIR)) .fail("Destination parent is not a directory: ", DIR)
        DIR <- dirname(DIR)
      }
      Entry$claims[[Path]] <- Resource[c("sha256", "ownership")]
      Action <- "create"
      if (file.exists(Target)) {
        Action <- "replace"
        if (Resource$ownership == "seed") Action <- "preserve"
        if (identical(digest::digest(file = Target, algo = "sha256"), Resource$sha256)) Action <- "keep"
      }
      Actions[[length(Actions) + 1L]] <- list(source = Name, path = Path, resource = Resource, action = Action)
      if (Resource$ownership == "managed") {
        Entry$files[[Path]] <- c(Revision, list(md5 = unname(tools::md5sum(Resource$path)), sha256 = Resource$sha256))
      }
    }
    Entry$complete <- all(vapply(names(Entry$claims), function(x) {
      Entry$claims[[x]]$ownership != "managed" || x %in% names(Entry$files)
    }, logical(1L)))
    project$scaffolds[[Name]] <- Entry
    for (Artifact in Source$artifacts) {
      if (!.isResourceObject(Artifact) || !is.character(Artifact$alias) || length(Artifact$alias) != 1L) {
        .fail("Invalid artifact seed in ", Name)
      }
      Alias <- Artifact$alias
      if (Alias %in% names(Artifacts) && !.sameResourceValue(Artifacts[[Alias]], Artifact)) {
        .fail("Incompatible artifact seeds at alias ", Alias)
      }
      Artifacts[[Alias]] <- Artifact
    }
  }
  if (!length(project$artifacts)) {
    project$artifacts <- .seedArtifacts(unname(Artifacts), root = root, sources = sources)
  }
  for (Name in names(project$scaffolds)) {
    Entry <- project$scaffolds[[Name]]
    if (Name %in% names(sources) || "claims" %in% names(Entry)) next
    for (Path in names(Entry$files)) {
      if (any(vapply(Actions, function(x) identical(Path, x$path), logical(1L)))) {
        .fail("Unresolved legacy claim from ", Name, " at ", Path)
      }
    }
  }
  .checkResourceClaims(project)
  Conflicts <- vapply(Filter(function(x) x$action == "replace", Actions), `[[`, character(1L), "path")
  if (length(Conflicts) && !force) .fail("Local differences require --force: ", paste(Conflicts, collapse = ", "))
  list(manifest = project, actions = Actions)
}

.replaceResource <- function(from, to) {
  Path <- tempfile(".ngr-", tmpdir = dirname(to))
  on.exit(unlink(Path), add = TRUE)
  if (!file.copy(from, Path, copy.mode = TRUE, copy.date = TRUE) || !file.rename(Path, to)) {
    .fail("Cannot replace resource: ", to)
  }
  invisible(NULL)
}

.applyResources <- function(root, manifest, actions) {
  Stage <- tempfile("ngr-pull-")
  if (!dir.create(Stage)) .fail("Cannot create resource staging directory")
  Cleanup <- TRUE
  on.exit(if (Cleanup) unlink(Stage, recursive = TRUE), add = TRUE)
  Writes <- list()
  for (Action in actions) {
    if (!Action$action %in% c("create", "replace")) next
    Path <- file.path(Stage, "source", Action$path)
    dir.create(dirname(Path), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(Action$resource$path, Path, overwrite = TRUE, copy.mode = TRUE, copy.date = TRUE)) {
      .fail("Cannot stage resource: ", Action$path)
    }
    if (!identical(digest::digest(file = Path, algo = "sha256"), Action$resource$sha256)) {
      .fail("Source changed during pull: ", Action$path)
    }
    Writes[[Action$path]] <- Path
  }
  Path <- file.path(Stage, "manifest.json")
  jsonlite::write_json(manifest, Path, auto_unbox = TRUE, pretty = TRUE, null = "null", digits = NA)
  Writes[["manifest.json"]] <- Path
  Backups <- list()
  for (Name in names(Writes)) {
    Target <- .confinedResource(root, Name)
    Backups[Name] <- list(NULL)
    if (!file.exists(Target)) next
    Path <- file.path(Stage, "backup", Name)
    dir.create(dirname(Path), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(Target, Path, copy.mode = TRUE, copy.date = TRUE)) {
      .fail("Cannot back up resource: ", Name)
    }
    Backups[[Name]] <- Path
  }
  Written <- Created <- character()
  tryCatch({
    for (Name in names(Writes)) {
      Target <- .confinedResource(root, Name)
      Parents <- character()
      DIR <- dirname(Target)
      while (DIR != root && !dir.exists(DIR)) {
        Parents <- c(DIR, Parents)
        DIR <- dirname(DIR)
      }
      for (DIR in Parents) {
        if (!dir.create(DIR)) .fail("Cannot create resource directory: ", DIR)
        Created <- c(Created, DIR)
      }
      .replaceResource(from = Writes[[Name]], to = Target)
      Written <- c(Written, Name)
    }
  }, error = function(e) {
    tryCatch({
      for (Name in rev(Written)) {
        if (is.null(Backups[[Name]])) {
          if (unlink(file.path(root, Name)) != 0L) .fail("Cannot remove resource: ", Name)
          next
        }
        if (!file.copy(Backups[[Name]], file.path(root, Name), overwrite = TRUE, copy.mode = TRUE, copy.date = TRUE)) {
          .fail("Cannot restore resource: ", Name)
        }
      }
      for (DIR in rev(Created)) {
        if (length(list.files(DIR, all.files = TRUE, no.. = TRUE)) || unlink(DIR, recursive = TRUE) != 0L) {
          .fail("Cannot remove created directory: ", DIR)
        }
      }
    }, error = function(error) {
      Cleanup <<- FALSE
      stop(errorCondition(paste0("Rollback failed; recovery retained at ", Stage, ": ", conditionMessage(error)),
                          class = "moduleFailure", parent = e, recovery = Stage))
    })
    stop(e)
  })
  invisible(NULL)
}

#' Incorporate and update project resources
#'
#' Sources declare mappings to shared project paths. All implicated claims are
#' checked before writes, including claims of sources not selected for update.
#' Existing seeds, extra project files and scientific data are preserved. Files
#' retired from a source are not deleted. Ordinary write errors restore the
#' files already written; concurrent writers and process termination are not
#' covered by this recovery.
#'
#' @param from Character vector of source manifest paths, or `NULL` to use
#'   existing project associations. Relative paths resolve from the R working
#'   directory. A source is identified by its `id`: a manifest whose `id` is
#'   already associated re-points that association to the new location, with a
#'   message. Incompatible with a nonempty `source`.
#' @param source Registered source identities, or `NULL` for all associations.
#' @param paths Destination files or directory prefixes. Empty selection uses
#'   the enrolled selection, or the complete source when `from` is supplied.
#' @param root Existing project directory; defaults to the working directory.
#' @param force Replace different managed files; never replace existing seeds
#'   or override incompatible source claims.
#' @param dryRun Return the same validated plan without writing files.
#' @return A list containing `actions` (a data frame with source, path and
#'   action columns) and `manifest` (the resulting project manifest).
#' @export
pullResources <- function(from = NULL, source = NULL, paths = character(),
                          root = getwd(), force = FALSE, dryRun = FALSE) {
  Root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  if (!dir.exists(Root)) .fail("Project root must be a directory")
  Project <- .readResourceProject(Root)
  Sources <- .loadResourceSources(from = from, source = source, paths = paths, project = Project)
  Plan <- .planResources(root = Root, project = Project, sources = Sources,
                         paths = paths, from = from, force = force)
  if (!dryRun) .applyResources(root = Root, manifest = Plan$manifest, actions = Plan$actions)
  Actions <- data.frame(source = character(), path = character(), action = character())
  if (length(Plan$actions)) {
    Actions <- as.data.frame(lapply(c("source", "path", "action"), function(x) {
      vapply(Plan$actions, `[[`, character(1L), x)
    }), stringsAsFactors = FALSE)
    names(Actions) <- c("source", "path", "action")
  }
  list(actions = Actions, manifest = Plan$manifest)
}

#' Compare project resources with their sources
#'
#' Reads sources, local files and per-file receipts without writing them.
#' @inheritParams pullResources
#' @param from Character vector of source manifest paths to compare against
#'   instead of the recorded locations, or `NULL` to use existing project
#'   associations. Associations are read, never re-pointed. Incompatible with a
#'   nonempty `source`.
#' @return A list with `files` (source, state, path and modified columns) and
#'   `changed`, which is true for differences, missing/retired files or edits
#'   against a receipt. Customized seeds alone do not set `changed`.
#' @export
compareResources <- function(from = NULL, source = NULL, paths = character(), root = getwd()) {
  Root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  Project <- .readResourceProject(Root)
  Sources <- .loadResourceSources(from = from, source = source, paths = paths, project = Project)
  Files <- data.frame(source = character(), state = character(), path = character(), modified = logical())
  for (Name in names(Sources)) {
    Source <- Sources[[Name]]
    Entry <- Project$scaffolds[[Name]]
    Paths <- paths
    if (!length(Paths)) Paths <- unlist(Entry$selection, use.names = FALSE)
    for (Path in sort(union(names(Source$files), names(Entry$claims)), method = "radix")) {
      if (!.selectedResource(Path, Paths)) next
      FILE <- .confinedResource(Root, Path)
      Resource <- Source$files[[Path]]
      State <- "retired"
      if (!is.null(Resource)) {
        State <- "missing"
        if (file.exists(FILE)) State <- "different"
        if (file_test("-f", FILE) && identical(digest::digest(file = FILE, algo = "sha256"), Resource$sha256)) State <- "equal"
        if (State == "different" && Resource$ownership == "seed") State <- "project-seed"
      }
      Receipt <- Entry$files[[Path]]
      Modified <- length(Receipt) > 0L && (!file_test("-f", FILE) || !identical(unname(tools::md5sum(FILE)), Receipt$md5))
      Files[nrow(Files) + 1L, ] <- list(Name, State, Path, Modified)
    }
  }
  list(files = Files, changed = any(!Files$state %in% c("equal", "project-seed") | Files$modified))
}

#' Run checks declared by registered resource sources
#'
#' Validates all applied source claims, then runs the selected sources' declared
#' argument vectors in the project directory. Those commands can have effects;
#' this is not a read-only query. A failed command stops the operation.
#' @inheritParams pullResources
#' @return Invisibly, a list of completed checks with source, command and status.
#' @export
checkResources <- function(source = NULL, root = getwd()) {
  Root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  Project <- .readResourceProject(Root)
  .checkResourceClaims(Project)
  if (!length(source)) source <- names(Project$scaffolds)
  WD <- getwd()
  on.exit(setwd(WD), add = TRUE)
  setwd(Root)
  Checks <- list()
  for (Name in source) {
    if (!Name %in% names(Project$scaffolds)) .fail("Unknown registered source: ", Name)
    for (Check in Project$scaffolds[[Name]]$checks) {
      Args <- unlist(Check, use.names = FALSE)
      .inform("moduleProgress", Name, ": ", paste(Args, collapse = " "), operation = "doctor", unit = Name)
      Status <- system2(Args[[1L]], args = shQuote(Args[-1L]))
      if (Status != 0L) .fail("Source check failed: ", Name, " (exit ", Status, ")")
      Checks[[length(Checks) + 1L]] <- list(source = Name, command = Check, status = Status)
    }
  }
  invisible(Checks)
}
