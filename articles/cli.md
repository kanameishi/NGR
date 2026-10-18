# NGR command-line interface

**Development interface.** The repository contains `cli/main.R` and
`install/`. Installing the R package alone does not install the CLI. The
complete scaffold builder migration remains in progress.

NGR combines project resources, Quarto rendering and Netlify
publication. The CLI is implemented in `cli/`; the installed R package
is a separate dependency. Development builds are verified in isolated
installations. Complete project acceptance remains separate from command
and installer tests.

## Install

Run installation commands from the **repository root**, where `install/`
and `lib/` are siblings. The public installer installs the complete R
package and CLI product. Install R and Quarto first; the installer does
not install R or operating-system tools. Python is an optional installer
prerequisite, though operations such as DOCX correction require it.
Receipt handling requires `jsonlite` already visible to R.

### macOS and Linux

Use the default `/usr/local` prefix, or choose a writable prefix without
sudo:

``` sh
sudo bash install/install.sh
bash install/install.sh --library "/absolute/path/to/R/library" --prefix "/absolute/writable/prefix"
```

These are alternatives; replace example paths with your actual
destinations. Under sudo, prefix writes are elevated but every R process
runs as the validated invoking user. The R library defaults to that
user’s current `R_LIBS_USER`; `--library` overrides it. Keep a custom
library visible through `R_LIBS` or `R_LIBS_USER` in later sessions. Add
the prefix’s `bin` directory to PATH; the Unix installer does not edit
shell profiles.

Validate prerequisites and destinations without installing:

``` sh
bash install/install.sh --check --prefix "/absolute/writable/prefix"
```

The default builds `lib/` without manuals or vignettes and installs it
even if an equal or newer version is already present. Use
`--tarball FILE` to select an existing archive with its adjacent `.rds`
build record; repeat `--dependency FILE` for private dependency archives
in installation order. Compatible visible dependencies are reused;
missing or incompatible requirements are installed into the selected
library. There are no public component-selection or build directory
options. Package maintenance and documentation building use the separate
`build.R` workflow.

### Windows

Run from a normal PowerShell session:

``` powershell
powershell -ExecutionPolicy Bypass -File install\install.ps1
```

The default prefix is `%LOCALAPPDATA%\Programs\NGR`, which requires no
elevation. `-Prefix` and `-Library` select other destinations.
Installation adds the prefix’s `bin` directory to the user PATH unless
`-NoPath` is supplied. Other public options are `-Check`, `-Yes`,
`-Tarball` and `-Dependency`. R must be registered by its installer so
the current R-core registry entry can be resolved. Launchers use the
current R and its normal library search; they do not pin a
version-specific interpreter or library.

### Updates and verification

Repeat the installation command to update the product. Replacing a
package or CLI asks once before building or installing; `--yes` on Unix
or `-Yes` on Windows skips that question. Modified or foreign runtime
files block replacement. Failed CLI publication restores the previous
CLI; an already installed R package remains installed.

After installation, verify the selected environment:

``` sh
ngr --version
ngr --help
```

These local checks do not render reports or certify scientific inputs.
The repository’s `install/USAGE.md` describes the complete installation
contract.

## Select your project directory

Run from the project directory or select it with `--root DIR`. `DIR`
must exist; a relative value is resolved from the caller’s working
directory. Relative source manifests, masters, outputs and the
`.netlify/sites.env` registry use the selected project. Operations
retain their existing path rules: supported absolute paths keep their
destinations, and Quarto masters remain project-relative. Omitting
`--root` preserves the working-directory behavior. The option may appear
before or after the command, also as `--root=DIR`, once and before any
`--` argument separator.

``` sh
ngr --root /path/to/project status --check
ngr render --root /path/to/project --manifest manifest.json --dry-run
```

The source manifest and master in this example must already exist. They
are project choices, not files supplied by the installation. Review the
source’s declared checks before running `doctor`.

``` sh
ngr pull --from ngr --from /path/to/book/manifest.json
ngr status --check
ngr doctor
ngr render --manifest manifest.json --dry-run
ngr render _master/book.en.qmd --profile book
```

These are separate operation examples. Rendering the book also requires
all chapters, data and software referenced by its master. A successful
manifest dry run does not execute the book or prove those scientific
inputs are present.

`pull` incorporates and updates declared resources. Registered sources
remain in `manifest.json`; subsequent pulls reuse them. Select
destination paths positionally and registered sources with `--source`.
Use `--force` to replace differing managed files. Existing project seeds
stay local, including the masters a scaffold declares as seeds;
conflicting source contributions always fail before copying. Naming a
registered source again with `--from` re-points it to that location.

Each scaffold also has its own `manifest.json`, declaring its resources.
The project manifest records the composition and provenance instead. NGR
does not read `qrt.manifest.json`; the [scaffold
guide](https://kanameishi.github.io/NGR/articles/scaffolds.md) gives the
three steps that move a project created with the earlier tools.

Resource operations are provided by the installed R library through
[`pullResources()`](https://kanameishi.github.io/NGR/reference/pullResources.md),
[`compareResources()`](https://kanameishi.github.io/NGR/reference/compareResources.md)
and
[`checkResources()`](https://kanameishi.github.io/NGR/reference/checkResources.md).
They can also be used directly from R. Resource commands do not require
Python; the current CLI installer and DOCX correction still use it.
Windows render staging also uses Python’s standard library when a
project contains symbolic links. Scaffold checks can require additional
software declared by their source.

`render` supports HTML books, HTML documents, RevealJS presentations,
simple and composed DOCX, and preserves existing static artifacts. It
loads the installed NGR R package and calls
[`quartoRender()`](https://kanameishi.github.io/NGR/reference/quartoRender.md),
independently of a source checkout. That API owns staging, Quarto
execution, DOCX repair and output delivery; its Python repair resource
is included in the R package.
[`quartoRenderManifest()`](https://kanameishi.github.io/NGR/reference/quartoRenderManifest.md)
owns batch selection, preflight and execution. Static and legacy map
entries refer to external products; NGR does not run their producer
scripts.

`deploy` uploads existing outputs. `deploy init` associates Netlify
sites; `deploy domain` manages domains and HTTPS; `deploy unbind`
removes a local alias. Production requires `--prod`. Use
`ngr deploy --help` for direct and manifest forms. Resource
incorporation never publishes a site.

## Library operations

The Bash, CMD and PowerShell launchers enter `cli/main.R`, which
interprets the arguments and calls only exported functions of the
installed NGR package. `ngr --help` and `ngr --version` work without the
library; any other command names a missing library or one older than the
version the CLI requires. Runtime commands do not install dependencies
or load R code from the source checkout.

R consumers can call these operations without the CLI:

| Operation | R interface |
|----|----|
| Incorporate or update resources | [`pullResources()`](https://kanameishi.github.io/NGR/reference/pullResources.md) |
| Compare resources | [`compareResources()`](https://kanameishi.github.io/NGR/reference/compareResources.md) |
| Diagnose source requirements | [`checkResources()`](https://kanameishi.github.io/NGR/reference/checkResources.md) |
| Render one source or a manifest selection | [`quartoRender()`](https://kanameishi.github.io/NGR/reference/quartoRender.md), [`quartoRenderManifest()`](https://kanameishi.github.io/NGR/reference/quartoRenderManifest.md) |
| Inspect render provenance | [`quartoRenderStamp()`](https://kanameishi.github.io/NGR/reference/quartoRenderStamp.md) |
| Associate, publish or configure Netlify sites | [`netlifyRegister()`](https://kanameishi.github.io/NGR/reference/netlifyRegister.md), [`netlifyDeploy()`](https://kanameishi.github.io/NGR/reference/netlifyDeploy.md), [`netlifyDomain()`](https://kanameishi.github.io/NGR/reference/netlifyDomain.md), [`netlifyUnbind()`](https://kanameishi.github.io/NGR/reference/netlifyUnbind.md) |
| The same for a manifest selection | [`netlifyRegisterManifest()`](https://kanameishi.github.io/NGR/reference/netlifyRegisterManifest.md), [`netlifyDeployManifest()`](https://kanameishi.github.io/NGR/reference/netlifyRegisterManifest.md), [`netlifyDomainManifest()`](https://kanameishi.github.io/NGR/reference/netlifyRegisterManifest.md) |

Scaffolds use
[`buildPlot()`](https://kanameishi.github.io/NGR/reference/buildPlot.md)
for supported graphics. The scaffold or scientific producer owns data
selection and calculation; NGR owns the representation. Existing map
HTML is an input to reports. Rendering never starts a map producer or
OpenQuake.

Run `ngr --help`, `ngr pull --help`, `ngr render --help` or
`ngr deploy --help` for command arguments. Local verification does not
certify a remote deployment.
