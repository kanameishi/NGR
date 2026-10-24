# R package maintenance

The library's installation and maintenance scripts live in `lib/inst/` and run
from `lib/`, the package root. They use the operations of `inst/package.R` and
R tooling; none of them depends on `install/`. The product installer under
`install/` calls `inst/install.R` to install the library and handles the CLI;
[USAGE.md](USAGE.md) documents that operation.

## Prepare the environment

Install R and make `Rscript` available first. Source builds may need the
platform's compiler tools and system libraries; manuals need LaTeX. These
scripts install R packages, not operating-system dependencies or R itself.

Sourcing `inst/package.R` defines `installRequirements()`, `documentPackage()`,
`buildPackage()`, `checkPackage()` and `installPackage()` without executing
them. Choose a writable R library explicitly, preferably one already in
`.libPaths()`. In R, with working directory `lib/`:

```r
source("inst/package.R")
installRequirements(
  path = ".", library = "/absolute/path/to/R/library", dependencies = TRUE,
  packages = c("roxygen2", "pkgbuild", "rcmdcheck", "spelling", "pkgdown", "rhub", "digest", "testthat")
)
documentPackage(path = ".", roxygen = TRUE)
```

`installRequirements()` installs the named packages and the DESCRIPTION
dependencies of the selected scope: `NA` reads Depends, Imports and LinkingTo,
and `TRUE` adds Suggests. The public `desc` reader preserves DESCRIPTION version
constraints. Compatible packages in visible libraries are reused; installations
write only to the selected library. CRAN is the default, with explicit
repository options preserved. Installation warnings stop the operation.
Private dependencies must be installed from the explicitly selected source or
recorded archive first; Remotes do not trigger implicit GitHub downloads. This
is a dependency preparation operation, not a rollback transaction.

A new library must remain visible in subsequent sessions: use R's existing
`R_LIBS_USER` configuration, or `.libPaths(c(Library, .libPaths()))` in an
interactive R session. Each operation restores any temporary library search
path it changes. Private dependency sources require their normal credentials;
the helper does not create credentials or make a private repository public.

`documentPackage()` runs roxygen2 when `roxygen = TRUE` and then checks the
spelling of the package and its vignettes; unreviewed terms stop the
operation. Review the generated diff before identifying a release candidate.

## Independent operations

| Entry | Arguments | Effect |
| --- | --- | --- |
| `Rscript inst/build.R` | output directory | Build one source tarball without manual or vignettes; write its record |
| `Rscript inst/cran-check.R` | tarball, new check directory | Check that exact tarball; retain options, results and logs |
| `installLibrary()` from `inst/install.R` | path, library, and a build directory or a recorded tarball | Install the library and its runtime dependencies |
| `inst/rhub.R` | R-hub environment variables | Prepare the dependencies of an R-hub job |
| `inst/rhub-check.R` | none; run interactively | Select the R-hub checks through `rhub::rhub_check()` |
| `inst/cran-submit.R` | none | Submit the package through `devtools::submit_cran()` |

A missing or extra argument stops `build.R` and `cran-check.R` before the
requested operation. `buildPackage()` and `checkPackage()` can also be called directly
after sourcing `inst/package.R`; `buildPackage()` builds the manual and
vignettes unless `documents = FALSE`.

The build directory must lie outside `lib/`. Use a new build destination when
that version already exists, and a new check directory for each attempt. Keep
the `.tar.gz` and adjacent `.tar.gz.rds` together. The record contains the
SHA-256, package/version, source commit, clean-tree observation and the SHA-256
of each source file. Check adds the R version, platform, arguments,
environment, status, errors, warnings, NOTEs and log directory. Checks reject
changed tarball bytes. Errors and warnings fail; NOTEs remain for human review.
Interrupted checks cannot retain a passed verdict.

The check enables `--as-cran`, `--run-donttest`, incoming/remote checks and
Suggested dependencies. It cannot exercise tests excluded from the artifact.
It does not imply a complete contextual CRAN audit or certification on another
R/platform.

```r
source("inst/install.R")
installLibrary(path = ".", library = "/chosen/R/library", build = "/chosen/build")
```

`installLibrary()` takes exactly one of `build` or `tarball`. With `build` it
builds `lib/` without manual or vignettes and installs the result; with
`tarball` it installs that recorded archive without rebuilding. `dependencies`
names recorded archives of private dependencies, installed first in the
supplied order. Each installation verifies the archive against its record and
the installed package version, and writes `.aom-install.rds` with the artifact
and file hashes into the installed package. It does not run a check or install
the CLI. A local development installation may use an unchecked build.
Installing a CRAN release candidate still requires the separate release review
below.

`.github/workflows/rhub.yaml` stages `lib/` in the R-hub checkout and sources
`inst/rhub.R`, which installs the check tools and dependencies into
`R_LIBS_USER` and builds and installs the local package when the job asks for
it. R-hub uses the branch on the live remote, not the local tarball; its
dispatch is not its result.

## Release and external operations

The release sequence is documentation, not a script:

1. Prepare development requirements with `installRequirements()` in an explicit
   R library.
2. Generate documentation with `documentPackage()`, review source changes and
   tests.
3. Identify and commit the intended source candidate through normal Git work.
4. Build once with `inst/build.R`, then check that tarball with
   `inst/cran-check.R`. Retain its adjacent RDS record and complete check logs.
   Review every NOTE.
5. Review the package contextually against current CRAN guidance; the approved
   `cran` skill can consume these artifacts. A green local check is not that
   audit.
6. Publish the accepted branch explicitly. Verify CI and public Pages for that
   commit. In interactive R, source `inst/rhub-check.R` to select remote
   checks; verify their results separately and retain the run identities.
7. Submit with `source("inst/cran-submit.R")`. `devtools::submit_cran()` builds
   a new tarball for the submission; it does not receive the artifact checked
   by `inst/cran-check.R`. Do not use that submission to claim that the
   checked tarball was submitted.
8. Retain the submission receipt. An uncertain upload is not permission to
   retry.

Record the exact candidate commit, tarball/hash, local check, contextual CRAN
review, CI/Pages results and R-hub results. Do not reuse evidence after
changing the source candidate or tarball.

The approved `cran` skill reviews the source and saved evidence. It neither
installs dependencies nor replaces these executable checks. Site generation
uses `pkgdown::build_site("lib")` from the repository root and the pkgdown
workflow; it is not a side effect of the check.

## Product dependencies

This is package maintenance, not an installer for all product components. The
product installer adds the CLI's R packages, which `install/requirements.R`
names, through `installRequirements()` after installing the library. That list
holds package names only; dependencies and their version constraints belong in
DESCRIPTION. The CLI runtime loads the installed package, independently of this
source checkout.
