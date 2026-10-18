# Dynamic QMD blocks

[`knitBlock()`](https://kanameishi.github.io/NGR/reference/knitBlock.md)
composes reusable QMD fragments at render time. It reads a QMD block,
expands Quarto include shortcodes, rewrites labels with a
caller-supplied stem, evaluates the block with caller-supplied
variables, and emits markdown through
[`knitr::knit_child()`](https://rdrr.io/pkg/knitr/man/knit_child.html).

The helper belongs to NGR because QMD chunks call it inside the R/knitr
runtime. The `qrt` CLI still owns render execution; it should not
silently inject this R helper into documents.

## Mother Blocks And Child Views

Use the default `labels = "parent"` for reportable mother blocks. In
this mode, labels in the requested block are rewritten with `stem`,
while labels and captions in recursively included child blocks are
stripped. This keeps one figure or table number for the reportable
object and avoids numbering every internal tab or view.

Use `labels = "strip"` when the whole block is an internal view that
should not create figure or table numbers. Use `labels = "rewrite"` only
when every label in the expanded include tree is intended to remain
numbered.

## Minimal Example

``` r

library(NGR)
#> Registered S3 method overwritten by 'quantmod':
#>   method            from
#>   as.zoo.data.frame zoo
```

``` r


Root <- file.path(tempdir(), "ngr-knit-block-vignette")
unlink(Root, recursive = TRUE, force = TRUE)
dir.create(file.path(Root, "_tbl"), recursive = TRUE)

writeLines(c(
  "```{r}",
  "#| label: tbl-site-view",
  "#| tbl-cap: \"Internal site/model view\"",
  "knitr::kable(data.frame(site = siteID_TARGET, model = ID_TARGET))",
  "```"
), file.path(Root, "_tbl", "site.qmd"))

writeLines(c(
  "{{< include /_tbl/site.qmd >}}",
  "",
  "```{r}",
  "#| label: tbl-hazard-summary",
  "#| tbl-cap: !expr CAP",
  "knitr::kable(data.frame(site = siteID_TARGET, model = ID_TARGET, value = VALUE))",
  "```"
), file.path(Root, "_tbl", "hazard.qmd"))
```

The same mother block can now be called repeatedly with different stems
and different render context:

``` r

knitBlock(
  path = "/_tbl/hazard.qmd",
  stem = "site-a-model-1",
  vars = list(
    siteID_TARGET = "SITE_A",
    ID_TARGET = "MODEL_1",
    VALUE = 0.42,
    CAP = "Hazard summary for SITE_A / MODEL_1."
  ),
  root = Root
)
knitr::kable(data.frame(site = siteID_TARGET, model = ID_TARGET))
```

| site   | model   |
|:-------|:--------|
| SITE_A | MODEL_1 |

``` r

knitr::kable(data.frame(site = siteID_TARGET, model = ID_TARGET, value = VALUE))
```

| site   | model   | value |
|:-------|:--------|------:|
| SITE_A | MODEL_1 |  0.42 |

``` r


knitBlock(
  path = "/_tbl/hazard.qmd",
  stem = "site-b-model-2",
  vars = list(
    siteID_TARGET = "SITE_B",
    ID_TARGET = "MODEL_2",
    VALUE = 0.67,
    CAP = "Hazard summary for SITE_B / MODEL_2."
  ),
  root = Root
)
knitr::kable(data.frame(site = siteID_TARGET, model = ID_TARGET))
```

| site   | model   |
|:-------|:--------|
| SITE_B | MODEL_2 |

``` r

knitr::kable(data.frame(site = siteID_TARGET, model = ID_TARGET, value = VALUE))
```

| site   | model   | value |
|:-------|:--------|------:|
| SITE_B | MODEL_2 |  0.67 |

## Contract

`stem` must be unique for every numbered call in one render. If the same
dynamic label is emitted twice,
[`knitBlock()`](https://kanameishi.github.io/NGR/reference/knitBlock.md)
fails explicitly instead of allowing an ambiguous Quarto
cross-reference.

`vars` is a named list. It is the place to pass selectors and captions
that the QMD fragment already understands, such as `ID_TARGET`,
`siteID_TARGET`, `TR_TARGET`, `CAP`, or project-specific equivalents.
[`knitBlock()`](https://kanameishi.github.io/NGR/reference/knitBlock.md)
does not know about PSHA, sites, models, or captions.

## Direct Helper Or Project Scaffold

Use
[`knitBlock()`](https://kanameishi.github.io/NGR/reference/knitBlock.md)
directly in a QMD `results: asis` chunk when a report or presentation
needs to repeat a shared block for several sites, models, or
language-specific captions.

Project scaffolds can provide higher-level loops, but they should still
leave scientific calculations and data production to their producer
libraries. NGR only owns QMD include expansion, label
rewrite/strip/check behavior, and
[`knitr::knit_child()`](https://rdrr.io/pkg/knitr/man/knit_child.html)
execution.
