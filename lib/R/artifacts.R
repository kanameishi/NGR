.readArtifacts <- function(manifest, root) {
  if (!grepl("^(/|[A-Za-z]:|\\\\\\\\)", manifest)) manifest <- file.path(root, manifest)
  DATA <- jsonlite::fromJSON(manifest, simplifyVector = FALSE)
  if (!is.list(DATA) || is.null(names(DATA)) || !is.numeric(DATA$schemaVersion) ||
      length(DATA$schemaVersion) != 1L || !DATA$schemaVersion %in% c(1, 2) ||
      !is.list(DATA$artifacts) || !is.null(names(DATA$artifacts)) || !length(DATA$artifacts)) {
    .fail("Invalid artifact manifest: ", manifest)
  }
  Artifacts <- DATA$artifacts
  for (i in seq_along(Artifacts)) {
    Entry <- Artifacts[[i]]
    if (!is.list(Entry) || is.null(names(Entry))) {
      .fail("Invalid artifact at position ", i, ".")
    }
    for (Field in c("alias", "path", "siteSlug", "domain")) {
      x <- Entry[[Field]]
      if (is.null(x) && Field %in% c("siteSlug", "domain")) next
      if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
        .fail("Invalid artifact ", Field, " at position ", i, ".")
      }
    }
    if (!is.logical(Entry$required) || length(Entry$required) != 1L || is.na(Entry$required)) {
      .fail("Artifact required must be boolean: ", Entry$alias)
    }
    if (DATA$schemaVersion == 1) {
      Entry$kind <- if (is.null(Entry$renderSource)) "static" else "quarto"
    }
    if (!is.character(Entry$kind) || length(Entry$kind) != 1L ||
        !Entry$kind %in% c("quarto", "static", "map")) {
      .fail("Invalid artifact kind: ", Entry$alias)
    }
    if (Entry$kind %in% c("quarto", "map") &&
        (!is.character(Entry$renderSource) || length(Entry$renderSource) != 1L ||
         is.na(Entry$renderSource) || !nzchar(Entry$renderSource))) {
      .fail("Invalid artifact renderSource: ", Entry$alias)
    }
    if (Entry$kind == "quarto" &&
        (!is.character(Entry$profile) || length(Entry$profile) != 1L ||
         !Entry$profile %in% c("book", "html", "revealjs", "docx"))) {
      .fail("Invalid artifact profile: ", Entry$alias)
    }
    if ((Entry$kind != "quarto" && !is.null(Entry$profile)) ||
        (Entry$kind == "static" && !is.null(Entry$renderSource))) {
      .fail("Invalid rendering fields for ", Entry$kind, ": ", Entry$alias)
    }
    Artifacts[[i]] <- Entry
  }
  Aliases <- vapply(Artifacts, `[[`, character(1L), "alias")
  if (anyDuplicated(Aliases)) .fail("Duplicate artifact alias.")
  Artifacts
}

.selectArtifacts <- function(artifacts, only, except) {
  if (!is.character(only) || anyNA(only) || !is.character(except) || anyNA(except)) {
    .fail("Artifact selections must be character vectors without missing values.")
  }
  Aliases <- vapply(artifacts, `[[`, character(1L), "alias")
  Missing <- setdiff(c(only, except), Aliases)
  if (length(Missing)) .fail("Unknown alias in selection: ", paste(Missing, collapse = ","))
  Selected <- artifacts[(length(only) == 0L | Aliases %in% only) & !Aliases %in% except]
  if (!length(Selected)) .fail("No artifacts selected.")
  Selected
}

.artifactOutput <- function(artifact) {
  if (artifact$kind == "quarto" && artifact$profile == "docx") {
    return(file.path(artifact$path, paste0(sub("\\.md$", "", sub("\\.qmd$", "", basename(artifact$renderSource))), ".docx")))
  }
  file.path(artifact$path, "index.html")
}
