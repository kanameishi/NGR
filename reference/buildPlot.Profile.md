# Build a depth-profile plot

Builds one Highcharts widget for a quantity measured along a borehole or
any other downward axis: the ordinate is depth, growing downward, and
the abscissa is the measured quantity on a fixed symmetric scale. One
series is drawn per `ID`.

The function renders a single panel. Composing several panels — for
example the two orthogonal axes of an inclinometer side by side —
belongs to the caller, which calls this function once per panel and lays
the widgets out.

Compared with
[`buildPlot()`](https://kanameishi.github.io/NGR/reference/buildPlot.md)
this builder adds explicit per-series colour, per-series marker symbols,
and a legend switch, and it defaults to a fixed symmetric abscissa. It
does not select surveys, order series, or decide the reference: the
caller owns all of that.

## Usage

``` r
buildPlot.Profile(
  data,
  xLegend = "X",
  yLegend = "Y",
  xLimit = NULL,
  yMax = NULL,
  palette = "Batlow",
  lineType = "spline",
  lineSize = 1.6,
  markers = FALSE,
  markerSize = 3,
  showLegend = TRUE,
  legendTitle = "ID",
  plotHeight = 760,
  theme = NULL
)
```

## Arguments

- data:

  A data frame or `data.table` with one row per plotted point. Required
  columns are `ID` (series identity), `X` (measured quantity) and `Y`
  (depth, positive downward). Optional columns, constant within each
  `ID`: `style` (a dash style accepted by
  [`buildPlot()`](https://kanameishi.github.io/NGR/reference/buildPlot.md)),
  `size` (line width), `color` (explicit series colour) and `symbol`
  (marker symbol, one of `circle`, `square`, `diamond`, `triangle`,
  `triangle-down`). Series are drawn in order of first appearance of
  `ID`, which also fixes palette assignment when `color` is absent.

- xLegend:

  Abscissa title.

- yLegend:

  Ordinate title.

- xLimit:

  Positive half-range of the symmetric abscissa: the axis spans
  `-xLimit` to `xLimit`. `NULL` derives it from `data`. A fixed scale is
  the normal choice, because autoscaling a profile of good data renders
  measurement noise at full width.

- yMax:

  Maximum depth of the ordinate. `NULL` derives it from `data`.

- palette:

  Palette name from
  [`grDevices::hcl.pals()`](https://rdrr.io/r/grDevices/palettes.html),
  used for every series without an explicit `color`.

- lineType:

  Series geometry, `"spline"` or `"line"`.

- lineSize:

  Default line width for series without a `size` value.

- markers:

  Draw a marker at every plotted point.

- markerSize:

  Marker radius in pixels.

- showLegend:

  Show the series legend. Keep it enabled on every panel of a composed
  figure: a legend attached to one panel of a pair shortens that panel
  and leaves the other unlabelled.

- legendTitle:

  Legend title.

- plotHeight:

  Widget height in pixels. Width stays responsive.

- theme:

  A Highcharts theme object.

## Value

A `highchart` htmlwidget. Inputs are not modified and no file is
written.

## Examples

``` r
Depth <- seq(0.5, 20, by = 0.5)
Data <- rbind(
  data.frame(ID = "baseline", X = 0, Y = Depth, style = "longdashdotdot",
    size = 1),
  data.frame(ID = "2026-04-01", X = 12 * (1 - Depth / 20)^2, Y = Depth,
    style = "solid", size = 1.6)
)
buildPlot.Profile(
  data = Data,
  xLegend = "Displacement (mm)",
  yLegend = "Depth (m)",
  xLimit = 25
)

{"x":{"hc_opts":{"chart":{"reflow":true,"zoomType":"xy","height":760},"title":{"text":null},"yAxis":{"title":{"text":"Depth (m)"},"reversed":true,"min":0,"max":20},"credits":{"enabled":false},"exporting":{"enabled":false},"boost":{"enabled":false},"plotOptions":{"series":{"label":{"enabled":false},"turboThreshold":0},"treemap":{"layoutAlgorithm":"squarified"}},"xAxis":{"title":{"text":"Displacement (mm)"},"min":-25,"max":25,"startOnTick":false,"endOnTick":false,"plotLines":[{"value":0,"width":0.75,"color":"#9CA3AF"}]},"series":[{"data":[[0,0.5],[0,1],[0,1.5],[0,2],[0,2.5],[0,3],[0,3.5],[0,4],[0,4.5],[0,5],[0,5.5],[0,6],[0,6.5],[0,7],[0,7.5],[0,8],[0,8.5],[0,9],[0,9.5],[0,10],[0,10.5],[0,11],[0,11.5],[0,12],[0,12.5],[0,13],[0,13.5],[0,14],[0,14.5],[0,15],[0,15.5],[0,16],[0,16.5],[0,17],[0,17.5],[0,18],[0,18.5],[0,19],[0,19.5],[0,20]],"type":"spline","name":"baseline","color":"#201158","dashStyle":"LongDashDotDot","lineWidth":1,"showInLegend":true,"marker":{"enabled":false,"radius":3,"symbol":"circle"}},{"data":[[11.4075,0.5],[10.83,1],[10.2675,1.5],[9.720000000000001,2],[9.1875,2.5],[8.669999999999998,3],[8.167499999999999,3.5],[7.680000000000001,4],[7.207500000000001,4.5],[6.75,5],[6.3075,5.5],[5.879999999999999,6],[5.467500000000001,6.5],[5.07,7],[4.6875,7.5],[4.32,8],[3.967499999999999,8.5],[3.630000000000001,9],[3.3075,9.5],[3,10],[2.7075,10.5],[2.43,11],[2.1675,11.5],[1.92,12],[1.6875,12.5],[1.47,13],[1.2675,13.5],[1.08,14],[0.9075000000000002,14.5],[0.75,15],[0.6074999999999999,15.5],[0.4799999999999998,16],[0.3675000000000002,16.5],[0.2700000000000001,17],[0.1875,17.5],[0.1199999999999999,18],[0.06749999999999992,18.5],[0.03000000000000005,19],[0.007500000000000014,19.5],[0,20]],"type":"spline","name":"2026-04-01","color":"#FFCEF4","dashStyle":"Solid","lineWidth":1.6,"showInLegend":true,"marker":{"enabled":false,"radius":3,"symbol":"square"}}],"legend":{"enabled":true,"align":"center","verticalAlign":"bottom","layout":"horizontal","title":{"text":"ID"}},"tooltip":{"crosshairs":true,"headerFormat":"","pointFormat":"<b>{series.name}<\/b><br/>Displacement (mm): {point.x}<br/>Depth (m): {point.y}"}},"theme":{"chart":{"backgroundColor":"transparent"},"colors":["#7cb5ec","#434348","#90ed7d","#f7a35c","#8085e9","#f15c80","#e4d354","#2b908f","#f45b5b","#91e8e1"]},"conf_opts":{"global":{"Date":null,"VMLRadialGradientURL":"http =//code.highcharts.com/list(version)/gfx/vml-radial-gradient.png","canvasToolsURL":"http =//code.highcharts.com/list(version)/modules/canvas-tools.js","getTimezoneOffset":null,"timezoneOffset":0,"useUTC":true},"lang":{"contextButtonTitle":"Chart context menu","decimalPoint":".","downloadCSV":"Download CSV","downloadJPEG":"Download JPEG image","downloadPDF":"Download PDF document","downloadPNG":"Download PNG image","downloadSVG":"Download SVG vector image","downloadXLS":"Download XLS","drillUpText":"◁ Back to {series.name}","exitFullscreen":"Exit from full screen","exportData":{"annotationHeader":"Annotations","categoryDatetimeHeader":"DateTime","categoryHeader":"Category"},"hideData":"Hide data table","invalidDate":null,"loading":"Loading...","months":["January","February","March","April","May","June","July","August","September","October","November","December"],"noData":"No data to display","numericSymbolMagnitude":1000,"numericSymbols":["k","M","G","T","P","E"],"printChart":"Print chart","resetZoom":"Reset zoom","resetZoomTitle":"Reset zoom level 1:1","shortMonths":["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],"shortWeekdays":["Sat","Sun","Mon","Tue","Wed","Thu","Fri"],"thousandsSep":" ","viewData":"View data table","viewFullscreen":"View in full screen","weekdays":["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]}},"type":"chart","fonts":[],"debug":false},"evals":[],"jsHooks":[]}
```
