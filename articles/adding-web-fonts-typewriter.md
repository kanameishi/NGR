# Adding Web Fonts to Typewriter Functions

## Overview

This document describes the process for adding new Google Fonts (or
other web fonts) to the typewriter effect functions in the NGR package.
The typewriter functions include: -
[`showTypewriter()`](https://kanameishi.github.io/NGR/reference/showTypewriter.md) -
R/typewriter.R -
[`rotateTypewriter()`](https://kanameishi.github.io/NGR/reference/rotateTypewriter.md) -
R/rotateTypewriter.R

## When to Add a Font

Users may request specific fonts to match a particular aesthetic or
theme. For example: - Vintage computer terminals (VT323, IBM Plex Mono,
Courier Prime) - Retro gaming displays (Press Start 2P, Silkscreen,
Pixelify Sans) - Sci-fi interfaces (Orbitron, Electrolize) - used for
HAL 9000 style from 2001: A Space Odyssey

## Process for Adding a New Web Font

### 1. Identify the Font Source

- **Google Fonts** (recommended): Check if the font is available at
  <https://fonts.google.com>
- **Local System Fonts**: For proprietary fonts that users must install
  on their system
- **Custom Web Fonts**: Fonts hosted elsewhere (requires @font-face CSS)

### 2. Get the Google Fonts Link

For Google Fonts: 1. Go to the font page on Google Fonts 2. Select the
weights needed (typically 400 and 700) 3. Copy the `<link>` URL or use
the format:
`https://fonts.googleapis.com/css2?family=Font+Name:wght@400;700&display=swap`

### 3. Add Font Configuration to BOTH Functions

**CRITICAL**: You must add the font to BOTH `typewriter.R` AND
`rotateTypewriter.R`

#### File: R/typewriter.R

Add to the `fontConfig` switch statement (around line 38):

``` r
"fontname" = list(
  family = "'Font Display Name', sans-serif",  # or monospace
  link = "https://fonts.googleapis.com/css2?family=Font+Name:wght@400;700&display=swap"
),
```

#### File: R/rotateTypewriter.R

Add to the `fontConfig` switch statement (around line 38):

``` r
"fontname" = list(
  family = "'Font Display Name', sans-serif",  # or monospace
  link = "https://fonts.googleapis.com/css2?family=Font+Name:wght@400;700&display=swap"
),
```

**Note**: For local fonts, use:

``` r
"fontname" = list(
  family = "'Font Name', monospace",
  link = NULL,
  local = "FontName"
),
```

### 4. Update Documentation

Update the `@param font` roxygen comment in both files to include the
new font name:

``` r

#' @param font Font name: "vt323", "ibm", "courier", ..., "newfont", ... (default "vt323")
```

### 5. Rebuild and Install Package

``` bash
cd /path/to/NGR
R CMD build .
R CMD INSTALL NGR_*.tar.gz
```

## Text Input Character Escaping

The typewriter functions handle special characters in text input that
could break JavaScript:

### Characters That Need Escaping

1.  **Backslashes** (`\`) - Must be escaped FIRST
2.  **Newlines** (`\n`) - Converted to `\\n` for JavaScript
3.  **Carriage returns** (`\r`) - Converted to `\\r`
4.  **Backticks** (`` ` ``) - Used in template literals, must be escaped
5.  **Dollar signs** (`$`) - Used in template literal interpolation,
    must be escaped

### Escaping Implementation

Located in both `typewriter.R` (lines 135-139) and `rotateTypewriter.R`
(lines 118-123):

``` r

# Escape for JavaScript (order matters!)
content_escaped <- gsub("\\\\", "\\\\\\\\", content)  # Backslashes FIRST
content_escaped <- gsub("\n", "\\\\n", content_escaped)  # Newlines
content_escaped <- gsub("\r", "\\\\r", content_escaped)  # Carriage returns
content_escaped <- gsub("`", "\\\\`", content_escaped)   # Backticks
content_escaped <- gsub("\\$", "\\\\$", content_escaped) # Dollar signs
```

**CRITICAL**: Backslashes must be escaped first, otherwise subsequent
escapes will double-escape.

### Testing Special Characters

When adding or modifying text handling, test with: - Text containing
backslashes: `path\to\file` - Text with quotes: `He said "hello"` - Text
with backticks: `` `code` `` - Text with dollar signs: `$variable` -
Multi-line text with `\n` characters

## Common Issues

### Issue: Font Not Loading

**Symptoms**: Text appears in default system font instead of selected
font **Causes**: 1. Font name misspelled in switch statement 2. Font not
added to both `typewriter.R` AND `rotateTypewriter.R` 3. Package not
rebuilt after changes 4. RStudio session not restarted after reinstall

**Solution**: - Check both files have identical font configurations -
Rebuild package: `R CMD build . && R CMD INSTALL NGR_*.tar.gz` - Restart
R session

### Issue: JavaScript Errors in Browser Console

**Symptoms**: Typewriter effect doesn’t work, console shows syntax
errors **Causes**: 1. Special characters not properly escaped 2. Text
contains unescaped backticks or dollar signs 3. Backslash escaping order
is wrong

**Solution**: - Review character escaping code - Ensure backslashes are
escaped first - Test with problematic text samples

## Example: Adding Orbitron Font

Request: “Add Orbitron font for HAL 9000 style displays”

### Step 1: Research

- Font: Orbitron from Google Fonts
- URL:
  <https://fonts.googleapis.com/css2?family=Orbitron:wght@400;700&display=swap>
- Type: sans-serif (geometric, futuristic)

### Step 2: Add to typewriter.R

``` r
"orbitron" = list(
  family = "'Orbitron', sans-serif",
  link = "https://fonts.googleapis.com/css2?family=Orbitron:wght@400;700&display=swap"
),
```

### Step 3: Add to rotateTypewriter.R

``` r
"orbitron" = list(
  family = "'Orbitron', sans-serif",
  link = "https://fonts.googleapis.com/css2?family=Orbitron:wght@400;700&display=swap"
),
```

### Step 4: Update Documentation

Both files’ `@param font` line:

``` r

#' @param font Font name: "vt323", "ibm", "courier", "space", "anonymous", "press", "silkscreen", "atari", "c64", "dotgothic", "overpass", "nova", "syne", "orbitron", "electrolize", "printchar21", "prnumber3", "data70" (default "vt323")
```

### Step 5: Rebuild

``` bash
R CMD build .
R CMD INSTALL NGR_*.tar.gz
```

### Step 6: Test

``` r

library(NGR)
showTypewriter(text = "HAL 9000 ONLINE", font = "orbitron", color = "#ff0000")
```

## Checklist for Adding a Font

Identify font name and Google Fonts URL

Add font configuration to `R/typewriter.R` switch statement

Add identical font configuration to `R/rotateTypewriter.R` switch
statement

Update `@param font` documentation in `R/typewriter.R`

Update `@param font` documentation in `R/rotateTypewriter.R`

Rebuild package: `R CMD build .`

Install package: `R CMD INSTALL NGR_*.tar.gz`

Restart R session

Test with `showTypewriter(text = "test", font = "newfont")`

Test with special characters in text

Verify in rendered HTML/Quarto output

## Reference: Current Available Fonts

### Google Fonts (Web)

- `vt323` - VT323 (default terminal)
- `ibm` - IBM Plex Mono
- `courier` - Courier Prime
- `space` - Space Mono
- `anonymous` - Anonymous Pro
- `press` - Press Start 2P
- `silkscreen` - Silkscreen
- `atari` - Share Tech Mono
- `c64` - Pixelify Sans
- `dotgothic` - DotGothic16
- `overpass` - Overpass Mono
- `nova` - Nova Mono
- `syne` - Syne Mono
- `orbitron` - Orbitron (sci-fi, HAL 9000)
- `electrolize` - Electrolize (sci-fi, clean)

### Local Fonts (System)

- `printchar21` - Print Char 21
- `prnumber3` - PR Number 3
- `data70` - Data70
