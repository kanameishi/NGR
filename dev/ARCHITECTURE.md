# Repository architecture

Under the family policy of the AOM model (AOM `dev/ARCHITECTURE.md`, owner rulings of 2026-10-15 and 2026-10-24), `install/` holds the product installer and `lib/inst/` holds the library's installation and maintenance scripts.

| Folder | Ownership |
| --- | --- |
| `lib/` | Independently buildable R package, APIs, help, vignettes, tests and runtime resources |
| `cli/` | Shared `main.R` command entry, minimal platform launchers and operational resources |
| `install/` | macOS/Linux and Windows entry points; AOM-managed product installer and CLI publisher; product declarations and installation tests |
| `app/`, `skill/`, `mcp/` | Their implemented components; reserved directories are not installable products |
| `lib/vignettes/`, `lib/man/` | Public articles and R reference, published by pkgdown |
| `dev/` | Live continuity state, this document, open defects and zipped legacy; see [dev/ maintenance](#dev-maintenance) |
| `.github/` | Repository automation |

## Owner rulings

Rulings given by the owner in September 2026 that still constrain the product
or the repository and that the code does not show by itself. Each names the
closed chain it came from; those chains were deleted under the maintenance rule.

- **Boundary with AOM.** The canonical installer and the canonical CLI contract
  belong to AOM. NGR delivers an accepted source and candidate; AOM keeps the
  canonical installation and the alignment of the consumer skill.
  (cli-repair, cli-root, ngr-integration, 2026-09-20)
- **Scientific contracts.** Scientific parameters and paths are consumed from
  their producer contracts; a producer contract is never changed to fit an
  incorrect reader. NGR hydrates and renders scaffolds and holds no closed
  catalogue of scientific products; the readers live in the scaffold source,
  `libraries/reports/sha`. (cli-repair, report-contracts, 2026-09-20)
- **Installation.** The normal reinstallation from a checkout is
  `sudo bash install/install.sh`. The owner rejected reinstalling through the
  `--tarball` flow: «no entendiste cómo se instala ni cómo funciona el
  instalador. rechazado». `--tarball` remains the documented special case in
  `install/USAGE.md`. (srk-can-install, 2026-09-24)
- **Visual acceptance of Word output.** The owner judges DOCX layouts in
  Microsoft Word. A LibreOffice rendering does not demonstrate Word fidelity,
  and the owner asked to stop PDF conversions for that purpose. Agents do not
  operate the owner's Word or the documents it has open.
  (srk-cover-comparison, srk-template, ngr-repair-build, 2026-09-24)
- **Library in production.** Any change to existing implementation goes
  through a Ship of Theseus plan: exact baseline, identifiable candidate,
  competent oracle, integration of the accepted change only.
  (cli-repair, 2026-09-20)

Pending owner decision carried from the 2026-09-24 repair: the interface
language (`lang`) of the DOCX preliminaries was deferred by the owner.

## dev/ maintenance

Rule confirmed by the owner on 2026-09-27 together with the maintainer of the
common rule (gmsp session):

1. `dev/SoT/` and `dev/plan/` hold only live chains: folders whose `STATE.md`
   is `ACTIVE` or `BLOCKED`.
2. A `DONE` folder is deleted in the commit that closes it. Before that
   commit, the owner rulings that survive move to this document and the open
   waits and defects move to the successor chain.
3. `dev/` contains only `dev/SoT/ACTIVE.md`, this document, the live
   `STATE.md` chains, `dev/legacy/`, `dev/bugs/` and what a live state cites.
4. Everything under `dev/` is tracked and carries no evidence bytes: no
   renders, workspaces, frozen baselines or installed copies.
5. The product (`README.md`, `cli/`, `install/`, `lib/`, `skills/`) does not
   link to `dev/`.
6. Defects: one open defect per file under `dev/bugs/` of the owning
   repository, with no imposed file format. The commit that fixes a defect
   deletes its file and names it. Reports written by other agents for NGR
   belong in `dev/bugs/`, not in a root `bugs/` folder.

Legacy lives in `dev/legacy/`, tracked, as one zip per topic plus its
`README.md` index with SHA-256 values; the repository root has no `legacy/`
folder. Originals leave the tree when their zip is created; Git keeps their
history in the cited commits.

## Installation and package lifecycle

Public entries are `install/install.sh` and `install/install.ps1`. `install/`
holds the product installer that AOM manages; the library's installation and
maintenance scripts run from `lib/` and do not depend on it. Dependencies,
installation, documentation, build, checks and publication remain explicit,
separate operations. Windows/macOS acceptance must be verified independently of
this document.

The R package builds from `lib/` without sibling directories. CLI/app consumers
use the installed package. `lib/inst/` is for package runtime resources and the
library's autonomous installation and maintenance scripts; the module installer
delegates library installation to `lib/inst/install.R`. Installing software
does not publish Pages/CRAN, mutate Git or migrate project data.

The installer writes the installed scaffold's `BUILD_INFO` (`buildInfo` in
`install/requirements.R`) from the Git commit of the checkout; without a known
commit the file is absent, and NGR treats the revision of the installed
resources as `unknown` and dirty. On Windows, the installer checks the managed
paths for reparse points through `install/cli/checkPaths.ps1`, which reads them
from a temporary UTF-8 file because NGR's resource paths exceed the Windows
argument limits. The product acceptance `install/acceptance.R` pulls only
`bib/apa.csl` into the temporary project of the installed-product test and
checks its status and its bytes against the installed scaffold.

## Console

NGR follows the family logging ruling of 2026-10-24 (AOM `dev/ARCHITECTURE.md`,
"Logging belongs to the CLIs"). The library signals `moduleNote`,
`moduleProgress` and `moduleFailure` conditions through `.inform()` and
`.fail()` of `lib/R/conditions.R`. `cli/main.R` reads `CLI_ARGS` and
`CLI_RESOURCES` from `install/cli/entry.R`, writes results to stdout and leaves
its errors to the renderer `install/cli/console.R`; `ngr deploy` without
arguments writes its help with exit 0.

Declared differences: Quarto and the checks a source declares run with the
command's console, outside the renderer; the functions named in
`documentWriters` of `install/requirements.R` write document text to stdout;
the errors and warnings of the functions that the command's operations do not
call (plots, tables and document writers) remain plain R warnings and errors,
which the family table admits at the warning and failure levels; the closing
`[pull]` line and the `doctor` report keep their bracketed form on stdout as
results.

## Documentation and Pages

Repositories are private by policy. GitHub Pages is the public documentation
surface: links must point to published pages, not private source, Issues or
repository files. Help uses the maintainer contact. Keep pkgdown repository
URL discovery disabled with `repo: {url: {}}` and omit repository navigation.

Public articles and reference sources are in `lib/vignettes/` and `lib/man/`.
The package README supplies the home page. With R, Pandoc, pkgdown and package
dependencies available, build locally from the repository root:

```sh
Rscript -e 'pkgdown::build_site("lib")'
```

The current `.github/workflows/pkgdown.yaml` builds from `lib/` on pushes to
`main` or manual dispatch and publishes `lib/docs/` to `gh-pages`. Pages serves
that branch at `https://kanameishi.github.io/NGR/`; reference and articles use
`reference/` and `articles/`. There is no Jekyll portal or second documentation
pipeline. App, skill and MCP folders remain reserved components.

There is currently no R-hub workflow. Its maintenance entry requires a workflow
configured for the package in `lib/` before remote checks can be dispatched.
