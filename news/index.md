# Changelog

## NGR 0.4.0

### Project resources, rendering and publication

- New project resource operations:
  [`pullResources()`](https://kanameishi.github.io/NGR/reference/pullResources.md),
  [`compareResources()`](https://kanameishi.github.io/NGR/reference/compareResources.md)
  and
  [`checkResources()`](https://kanameishi.github.io/NGR/reference/checkResources.md)
  incorporate, compare and check resources declared by source manifests.
  A source is identified by its `id`, so naming a registered source
  again re-points it to another location. A file entry may override the
  ownership given by its directory entry, artifact seeds may name the
  project through `{project_id}`, and a source outside Git reports the
  revision recorded in a `BUILD_INFO` file beside its manifest.
- New rendering operations:
  [`quartoRender()`](https://kanameishi.github.io/NGR/reference/quartoRender.md),
  [`quartoRenderManifest()`](https://kanameishi.github.io/NGR/reference/quartoRenderManifest.md)
  and
  [`quartoRenderStamp()`](https://kanameishi.github.io/NGR/reference/quartoRenderStamp.md).
  The publication stamp reaches filters and scaffolds through the
  `NGR_RENDER_STAMP` environment variable.
- New Netlify operations:
  [`netlifyRegister()`](https://kanameishi.github.io/NGR/reference/netlifyRegister.md),
  [`netlifyDeploy()`](https://kanameishi.github.io/NGR/reference/netlifyDeploy.md),
  [`netlifyDomain()`](https://kanameishi.github.io/NGR/reference/netlifyDomain.md)
  and
  [`netlifyUnbind()`](https://kanameishi.github.io/NGR/reference/netlifyUnbind.md),
  with the manifest forms
  [`netlifyRegisterManifest()`](https://kanameishi.github.io/NGR/reference/netlifyRegisterManifest.md),
  [`netlifyDeployManifest()`](https://kanameishi.github.io/NGR/reference/netlifyRegisterManifest.md)
  and
  [`netlifyDomainManifest()`](https://kanameishi.github.io/NGR/reference/netlifyRegisterManifest.md).
- The `ngr` command-line interface interprets its arguments in
  `cli/main.R` and calls only exported functions; it requires NGR \>=
  0.4.0.

Existing plotting, table, Quarto YAML and display functions are
unchanged.

## NGR 0.3.11

### API

- [`buildPlot()`](https://kanameishi.github.io/NGR/reference/buildPlot.md)
  gains `xAxis.bands` and `yAxis.bands` for shaded axis regions
  (Highcharts `plotBands`) drawn behind the series. The semantic form
  `list(cuts = , colors = )` splits an axis into `length(cuts) + 1`
  open-ended regions, so a cut outside the plotted range is clipped by
  Highcharts instead of producing an inverted band; a prebuilt list of
  `list(from = , to = , color = )` entries passes through unchanged.
  Both default to `NULL`, which leaves every existing configuration
  untouched.

## NGR 0.3.10

### API

- Add
  [`buildSectionResultantsPlot()`](https://kanameishi.github.io/NGR/reference/buildSectionResultantsPlot.md)
  for responsive, interactive `N`/`M`/`Q` diagrams around a circular
  section. The function renders any non-empty caller-prepared subset as
  one or more square panels, preserves independent radial ordinates, and
  keeps the widget width responsive.

## NGR 0.3.9

### API

- [`buildPlot()`](https://kanameishi.github.io/NGR/reference/buildPlot.md)
  gains an explicit `data.ranges` input for keyed lower/upper curves.
  Coincident bounds render as one solid line; distinct bounds render as
  linked solid boundary lines with one legend item and a shaded band.
  Boundary tooltips identify `lower` and `upper`, and optional
  named-list columns preserve point metadata.

## NGR 0.3.8

### Visual

- Restore the lighter minor-gridline styling so auxiliary gridlines
  remain subordinate to thin data series.

## NGR 0.3.7

### API

- [`buildPlot()`](https://kanameishi.github.io/NGR/reference/buildPlot.md):
  remove the `xAxis.log.offset` / `yAxis.log.offset` transformation
  layer and replace it with `xAxis.log.zero` for log-log plots. When
  `xAxis.log.zero = TRUE`, points with `X == 0` are assigned an internal
  positive display coordinate derived from the first two positive X
  values (`x1^2 / x2`), while the original X value is preserved for
  tooltips and caller data are not mutated. Negative X values on
  logarithmic axes remain unsupported.

### Visual

- [`buildPlot()`](https://kanameishi.github.io/NGR/reference/buildPlot.md):
  hide technical auto-envelope IDs (`fill.min` / `fill.max`, default
  `.min` / `.max`) from the legend and tooltip when
  `fill.minmax = TRUE`, and exclude those technical boundary series from
  data export. The default shaded-area legend is now the generic
  `"Shaded range"` instead of exposing the boundary IDs.

- `hc_theme_*_gridlines()`: bump minor gridline visibility from
  `#EEEEEE` / `#E0E0E0` @ width 0.25 to `#D8D8D8` / `#C8C8C8` @ width
  0.5. The previous very-faint settings were essentially invisible
  against white backgrounds, defeating the purpose of the `_gridlines`
  variants (which exist specifically to provide auxiliary subdivisions
  between major ticks on logarithmic axes). New settings remain clearly
  subordinate to major gridlines but are now readable.

## NGR 0.3.6

### Bug fixes

- [`buildPlot()`](https://kanameishi.github.io/NGR/reference/buildPlot.md):
  revert the `tickPositioner` injection added in 0.3.4. Highcharts
  treats `tickPositioner` positions as linear coordinates on a
  logarithmic axis, which collapsed our custom positions to the right
  edge of the plot and suppressed minor gridlines. Tick *placement* is
  now left entirely to Highcharts’ native log autoplacing; the offset
  compensation is done by the label formatter alone. Two snap rules in
  the formatter:
  - `|val| < 1.5 * offset` -\> label `"0"` (the un-shifted position of
    the original `X=0` cluster).
  - `val` within 10% (relative) of a power of ten -\> snap to that power
    (catches the typical `0.0092 -> 0.01` case where the offset shift
    introduces an ~8% error in the un-shifted value). No more ugly tail
    digits, minor gridlines restored.

## NGR 0.3.5

### Bug fixes

- [`buildPlot()`](https://kanameishi.github.io/NGR/reference/buildPlot.md):
  change default `plot.theme` from
  [`hc_theme_flat()`](https://jkunst.com/highcharter/reference/hc_theme_flat.html)
  to
  [`hc_theme_flat_gridlines()`](https://kanameishi.github.io/NGR/reference/hc_theme_flat_gridlines.md).
  The previous default silently broke the log-axis `tickPositioner`
  callback (see 0.3.4) because it omitted `minorTickInterval = "auto"` —
  without that, Highcharts skips the custom tick positions entirely and
  renders no major ticks on a logarithmic axis with offset shift. The
  `_gridlines` variant is a strict superset (everything from
  [`hc_theme_flat()`](https://jkunst.com/highcharter/reference/hc_theme_flat.html)
  plus minor gridlines + minorTickInterval) and lets the tickPositioner
  take effect. Callers that explicitly pass `plot.theme = ...` are
  unaffected.

## NGR 0.3.4

### Bug fixes

- [`buildPlot()`](https://kanameishi.github.io/NGR/reference/buildPlot.md):
  fix major-tick labels on logarithmic axes when the data contains
  non-positive values (e.g. `Tn = 0` for PGA in response spectra). The
  existing `xAxis.log.offset` / `yAxis.log.offset` mechanism shifts the
  data so non-positive points become plottable on a
  `type = "logarithmic"` axis, and a JS label formatter subtracts the
  offset to render labels in original space. Previously Highcharts
  auto-placed ticks at clean powers of ten in the *shifted* axis space,
  so the label formatter turned them into ugly values
  (`0.009 / 0.099 / 0.999 / 9.999`). This release adds a
  `tickPositioner` JS callback (auto-injected when `x_offset > 0` or
  `y_offset > 0`) that picks tick positions at `10^n + offset` in the
  shifted axis, so the formatter renders clean decades
  (`0.01 / 0.1 / 1 / 10`) plus a `"0"` tick at the offset position
  itself. The positioner derives the exponent range from the actual axis
  `dataMin` / `dataMax` at render time — no R-side hardcoded tick
  positions, adapts to any data range. No change for users who pass
  `*.log.offset = FALSE` or for data without non-positive values.
