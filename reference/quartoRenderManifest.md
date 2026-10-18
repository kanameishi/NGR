# Render a selection of project artifacts

Validates the complete manifest's output claims before rendering
selected Quarto masters in manifest order. External products (`static`
and legacy `map` entries) are checked as existing outputs; their
producers never run.

## Usage

``` r
quartoRenderManifest(
  manifest,
  root = getwd(),
  only = character(),
  except = character(),
  dryRun = FALSE
)
```

## Arguments

- manifest:

  Path to a schema 1 or 2 artifact manifest, relative to `root` or
  absolute.

- root:

  Project directory. Defaults to the current working directory.

- only:

  Character vector of aliases to include; empty selects all.

- except:

  Character vector of aliases to exclude.

- dryRun:

  Validate selection, output claims and Quarto source paths without
  rendering or requiring existing output files.

## Value

Invisibly, the selected artifact records in manifest order.

## Details

Outputs are checked after the batch: required missing outputs fail,
optional missing outputs are reported. Execution stops on the first
render failure, retaining earlier successful outputs. This is not a
transaction.

## See also

[`quartoRender()`](https://kanameishi.github.io/NGR/reference/quartoRender.md)
