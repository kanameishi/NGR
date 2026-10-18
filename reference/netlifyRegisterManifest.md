# Register, publish or configure the Netlify sites of a manifest selection

Manifest forms of
[`netlifyRegister()`](https://kanameishi.github.io/NGR/reference/netlifyRegister.md),
[`netlifyDeploy()`](https://kanameishi.github.io/NGR/reference/netlifyDeploy.md)
and
[`netlifyDomain()`](https://kanameishi.github.io/NGR/reference/netlifyDomain.md).
Each reads the artifact manifest, applies the alias selection and
validates the whole selection before its first effect. Registration and
domains take each artifact's `siteSlug` and `domain`; those values must
be unique across the complete manifest, not only the selection, and
every selected artifact must declare the one in use. Publication uploads
each selected artifact's `path`: a missing `index.html` fails a required
artifact and skips an optional one with a message.

## Usage

``` r
netlifyRegisterManifest(
  manifest,
  root = getwd(),
  only = character(),
  except = character(),
  create = FALSE,
  account = NULL,
  dryRun = FALSE
)

netlifyDeployManifest(
  manifest,
  root = getwd(),
  only = character(),
  except = character(),
  prod = FALSE,
  dryRun = FALSE
)

netlifyDomainManifest(
  manifest,
  root = getwd(),
  only = character(),
  except = character(),
  https = FALSE,
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

- create:

  Permit creating missing sites. Defaults to `FALSE`.

- account:

  Optional Netlify account slug.

- dryRun:

  Describe the request without provider calls or registry writes.

- prod:

  Publish to production instead of creating a draft.

- https:

  Enable HTTPS, including certificate provisioning if needed.

## Value

Invisibly, the value of the direct operation for the artifacts it
reached; an empty character vector when every selected upload was
skipped.

## Details

Batches are sequential, not transactions; a later failure retains
earlier effects. Dry runs contact no provider and write no registry.

## See also

[`quartoRenderManifest()`](https://kanameishi.github.io/NGR/reference/quartoRenderManifest.md)
