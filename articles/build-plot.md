# buildPlot line and point layers

[`buildPlot()`](https://kanameishi.github.io/NGR/reference/buildPlot.md)
composes highcharter plots from table-like inputs. The common pattern is
one `data.table` for line series and, when needed, a second `data.table`
for point series. Both tables use `ID` to define the series and `X`/`Y`
for coordinates.

## Line And Point Inputs

Line data can include optional style columns such as `style` and `fill`.
Point data can include marker style columns.

``` r

library(NGR)
library(data.table)

DataLines <- data.table(
  ID = rep(c("A", "B", "C"), each = 5),
  X = as.numeric(rep(1:5, 3)),
  Y = as.numeric(c(seq(1, 5), seq(2, 6), seq(3, 7))),
  style = c(rep("solid", 5), rep("dotted", 5), rep("dashed", 5)),
  fill = c(rep(TRUE, 5), rep(TRUE, 5), rep(FALSE, 5))
)

DataPoints <- data.table(
  ID = rep(c("A", "B", "C"), each = 4),
  X = as.numeric(rep(1:4, 3)),
  Y = as.numeric(c(seq(8, 11), seq(6, 9), seq(4, 7))),
  style = c(rep("circle", 4), rep("diamond", 4), rep("triangle-down", 4))
)
```

## Combined Plot

Pass line and point layers together. `line.type = "spline"` uses curved
line segments while preserving the point layer.

``` r

PLOT <- buildPlot(
  data.lines = DataLines,
  data.points = DataPoints,
  line.type = "spline",
  plot.title = "Combined Lines and Points Example",
  plot.subtitle = "Demonstration of fills, line styles, and point styles",
  plot.height = 500,
  plot.width = 700,
  xAxis.legend = "Time (units)",
  yAxis.legend = "Value",
  print.max.abs = FALSE
)

PLOT
```

## Required Columns

For line series:

| Column | Role              |
|--------|-------------------|
| `ID`   | series identifier |
| `X`    | x coordinate      |
| `Y`    | y coordinate      |

For point series, the same `ID`, `X`, and `Y` columns are required.
Optional columns such as `style`, `size`, `fill`, or `yAxis` are
consumed when present by the plotting helper.

## Related Articles

Use the secondary-axis article when the plot needs a linked or
independent right-hand axis. Use the gridline-theme article when
plotting on log axes.
