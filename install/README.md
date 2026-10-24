# Installation policy

## Location and ownership

| Location | Responsibility |
| --- | --- |
| `install/install.sh` | Public installation entry for macOS/Linux |
| `install/install.ps1` | Public installation entry for Windows, invoked with PowerShell |
| `install/` | AOM-managed product installer and CLI publisher, product declarations and installation tests |
| `lib/` | Independently buildable R package and public APIs |
| `lib/inst/` | Package runtime resources and the library's autonomous installation and maintenance scripts |
| `cli/` | CLI payload, argument adapter and operational resources/tests |
| `lib/vignettes/`, `lib/man/` | Public documentation sources rendered by pkgdown |

The module installer installs the complete product by calling
`installLibrary()` from `lib/inst/install.R` and handling the CLI. The
maintenance scripts in `lib/inst/` run from `lib/` and do not depend on
`install/`; [MAINTENANCE.md](MAINTENANCE.md) describes them.

`install/` does not enter the R package. The CLI receipt owns a minimal
removal bundle under its runtime; it contains no package implementation or
release tooling.

## Product and component installation

The product entry coordinates installation of the selected R library, its
dependencies and the implemented CLI. R-only and CLI-only installation remain
explicit operations. Reserved app/skill/MCP components are not installed.
The runtime calls the installed library; it neither sources the checkout nor
installs or updates dependencies during normal commands.

Resolve dependencies from DESCRIPTION **and actual component operations**.
Respect version constraints, additional R packages, interpreters and external
tools. Install missing/incompatible R requirements in the selected library
and preserve compatible visible packages. An unloadable package is not simply
an absent package. Private/development dependencies require an explicitly
identified source or artifact; do not silently substitute a CRAN release.

Inspect destinations, ownership, conflicts and prerequisites before modifying
them. Identify the selected package artifact by hash and verify its installed
identity and required API. Package name and version alone do not identify a
development build. Installation of a selected tarball must not rebuild another
tarball or imply it passed a release check.

## Platforms and privileges

Each product uses `cli/main.R` as its single R command entry on macOS and
Windows. Platform launchers only locate the installed runtime and forward
arguments, streams and exit status. Command parsing and dispatch are shared;
calculations and reusable domain operations remain in the installed library.
Preserve required Python helpers where their operation needs Python. A new
filename alone does not complete the transition from an existing Bash driver.
Reserved products receive this entry when their CLI is implemented, not an
empty placeholder presented as an operational interface.

The CLI must be usable from Windows and macOS. Providing a `.ps1` file or
passing a macOS check is not evidence of Windows support. The maintainer owns
the choice and implementation of the required runtime; the user is not asked
to design that layer. Native R/Python code should be reused where applicable.
Existing Bash requirements must be handled by a deliberate Windows installation
contract with launchers and path handling; do not silently assume WSL or Git
Bash is already present.

The established macOS/Linux entry convention is
`sudo bash install/install.sh` when the selected system CLI destination
requires elevation. The Windows entry is `install/install.ps1` through
PowerShell. Privilege requirements must follow the actual destination and
component. Elevating CLI installation must not silently select root's R
library, create root-owned files in the caller's R library or change the
intended R user. Record and verify effective R, user, library and CLI paths.
No fallback to a different destination after a permission failure.

## Separate effects

Installation, documentation generation, build, package checks, CRAN submission,
R-hub dispatch and Pages publication are separate explicit operations.
CRAN tooling location does not authorize automatic submission, publication,
Git changes, credentials, OS-level installation or project-data migration.

Retain the robust checker contract: check the exact recorded tarball, retain
options/logs/results, expose errors and warnings, leave NOTEs for review and
never reuse a passed record after a failed or interrupted check. Contextual
CRAN review complements those checks; it does not replace them.

Do not replace the maintained workflow with a bare R CMD check. Submission is
a separate explicit operation: identify its actual implementation and its input
artifact, retain the receipt and do not retry an uncertain upload. Moving a
submitter does not authorize changing or executing it.

Updates and removal respect ownership receipts, preserve foreign/modified
files and keep shared R libraries/dependencies unless their removal is an
explicitly selected operation. Report partial success accurately: failure of
CLI installation does not undo an R installation. Preserve recovery evidence
when restoration is uncertain. Keep QRT/PSHA/SPT references until their owner
explicitly retires them.

## Acceptance

Validate the installed interfaces outside the checkout, including package/API
identity, a representative operation, missing dependencies, compatible
dependency preservation, file conflicts, update/removal and failure handling.
Exercise paths with spaces and Unicode, argument forwarding and exit status
on the actual supported platforms. Record macOS and Windows results separately.

This file defines the required policy. It does not certify that Windows tests
have passed. Repository sources remain private; public help links use Pages.

## NGR migration status

The canonical kit preserves the scaffold payload declared by
`manifest.json`. It generates `scaffold/BUILD_INFO` when the source Git commit
is known; without Git provenance the record is absent and NGR identifies the
resources as an unknown, dirty revision.
Windows path validation passes the complete path list through a temporary
UTF-8 file, so the number of scaffold files does not enlarge the command line.

The installed-interface check pulls only the declared `bib/apa.csl` resource
into a temporary project and verifies status and bytes. It does not render,
contact Netlify or publish. Existing scaffold/release acceptance is separate.

See [USAGE.md](USAGE.md) for the common installation and removal contract and
[MAINTENANCE.md](MAINTENANCE.md) for the maintenance of the R package.
