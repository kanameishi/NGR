# nolint start
#' Build Quarto YAML and prepare project structure
#'
#' Assemble a consolidated Quarto configuration (`_quarto.yml`) by merging project files
#' (parameters, authors, format-specific YAMLs) with language-specific variants when present.
#' Copies package support files into `build_dir`, ensures a clean `publish_dir`, and writes
#' the final `_quarto.yml`. Rendering is not performed; use Quarto CLI or
#' `quarto::quarto_render()` after calling this function.
#'
#' @param build_dir Directory where package support files are copied (created if needed).
#' @param publish_dir Output directory configured in the generated `_quarto.yml` (re-created).
#' @param index_filename Report entrypoint (e.g. `index.qmd`). Used to invoke Quarto downstream.
#' @param quarto_filename Target filename for the generated Quarto config (default `_quarto.yml`).
#' @param language Language code (e.g. `"EN"`, `"ES"`) to pick suffixed files like `_html_ES.yml`.
#' @param output_format Character vector of output formats to include (e.g. `c("html","pdf")`).
#' @param extensions Reserved for future cleanup behavior (currently used only on error paths).
#'
#' @import data.table
#' @import yaml
#' @export
buildYAML <- function(
    build_dir = "_build",
    publish_dir = "_publish",
    index_filename = "index.qmd",
    quarto_filename = "_quarto.yml",
    language = "EN",
    output_format = c("html"),
    extensions = c("spl", "bst", "cls", "md", "aux", "log", "tex", "jpg", "sty","docx", "pdf", "html")
) {
  . <- NULL 
  
  # Pre-render function
  .preRender <- function() {
    paths <- c(
      file.path(build_dir)
    )
    for (path in paths) {
      if (dir.exists(path)) {
        subdirs <- list.dirs(path = path, full.names = TRUE, recursive = TRUE)[-1]
        unlink(subdirs, recursive = TRUE, force = TRUE)
      }
    }
  }
  
  # Build YAML function
  .buildYAML <- function(){
    
    LANG <- language
    
    # Initialize DATA and LDATA as empty lists
    DATA <- list()
    LDATA <- list()
    
    # ---------------------------------------------------------------------------
    # Language-independent stage
    
    # Project settings
    FIELD <- list(
      project = list(
        type = "default",
        'output-dir' = publish_dir
        
      ),
      engine = "knitr",
      jupyter = "python3"
    )
    DATA <- .merge(DATA, FIELD)
    
    # Bibliography
    FILE <- list.files(".", pattern = "references\\.bib$", recursive = TRUE, full.names = TRUE)
    if (length(FILE) > 0) {
      FIELD <- list(bibliography = FILE[1])
      DATA <- .merge(DATA, FIELD)
    }
    
    # Authors
    FILE <- list.files(".", pattern = "_authors\\.yml$", recursive = TRUE, full.names = TRUE)
    has_authors_yml <- length(FILE) > 0
    if (has_authors_yml) {
      FIELD <- read_yaml(FILE[1], readLines.warn = FALSE)
      FIELD$author <- Filter(.validAuthor, FIELD$author)
      DATA <- .merge(DATA, FIELD)
    }
    
    # Parameters
    FILE <- list.files(".", pattern = paste0("_params_", LANG, "\\.yml$"), recursive = TRUE, full.names = TRUE)
    if (length(FILE) == 0) {
      FILE <- list.files(".", pattern = "_params\\.yml$", recursive = TRUE, full.names = TRUE)
    }
    if (length(FILE) > 0) {
      FIELD <- read_yaml(FILE[1], readLines.warn = FALSE)
      if (has_authors_yml) {
        FIELD$author <- NULL  # Remove author field if _authors.yml exists
      }
      DATA <- .merge(DATA, FIELD)
    }

    # HTML
    if ("html" %in% output_format) {
      FILE <- list.files(".", pattern = paste0("_html_", LANG, "\\.yml$"), recursive = TRUE, full.names = TRUE)
      if (length(FILE) == 0) {
        FILE <- list.files(".", pattern = "_html\\.yml$", recursive = TRUE, full.names = TRUE)
      }
      if (length(FILE) > 0) {
        FIELD <- read_yaml(FILE[1], readLines.warn = FALSE)
        if (!is.null(FIELD$format)) {
          FIELD$format <- FIELD$format[names(FIELD$format) %in% output_format]
        }
        DATA <- .merge(DATA, FIELD)
      } else {stop("No yaml headers file found")}
    }
      
    
    # Reveal.js
    if ("revealjs" %in% output_format) {
      FILE <- list.files(".", pattern = paste0("_revealjs_", LANG, "\\.yml$"), recursive = TRUE, full.names = TRUE)
      if (length(FILE) == 0) {
        FILE <- list.files(".", pattern = "_revealjs\\.yml$", recursive = TRUE, full.names = TRUE)
      }
      if (length(FILE) > 0) {
        FIELD <- read_yaml(FILE[1], readLines.warn = FALSE)
        if (!is.null(FIELD$format)) {
          FIELD$format <- FIELD$format[names(FIELD$format) %in% output_format]
        }
        DATA <- .merge(DATA, FIELD)
      } else {stop("No yaml headers file found")}
      
    }
    
    # DOCX
    if ("docx" %in% output_format) {
      FILE <- list.files(".", pattern = paste0("_docx_", LANG, "\\.yml$"), recursive = TRUE, full.names = TRUE)
      if (length(FILE) == 0) {
        FILE <- list.files(".", pattern = "_docx\\.yml$", recursive = TRUE, full.names = TRUE)
      }
      if (length(FILE) > 0) {
        FIELD <- read_yaml(FILE[1], readLines.warn = FALSE)
        if (!is.null(FIELD$format)) {
          FIELD$format <- FIELD$format[names(FIELD$format) %in% output_format]
        }
        DATA <- .merge(DATA, FIELD)
      } else {stop("No yaml headers file found")}
      # Styles for DOCX
      FILE <- list.files(".", pattern = "\\.docx$", recursive = TRUE, full.names = TRUE)
      if (length(FILE) > 0) {
        DOCSTYLE <- file.path(build_dir, basename(FILE[1]))
        FIELD <- list(format = list(docx = list("reference-doc" = DOCSTYLE)))
        DATA <- .merge(DATA, FIELD)
      }
      
    }
    
    
    # PDF
    if ("pdf" %in% output_format) {
      FILE <- list.files(".", pattern = paste0("_pdf_", LANG, "\\.yml$"), recursive = TRUE, full.names = TRUE)
      if (length(FILE) == 0) {
        FILE <- list.files(".", pattern = "_pdf\\.yml$", recursive = TRUE, full.names = TRUE)
      }
      if (length(FILE) > 0) {
        FIELD <- read_yaml(FILE[1], readLines.warn = FALSE)
        if (!is.null(FIELD$format)) {
          FIELD$format <- FIELD$format[names(FIELD$format) %in% output_format]
        }
        DATA <- .merge(DATA, FIELD)
      } else {stop("No yaml headers file found")}
    }
    
    # Elsevier PDF
    if ("els-pdf" %in% output_format) {
      FILE <- list.files(".", pattern = "_els-pdf\\.yml$", recursive = TRUE, full.names = TRUE)
      if (length(FILE) > 0) {
        FIELD <- read_yaml(FILE[1], readLines.warn = FALSE)
        FIELD$format <- FIELD$format[names(FIELD$format) %in% output_format]
        if (is.null(FIELD$format$`els-pdf`$journal$name)) {
          FIELD$format$`els-pdf`$journal$name <- gsub(DATA$subtitle, pattern = "\n", replacement = "")
        }
        DATA <- .merge(DATA, FIELD)
      }
    }
    
   # Detect PNG files
   FILE <- list.files(".", pattern = "logo\\.png$", recursive = TRUE, full.names = TRUE)
   if (length(FILE) > 0) {
     # Suppose you specifically want the first PNG to be your 'logo'
     LOGO <- file.path(build_dir, basename(FILE[1]))
     if ("html" %in% output_format) {
       FIELD <- list(format = list(html = list(logo = LOGO)))
       DATA <- .merge(DATA, FIELD)
     }
     if ("revealjs" %in% output_format) {
       FIELD <- list(format = list(revealjs = list(logo = LOGO)))
       DATA <- .merge(DATA, FIELD)
     }
   }

   # Detect CSS files
   FILE <- list.files(".", pattern = "\\.css$", recursive = TRUE, full.names = TRUE)
  if (length(FILE) > 0) {
     # Convert each file into a path that includes build_dir
     CSS <- file.path(build_dir, basename(FILE))


     if ("html" %in% output_format) {
       FIELD <- list(format = list(html = list(css = CSS)))
       DATA <- .merge(DATA, FIELD)
     }
     if ("revealjs" %in% output_format) {
       FIELD <- list(format = list(revealjs = list(css = CSS)))
       DATA <- .merge(DATA, FIELD)
     }
   }
    
    
    # ---------------------------------------------------------------------------
    # LANGUAGE-DEPENDENT STAGE
    
    # Cross-references
    FILE <- list.files(".", pattern = "_crossref\\.yml$", recursive = TRUE, full.names = TRUE)
    if (length(FILE) > 0) {
      FIELD <- yaml::read_yaml(FILE[1], readLines.warn = FALSE)
      LDATA <- .merge(LDATA, FIELD[[LANG]])
    }
    
    # Title
    FILE <- list.files(".", pattern = paste0("_TITLE_", LANG, "\\.qmd$"), recursive = TRUE, full.names = TRUE)
    if (length(FILE) == 0) {
      FILE <- list.files(".", pattern = "_TITLE\\.qmd$", recursive = TRUE, full.names = TRUE)
    }
    if (length(FILE) > 0) {
      VAR <- brio::read_lines(FILE[1]) |> paste(collapse = "\n")
      FIELD <- list(title = VAR)
      LDATA <- .merge(LDATA, FIELD)
    }
    
    # Subtitle
    FILE <- list.files(".", pattern = paste0("_SUBTITLE_", LANG, "\\.qmd$"), recursive = TRUE, full.names = TRUE)
    if (length(FILE) == 0) {
      FILE <- list.files(".", pattern = "_SUBTITLE\\.qmd$", recursive = TRUE, full.names = TRUE)
    }
    if (length(FILE) > 0) {
      VAR <- brio::read_lines(FILE[1]) |> paste(collapse = "\n")
      FIELD <- list(subtitle = VAR)
      LDATA <- .merge(LDATA, FIELD)
    }
    
    # Abstract
    FILE <- list.files(".", pattern = paste0("_ABSTRACT_", LANG, "\\.qmd$"), recursive = TRUE, full.names = TRUE)
    if (length(FILE) == 0) {
      FILE <- list.files(".", pattern = "_ABSTRACT\\.qmd$", recursive = TRUE, full.names = TRUE)
    }
    if (length(FILE) > 0) {
      VAR <- brio::read_lines(FILE[1]) |> paste(collapse = "\n")
      FIELD <- list(abstract = VAR)
      LDATA <- .merge(LDATA, FIELD)
    }
    
    # Additional parameters
    FIELD <- list(params = list(
      background = "white",
      render = "none",
      ext = "png",
      lang = LANG
    ))
    LDATA <- .merge(LDATA, FIELD)
    
    # ---------------------------------------------------------------------------
    # Combine DATA and LDATA
    DATA <- .merge(DATA, LDATA)
    
    # Filter formats
    if (!is.null(DATA$format)) {
      DATA$format <- DATA$format[names(DATA$format) %in% output_format]
    }
    
    # Convert to YAML
    YAML <- yaml::as.yaml(DATA)
    YAML <- gsub(pattern = ":\\s*yes($|\\n)", replacement = ": true\\1", YAML)
    YAML <- gsub(pattern = ":\\s*no($|\\n)", replacement = ": false\\1", YAML)
    
    # Always remove existing quarto_filename, then recreate
    unlink(quarto_filename, recursive = FALSE, force = TRUE)
    brio::write_lines(text = YAML, path = quarto_filename)
  }
  
  # Post-render function
  .postRender <- function() {
    # Remove files with specified extensions in the project folder
    pattern <- paste0("\\.(", paste(extensions, collapse = "|"), ")$")
    files <- list.files(
      path = ".",
      pattern = pattern,
      ignore.case = TRUE,
      full.names = TRUE
    )
    if (length(files) > 0) {
      file.remove(files)
    }
    
  }
  
  # Additional helper functions
  .merge <- function(x, y) {
    if (is.list(x) && is.list(y)) {
      for (name in names(y)) {
        if (name %in% names(x)) {
          x[[name]] <- .merge(x[[name]], y[[name]])
        } else {
          x[[name]] <- y[[name]]
        }
      }
      return(x)
    } else {
      return(y)
    }
  }
  
  .validAuthor <- function(author) {
    fields_to_check <- c("name", "orcid", "email")
    for (field in fields_to_check) {
      if (!is.null(author[[field]])) {
        return(TRUE)
      }
    }
    return(FALSE)
  }
  # Get package resources path
  extdata_path <- system.file("extdata", package = "smartReports")

  # 1) Copy _extensions folder (if it exists) from extdata_path to current dir (".")
  extensions_folder <- file.path(extdata_path, "_extensions")
  if (dir.exists(extensions_folder)) {
    file.copy(
      from = extensions_folder,
      to = ".",   # copy to top-level working directory
      recursive = TRUE,
      overwrite = TRUE
    )
    .inform("moduleNote", "Copied _extensions folder to current directory!", operation = "buildYAML")
  }

  # 2) Now copy all other support files/folders into build_dir
  if (!dir.exists(build_dir)) {
    dir.create(build_dir, recursive = TRUE)

    # Exclude the _extensions folder (already handled above)
    files_to_copy <- list.files(extdata_path, full.names = TRUE)
    files_to_copy <- files_to_copy[basename(files_to_copy) != "_extensions"]

    # Also exclude build_dir itself just in case
    excluded_folder <- basename(build_dir)
    files_to_copy <- files_to_copy[basename(files_to_copy) != excluded_folder]

    file.copy(
      from = files_to_copy,
      to = build_dir,
      recursive = TRUE,
      overwrite = TRUE
    )
    .inform("moduleNote", "Project structure initialized successfully in build_dir!", operation = "buildYAML")
  }

  # Always refresh the publish_dir so it's guaranteed to be clean
  unlink(publish_dir, recursive = TRUE, force = TRUE)
  dir.create(publish_dir, recursive = TRUE)
  
  # Main execution flow
  tryCatch({
    .preRender()
    
    # Build the YAML configuration
    .buildYAML()

    
  }, error = function(e) {
    .inform("moduleNote", "Error during rendering: ", e$message, operation = "buildYAML")
    .postRender()
    stop(e)
  })
}
# nolint end
