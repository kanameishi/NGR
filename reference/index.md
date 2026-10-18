# Package index

## Plotting

- [`buildPlot()`](https://kanameishi.github.io/NGR/reference/buildPlot.md)
  : Build a highchart plot
- [`buildPlot.Bar()`](https://kanameishi.github.io/NGR/reference/buildPlot.Bar.md)
  : Build a bar/column plot (Highcharts)
- [`buildPlot.Histogram()`](https://kanameishi.github.io/NGR/reference/buildPlot.Histogram.md)
  : Build a histogram (and/or density) plot
- [`buildPlot.Model()`](https://kanameishi.github.io/NGR/reference/buildPlot.Model.md)
  : Build a model plot
- [`buildPlot.Profile()`](https://kanameishi.github.io/NGR/reference/buildPlot.Profile.md)
  : Build a depth-profile plot
- [`buildPlot.Time()`](https://kanameishi.github.io/NGR/reference/buildPlot.Time.md)
  : Build a time-series plot
- [`buildHeatmap()`](https://kanameishi.github.io/NGR/reference/buildHeatmap.md)
  : Build a heatmap plot (Highcharts)
- [`buildSectionResultantsPlot()`](https://kanameishi.github.io/NGR/reference/buildSectionResultantsPlot.md)
  : Build circular-section resultant diagrams

## Tables and report composition

- [`buildTable()`](https://kanameishi.github.io/NGR/reference/buildTable.md)
  : Render a table with specified formatting options
- [`buildYAML()`](https://kanameishi.github.io/NGR/reference/buildYAML.md)
  : Build Quarto YAML and prepare project structure
- [`knitBlock()`](https://kanameishi.github.io/NGR/reference/knitBlock.md)
  : Knit a QMD block with dynamic labels

## Project resources

- [`pullResources()`](https://kanameishi.github.io/NGR/reference/pullResources.md)
  : Incorporate and update project resources
- [`compareResources()`](https://kanameishi.github.io/NGR/reference/compareResources.md)
  : Compare project resources with their sources
- [`checkResources()`](https://kanameishi.github.io/NGR/reference/checkResources.md)
  : Run checks declared by registered resource sources

## Quarto rendering

- [`quartoRender()`](https://kanameishi.github.io/NGR/reference/quartoRender.md)
  : Render a Quarto document in a disposable project copy
- [`quartoRenderManifest()`](https://kanameishi.github.io/NGR/reference/quartoRenderManifest.md)
  : Render a selection of project artifacts
- [`quartoRenderStamp()`](https://kanameishi.github.io/NGR/reference/quartoRenderStamp.md)
  : Resolve the print stamp of a render from scaffold provenance

## Netlify publication

- [`netlifyRegister()`](https://kanameishi.github.io/NGR/reference/netlifyRegister.md)
  : Register local aliases for Netlify sites
- [`netlifyDeploy()`](https://kanameishi.github.io/NGR/reference/netlifyDeploy.md)
  : Upload existing directories to Netlify
- [`netlifyDomain()`](https://kanameishi.github.io/NGR/reference/netlifyDomain.md)
  : Configure domains for registered Netlify sites
- [`netlifyUnbind()`](https://kanameishi.github.io/NGR/reference/netlifyUnbind.md)
  : Remove a local Netlify alias association
- [`netlifyRegisterManifest()`](https://kanameishi.github.io/NGR/reference/netlifyRegisterManifest.md)
  [`netlifyDeployManifest()`](https://kanameishi.github.io/NGR/reference/netlifyRegisterManifest.md)
  [`netlifyDomainManifest()`](https://kanameishi.github.io/NGR/reference/netlifyRegisterManifest.md)
  : Register, publish or configure the Netlify sites of a manifest
  selection

## Quarto YAML helpers

R helpers for qrt-style runtime YAML composition without depending on
the qrt CLI.

- [`quartoReadFrontmatter()`](https://kanameishi.github.io/NGR/reference/quartoYaml.md)
  [`quartoAsSequence()`](https://kanameishi.github.io/NGR/reference/quartoYaml.md)
  [`quartoHasBookManifest()`](https://kanameishi.github.io/NGR/reference/quartoYaml.md)
  [`quartoSetProjectRender()`](https://kanameishi.github.io/NGR/reference/quartoYaml.md)
  [`quartoMergeBookManifest()`](https://kanameishi.github.io/NGR/reference/quartoYaml.md)
  [`quartoDocxBookProfile()`](https://kanameishi.github.io/NGR/reference/quartoYaml.md)
  [`quartoAsYaml()`](https://kanameishi.github.io/NGR/reference/quartoYaml.md)
  [`quartoWriteYaml()`](https://kanameishi.github.io/NGR/reference/quartoYaml.md)
  : Quarto YAML helper functions

## Highcharter themes

- [`hc_theme_hcrt_gridlines()`](https://kanameishi.github.io/NGR/reference/hc_theme_hcrt_gridlines.md)
  : Highcharter theme based on hc_theme_hcrt with enhanced gridlines
- [`hc_theme_flat_gridlines()`](https://kanameishi.github.io/NGR/reference/hc_theme_flat_gridlines.md)
  : Highcharter theme based on hc_theme_flat with enhanced gridlines
- [`hc_theme_538_gridlines()`](https://kanameishi.github.io/NGR/reference/hc_theme_538_gridlines.md)
  : Highcharter theme based on FiveThirtyEight (538) with enhanced
  gridlines
- [`hc_theme_economist_gridlines()`](https://kanameishi.github.io/NGR/reference/hc_theme_economist_gridlines.md)
  : Highcharter theme based on The Economist with enhanced gridlines

## Display utilities

- [`showCode()`](https://kanameishi.github.io/NGR/reference/showCode.md)
  : Display source code with syntax highlighting
- [`showHTML()`](https://kanameishi.github.io/NGR/reference/showHTML.md)
  : Display HTML content in iframe
- [`showPDF()`](https://kanameishi.github.io/NGR/reference/showPDF.md) :
  Display PDF in iframe using PDF.js viewer
- [`showMarkdownRendered()`](https://kanameishi.github.io/NGR/reference/showMarkdownRendered.md)
  : Display markdown file as rendered HTML via iframe
- [`showGithubREADME()`](https://kanameishi.github.io/NGR/reference/showGithubREADME.md)
  : Display GitHub README as iframe
- [`showASCII()`](https://kanameishi.github.io/NGR/reference/showASCII.md)
  : Display text file as plain ASCII (non-formatted)
- [`showTypewriter()`](https://kanameishi.github.io/NGR/reference/showTypewriter.md)
  : Generate typewriter effect HTML from text file or direct text
- [`rotateTypewriter()`](https://kanameishi.github.io/NGR/reference/rotateTypewriter.md)
  : Generate rotating typewriter effect from multiple text files or text
  strings
- [`buildIndexTypewriter()`](https://kanameishi.github.io/NGR/reference/buildIndexTypewriter.md)
  : Build and display typewriter index from chapter list
- [`export()`](https://kanameishi.github.io/NGR/reference/export.md) :
  Export Highcharts widget to PNG
