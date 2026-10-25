# Product installation

Run from the repository root. The public operation installs the complete R
library + CLI product. R must already be installed.

```sh
sudo bash install/install.sh
bash install/install.sh --yes --library "/chosen/R/library" --prefix "/chosen/prefix"
bash install/install.sh --check --prefix "/writable/test/prefix"
```

The Unix prefix defaults to `/usr/local`. Under sudo, Bash owns prefix writes;
every R process runs as the validated invoking user. Without sudo choose a
writable prefix. `--check` validates prerequisites and destinations without
installing. This includes library destinations and the presence of explicitly
selected archives and their records. Artifact hashes are checked before any
package is installed. Receipt handling requires `jsonlite` already visible to R.

The default builds `lib/` without manuals or vignettes and installs it even
when the existing version is equal or newer. `--tarball FILE` selects a recorded
archive and its adjacent `.rds` instead. Its recorded library sources must
match this checkout; an equal version alone is insufficient. Repeat `--dependency FILE` to install
private dependency archives in the supplied order. Dependencies and their version
constraints come from DESCRIPTION; `requirements.R` adds CLI package names.
The installer uses `utils::install.packages()` and the public `desc` metadata
reader. It writes only to the selected library and reuses compatible packages
visible in R's other libraries. CRAN is the default repository; explicit R
repository options remain effective. Installation warnings terminate the operation
before CLI publication. Selected archives resolve their own DESCRIPTION dependencies.
Private packages must already be available or supplied as recorded `--dependency`
archives; GitHub `Remotes` are not downloaded implicitly.
The installed product must load from the selected library, match the selected
artifact and expose its declared CLI exports.

Replacing an existing package or CLI asks once before any build or installation.
The prompt defaults to `[Y/n]`: Enter or `y` accepts; `n` cancels unchanged.
EOF fails. `--yes` skips that question.
There are no public `--component` or `-Component` modes. R package maintenance
and documentation building remain separate operations under `lib/inst/`.
The product calls `lib/inst/install.R`; that library installer has no CLI-prefix
dependency and can be sourced from the standalone package.

## Current R and its libraries

Installers, uninstallers and generated launchers share the same resolver.
macOS uses the current Framework alias, then an unversioned Homebrew R prefix;
Linux uses `/usr/local/bin/Rscript`, then `/usr/bin/Rscript`. An arbitrary
`Rscript` first on PATH cannot replace these system locations. A private R
installation outside these locations is not supported by this resolver.
On Windows, the current R-core registry version selects the installation,
with HKCU before HKLM. R's installer must register it; see the
[R Windows FAQ](https://cran.r-project.org/bin/windows/base/rw-FAQ.html).

The receipt records the interpreter as history. For manifest version 2 it
also binds the selected artifact, installed library bytes and product resources.
The launcher selects that recorded library and rejects an incompatible package,
including a conflicting namespace loaded by a user profile. It still resolves
the current R executable on each call; no version-specific RSCRIPT file is kept.
Reinstall after an incompatible R upgrade. Version 1 manifests retain the
legacy library-resolution behavior until migrated.

`--library` defaults to R_LIBS_USER, including Renviron files; discovery does
not execute profiles. Keep the bootstrap dependencies jsonlite and digest
visible to the current R. No profile is edited.

## Local acceptance and rollback

Before committing a CLI transaction, both publishers run only `--version` and
`--help`, with the selected library and explicitly empty R environment/profile
files. Those two operations must be local and require no service credentials.
`doctor`, APIs and scientific operations belong to product acceptance tests.
Normal CLI invocations keep their normal user environment. This distinction
uses R's documented [startup controls](https://stat.ethz.ch/R-manual/R-patched/library/base/html/Startup.html).

The CLI lives in `PREFIX/bin/<command>` and `PREFIX/libexec/<runtime>`.
Receipt paths, hashes and symlink ancestors are validated. Failed publication
restores the previous CLI; an already installed R package remains installed.
Updates retire previously owned files absent from the new payload. Foreign
files and nonempty directories survive. Unknown or modified files are refused.

```sh
sudo bash install/uninstall.sh
sudo bash /usr/local/libexec/<runtime>/install/uninstall.sh
```

Removal works without the source checkout. Supply the chosen `--prefix` again;
`--library` selects a library for receipt-reading dependencies, not a removal
target. The final notice reports the historical package library from the receipt
(or unknown if absent). It never removes an R package.

## Console

The launcher runs `install/cli/entry.R`. It consumes `--verbose` and
`--quiet` placed before `--` and passes the other arguments to the product's
`cli/main.R` as `CLI_ARGS`.
It loads the managed renderer `install/cli/console.R` only when its bytes
match the receipt and evaluates `main.R` under the renderer's handlers.

stdout carries results. The renderer writes on stderr the classed conditions
the library signals: `moduleNote`, `moduleProgress` and `moduleDetail`
messages, warnings and errors. On a terminal it starts each condition with a
symbol (`i`, `>`, `.`, `!` or `x`), coloured unless `NO_COLOR` is set and not
empty; off a terminal it writes the text alone, with `warning: ` before a
warning. A message without one of those classes keeps R's default output.
`--quiet` hides notes, progress and detail; `--verbose` shows detail and the
fields `operation`, `phase`, `unit`, `path`, `count` and `total`; given
together, `--quiet` prevails. An error is
written as `<command>: <message>`; an error without the class `moduleFailure`
or `moduleUsage` adds the R version and the package found. An error exits
with 2 for `moduleUsage`, with the `status` field of the error when it
carries one, and with 1 otherwise; an interrupt exits with 130.

## Windows

```powershell
powershell -ExecutionPolicy Bypass -File install\install.ps1 -Yes -Library "C:\R library" -Prefix "C:\Tools\product" -NoPath
```

Options are `-Yes`, `-Check`, `-Library`, `-Dependency`, `-Tarball`, `-Prefix`
and `-NoPath`. The default prefix is `%LOCALAPPDATA%\Programs\<package>`.
Unless `-NoPath`, installation adds its bin directory to the user PATH; removal
only removes an entry its receipt records adding. Use `install\uninstall.ps1`
(or the installed copy) with `-Prefix`, `-Library`, `-Yes` and `-NoPath`.
macOS checks do not certify native Windows or real sudo.

## Product declarations and tests

`requirements.R` names `command`, optional `runtime`, `exports`, `packages`
(an unnamed character vector), `tools` and optional tools. A CLI that starts
external executables also declares `pathEnv`, an upper-case name ending in
`_COMMAND_PATH` (NGR: `pathEnv = "NGR_COMMAND_PATH"`). R startup files such as
`~/.Renviron` can replace `PATH`. The generated launchers export the caller's
`PATH` in that variable, and the product's `cli/main.R` must restore it before
starting any executable:

```r
Path <- Sys.getenv("NGR_COMMAND_PATH", unset = NA_character_)
if (!is.na(Path)) Sys.setenv(PATH = Path)
Sys.unsetenv("NGR_COMMAND_PATH")
```

`documentWriters`, optional, names the library functions whose standard
output is a document; `aom verify` does not report their `cat()` and
`print()` calls.

`manifest.json` version 2 explicitly records product/package origin, source,
installed destination (product files only), optional module target, ownership
and mode. Package resources stay in the R installation. Version 1 remains
readable for existing modules. The manifest lists the payload and the command's three `bin/` entries.
The manager generates those launchers from the managed `install/cli/command.*`
templates; old product-owned launchers are not read. There is no `launchers`
or `verify` policy switch. Run `bash install/update-manifest.sh` after changing
payload files. Domain code and public APIs remain product-owned.

`bash install/cli/test-installers.sh [R_LIBRARY]` runs disposable fixtures.
Supplying an installed library also runs `install/acceptance.R` through the
installed CLI without replacing that library. That product acceptance,
`install/cli/testProduct.R`, requires `--version` to print two lines,
`<package> <version>` and `build: <short commit>` with a prefix of the commit
that `BUILD_INFO` records, or `build: unknown` when it records none. It runs
`doctor` and requires one JSON report on stdout with `schema`, `package`,
`version`, `summary.status` and `checks`, exit status 1 exactly when a
required check fails and 0 otherwise, every check named by `doctor --help`,
and exit status 2 for an argument. Windows uses
`powershell -File install/cli/test-installers.ps1 [-Library R_LIBRARY]`.
The internal manager supports these isolated CLI tests; it is not a public
partial-installation mode.
