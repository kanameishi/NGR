# Secondary Y axis in buildPlot()

[`buildPlot()`](https://kanameishi.github.io/NGR/reference/buildPlot.md)
supports two different “secondary axis” modes.

## Mode A — linked (one curve, relabel ticks)

Use this when you want **one curve** but the right axis shows a
transformed label of the **same** tick values.

Example: if the left axis is `AEP [1/yr]` and you want the right axis to
show `TR [yr] = 1 / AEP`:

``` r

PLOT <- buildPlot(
  data.lines = DATA,
  yAxis.legend = "AEP [1/yr]",
  yAxis2.legend = "TR [yr]",
  yAxis2.transform = ~ 1 / Y,
  yAxis2.decimals = 0
)
```

Notes: - In `yAxis2.transform = ~ f(Y)`, the symbol `Y` represents the
**primary axis tick value**. - This mode does **not** add a second
curve. It only changes how the right axis labels are displayed.

### Supported operations in `yAxis2.transform`

The formula is translated to JavaScript internally. Supported
operators/functions:

- Operators: `+`, `-`, `*`, `/`, `^`
- Functions: [`abs()`](https://rdrr.io/r/base/MathFun.html),
  [`sqrt()`](https://rdrr.io/r/base/MathFun.html),
  [`exp()`](https://rdrr.io/r/base/Log.html),
  [`sin()`](https://rdrr.io/r/base/Trig.html),
  [`cos()`](https://rdrr.io/r/base/Trig.html),
  [`tan()`](https://rdrr.io/r/base/Trig.html)
- Rounding: [`floor()`](https://rdrr.io/r/base/Round.html),
  [`ceiling()`](https://rdrr.io/r/base/Round.html), `round(x)`,
  `round(x, digits)`
- Logs: `log(x)`, `log(x, base)`, `log10(x)`, `log2(x)`
- Constants: `pi`

If you need something outside this set, use the advanced
`yAxis2 = list(...)` hook.

## Mode B — independent axes (two variables / two scales)

Use this when you want to plot **two different variables** with
**different scales**.

Assign each series to an axis via a `yAxis` column (0 = left axis, 1 =
right axis):

``` r

DT <- data.table::rbindlist(list(
  data.table::data.table(ID = "Pressure", X = 1:50, Y = pressure, yAxis = 0),
  data.table::data.table(ID = "Temp",     X = 1:50, Y = temp,     yAxis = 1)
))

PLOT <- buildPlot(
  data.lines = DT,
  yAxis.legend = "Pressure",
  yAxis2.legend = "Temp"
)
```

Important: - In this mode, you **must not** use `yAxis2.transform` (it
is only for linked mode).

## Advanced override (`yAxis2 = list(...)`)

For full Highcharts control of the secondary axis, pass
`yAxis2 = list(...)`.

When `yAxis2` is provided, it overrides the convenience arguments
(`yAxis2.legend`, `yAxis2.transform`, `yAxis2.decimals`).
