# Build a heatmap plot (Highcharts)

Build a Highcharts heatmap from a data.table with columns X, Y, Z.

X and Y are treated as categorical axes: unique values are sorted and
used as category labels. Z is the numeric value mapped to the color
axis. The function converts the raw X/Y values to 0-based integer
indices internally, and stores the original labels in each point as
`xLabel` and `yLabel`.

Color axis defaults to the Inferno palette (10 stops). Supply
`color.stops` to override. `colorAxis.max` defaults to `ceiling(max(Z))`
when NULL.

## Usage

``` r
buildHeatmap(
  .data,
  xAxis.legend = "X",
  yAxis.legend = "Y",
  plot.title = NULL,
  colorAxis.min = 0,
  colorAxis.max = NULL,
  color.stops = NULL,
  series.name = "Value",
  border.width = 1,
  border.color = "#333333",
  dataLabels.show = FALSE,
  tooltip.format = NULL,
  legend.align = "right",
  legend.layout = "vertical",
  legend.valign = "middle",
  plot.theme = NULL
)
```

## Arguments

- .data:

  A data.table with columns X, Y (raw category values) and Z (numeric).

- xAxis.legend:

  Character; x-axis title. Default `"X"`.

- yAxis.legend:

  Character; y-axis title. Default `"Y"`.

- plot.title:

  Character or NULL; chart title. Default NULL (no title).

- colorAxis.min:

  Numeric; lower bound of the color axis. Default `0`.

- colorAxis.max:

  Numeric or NULL; upper bound of the color axis. NULL (default) uses
  `ceiling(max(.data$Z))`.

- color.stops:

  List of Highcharts color-axis stops, each a `list(position, color)`.
  NULL (default) uses a 10-stop Inferno palette.

- series.name:

  Character; legend label for the series. Default `"Value"`.

- border.width:

  Numeric; cell border width in pixels. Default `1`.

- border.color:

  Character; cell border color. Default `"#333333"`.

- dataLabels.show:

  Logical; show value labels inside cells. Default `FALSE`.

- tooltip.format:

  Character; Highcharts `pointFormat` string. NULL (default) generates a
  format using `xAxis.legend`, `yAxis.legend`, `series.name`,
  `{point.xLabel}`, and `{point.yLabel}`. For custom tooltips, use
  `{point.xLabel}` and `{point.yLabel}` for the original `.data$X` and
  `.data$Y` values; `{point.x}` and `{point.y}` are internal 0-based
  indices.

- legend.align:

  Character; horizontal legend alignment. Default `"right"`.

- legend.layout:

  Character; legend layout direction. Default `"vertical"`.

- legend.valign:

  Character; vertical legend alignment. Default `"middle"`.

- plot.theme:

  Optional Highcharts theme object (e.g.
  [`hc_theme_538_gridlines()`](https://kanameishi.github.io/NGR/reference/hc_theme_538_gridlines.md)).
  Default NULL applies no theme.

## Value

A highchart object.
