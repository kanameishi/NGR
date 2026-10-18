# Temas con líneas de grilla para escalas logarítmicas

## Resumen

Los temas “enlatados” de highcharter como
[`hc_theme_hcrt()`](https://jkunst.com/highcharter/reference/hc_theme_hcrt.html)
y
[`hc_theme_flat()`](https://jkunst.com/highcharter/reference/hc_theme_flat.html)
son visualmente profesionales pero **no muestran las líneas de grilla
secundarias (minor gridlines)** en escalas logarítmicas.

He creado dos nuevas funciones de tema que extienden los temas
profesionales con líneas de grilla secundarias visibles:

- [`hc_theme_hcrt_gridlines()`](https://kanameishi.github.io/NGR/reference/hc_theme_hcrt_gridlines.md) -
  Basado en
  [`hc_theme_hcrt()`](https://jkunst.com/highcharter/reference/hc_theme_hcrt.html)
- [`hc_theme_flat_gridlines()`](https://kanameishi.github.io/NGR/reference/hc_theme_flat_gridlines.md) -
  Basado en
  [`hc_theme_flat()`](https://jkunst.com/highcharter/reference/hc_theme_flat.html)

## ¿Por qué son útiles las líneas secundarias?

En escalas logarítmicas, las líneas de grilla secundarias ayudan a: 1.
Leer valores intermedios entre las potencias de 10 2. Visualizar mejor
la distribución de datos 3. Hacer interpolaciones visuales más precisas

Por ejemplo, entre 10 y 100, las líneas secundarias marcan 20, 30, 40,
50, 60, 70, 80, 90.

## Uso Básico

``` r

library(NGR)
library(data.table)

# Datos de ejemplo
data_lines <- data.table(
  ID = "Sample",
  X = 10^seq(0, 3, length.out = 50),
  Y = 10^seq(0, 3, length.out = 50) * rnorm(50, 1, 0.1)
)

# SIN líneas secundarias (tema estándar)
plot1 <- buildPlot(
  data.lines = data_lines,
  xAxis.log = TRUE,
  yAxis.log = TRUE,
  plot.theme = hc_theme_hcrt()  # Tema original
)

# CON líneas secundarias (tema mejorado)
plot2 <- buildPlot(
  data.lines = data_lines,
  xAxis.log = TRUE,
  yAxis.log = TRUE,
  plot.theme = hc_theme_hcrt_gridlines()  # Nuevo tema
)
```

## Configuración de los Temas

### `hc_theme_hcrt_gridlines()`

Este tema mantiene toda la estética profesional de
[`hc_theme_hcrt()`](https://jkunst.com/highcharter/reference/hc_theme_hcrt.html)
y agrega:

- **minorGridLineWidth**: 0.5 (líneas secundarias visibles pero sutiles)
- **minorGridLineColor**: `#E8E8E8` (más claro que las líneas
  principales `#F3F3F3`)
- **minorTickInterval**: `"auto"` (calcula automáticamente los
  intervalos en escala log)

### `hc_theme_flat_gridlines()`

Este tema mantiene la estética de
[`hc_theme_flat()`](https://jkunst.com/highcharter/reference/hc_theme_flat.html)
y agrega:

- **minorGridLineWidth**: 0.5
- **minorGridLineDashStyle**: `"Dot"` (líneas punteadas para distinguir
  de las principales)
- **minorGridLineColor**: `#D5D8DC` (más claro que las líneas
  principales `#BDC3C7`)
- **minorTickInterval**: `"auto"`

## Propiedades Técnicas

Las líneas de grilla en Highcharts se controlan a nivel de configuración
de ejes (`xAxis` y `yAxis`). Las propiedades clave son:

| Propiedad            | Descripción                 | Valor Recomendado       |
|----------------------|-----------------------------|-------------------------|
| `gridLineWidth`      | Ancho de líneas principales | 1 (predeterminado)      |
| `gridLineColor`      | Color de líneas principales | `#F3F3F3` (gris claro)  |
| `minorGridLineWidth` | Ancho de líneas secundarias | 0.5                     |
| `minorGridLineColor` | Color de líneas secundarias | `#E8E8E8` (más claro)   |
| `minorTickInterval`  | Intervalo de marcas menores | `"auto"` para log scale |

## Personalización Avanzada

Si quieres crear tu propio tema personalizado:

``` r

# Toma cualquier tema base
mi_tema <- highcharter::hc_theme_hcrt()

# Añade configuración de gridlines
mi_tema$xAxis$minorGridLineWidth <- 0.5
mi_tema$xAxis$minorGridLineColor <- "#E8E8E8"
mi_tema$xAxis$minorTickInterval <- "auto"

mi_tema$yAxis$minorGridLineWidth <- 0.5
mi_tema$yAxis$minorGridLineColor <- "#E8E8E8"
mi_tema$yAxis$minorTickInterval <- "auto"

# Opcional: cambiar estilo de líneas (Solid, Dash, Dot, etc.)
# mi_tema$xAxis$minorGridLineDashStyle <- "Dot"

# Usa tu tema
buildPlot(data.lines = my_data, plot.theme = mi_tema)
```

## Ejemplo Completo

Los ejemplos de esta vignette son intencionalmente mínimos. Para
ejemplos ejecutables, use la documentación de las funciones
`hc_theme_*_gridlines()` y
[`buildPlot()`](https://kanameishi.github.io/NGR/reference/buildPlot.md).

## Referencias

- [Highcharts API - xAxis](https://api.highcharts.com/highcharts/xAxis)
- [Highcharts API - yAxis](https://api.highcharts.com/highcharts/yAxis)
- Propiedades específicas: `minorGridLineWidth`, `minorGridLineColor`,
  `minorTickInterval`
