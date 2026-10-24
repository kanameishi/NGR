#' Display markdown file as rendered HTML via iframe
#'
#' @param filePath Path to markdown file (will be rendered to HTML at runtime)
#' @param height Height of iframe (default "500px")
#' @param theme HTML theme (default "spacelab")
#' @param toc Show table of contents (default FALSE)
#' @param force Force re-render even if HTML is up to date (default FALSE)
#' @param fontsize Base font size (e.g., "0.8em", "14px", "90%", default NULL = theme default)
#' @return Prints iframe HTML using cat() for results: asis
#' @export
showMarkdownRendered <- function(filePath, height = "500px", theme = "spacelab", toc = FALSE, force = FALSE, fontsize = NULL) {
  if (!file.exists(filePath)) {
    stop(paste("File not found:", filePath))
  }
  
  HTML_PATH <- sub("\\.md$", ".html", filePath)
  
  # OPTIMIZATION: Only render if HTML doesn't exist or is older than MD
  SHOULD_RENDER <- force || !file.exists(HTML_PATH) || 
    file.info(filePath)$mtime > file.info(HTML_PATH)$mtime
  
  if (SHOULD_RENDER) {
    .inform("moduleNote", "Rendering ", basename(filePath), " (HTML missing or outdated)",
            operation = "showMarkdownRendered", path = filePath)
    
    CONTENT <- readLines(filePath, warn = FALSE)
    
    # Search for bibliography file in the same directory as the markdown file
    MD_DIR <- dirname(filePath)
    BIB_FILE <- NULL
    
    BIB_PATH_1 <- file.path(MD_DIR, "biblatex.bib")
    BIB_PATH_2 <- file.path(MD_DIR, "references.bib")
    
    if (file.exists(BIB_PATH_1)) {
      BIB_FILE <- basename(BIB_PATH_1)  # Use relative path for Quarto
    } else if (file.exists(BIB_PATH_2)) {
      BIB_FILE <- basename(BIB_PATH_2)  # Use relative path for Quarto
    }
    
    YAML_HEADER <- c(
      "---",
      "format:",
      "  html:",
      paste0("    theme: ", theme),
      "    highlight-style: tango",
      paste0("    toc: ", tolower(as.character(toc))),
      "    toc-depth: 4",
      "    number-sections: false",
      "    code-fold: true",
      "    code-tools: true",
      "    embed-resources: true"
    )
    
    if (!is.null(fontsize)) {
      YAML_HEADER <- c(YAML_HEADER, paste0("fontsize: ", fontsize))
    }
    
    if (!is.null(BIB_FILE)) {
      YAML_HEADER <- c(YAML_HEADER, paste0("bibliography: ", BIB_FILE))
    }
    
    YAML_HEADER <- c(YAML_HEADER, "---", "")
    
    if (!grepl("^---", CONTENT[1])) {
      CONTENT <- c(YAML_HEADER, CONTENT)
    }
    
    TEMP_FILE <- file.path(dirname(filePath), paste0("._temp_", basename(filePath)))
    writeLines(CONTENT, TEMP_FILE)
    
    QUARTO_CMD <- Sys.which("quarto")
    if (QUARTO_CMD == "") QUARTO_CMD <- "/usr/local/bin/quarto"
    
    system2(QUARTO_CMD, c("render", TEMP_FILE, "--to", "html"), stdout = FALSE, stderr = FALSE)
    
    TEMP_HTML <- sub("\\.md$", ".html", TEMP_FILE)
    if (file.exists(TEMP_HTML)) file.rename(TEMP_HTML, HTML_PATH)
    
    unlink(TEMP_FILE)
    TEMP_FILES_DIR <- sub("\\.md$", "_files", TEMP_FILE)
    if (dir.exists(TEMP_FILES_DIR)) unlink(TEMP_FILES_DIR, recursive = TRUE)
  } else {
    .inform("moduleNote", "Using cached HTML for ", basename(filePath),
            operation = "showMarkdownRendered", path = filePath)
  }
  
  HTML_RELATIVE <- HTML_PATH
  
  cat('\n<iframe\n')
  cat('  src="', HTML_RELATIVE, '"\n', sep = "")
  cat('  width="100%"\n')
  cat('  height="', height, '"\n', sep = "")
  cat('  style="border:0; max-width: 100%;"\n')
  cat('  loading="lazy"\n')
  cat('></iframe>\n\n')
  
  cat('<p style="font-size: 0.8em; margin-top: 5px; text-align: center;">\n')
  cat('<a href="', HTML_RELATIVE, '" target="_blank">Open in new window</a>\n', sep = "")
  cat('</p>\n\n')
}
