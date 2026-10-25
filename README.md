# NGR

NGR incorporates project resources, renders Quarto books, documents and
presentations, and registers or publishes their outputs on Netlify. The
scaffold or scientific producer owns data selection and calculation; NGR owns
the representation. Rendering consumes the project's data and does not generate
missing scientific results; it never starts a map producer or OpenQuake.

| Component | Location |
| --- | --- |
| R package | [`lib/`](lib/) |
| Command-line interface `ngr` | [`cli/`](cli/) |
| Consumer skill | [`skills/ngr/`](skills/ngr/) |
| Product installer | [`install/`](install/) |
| Library installation and maintenance scripts | [`lib/inst/`](lib/inst/) |
| Application (reserved) | [`app/`](app/) |
| MCP (reserved) | [`mcp/`](mcp/) |
| Live continuity state, maintainer rules and open defects | `dev/` |

## Command-line interface

`ngr` runs in the project directory, or in the directory that `--root DIR`
selects; `DIR` must exist, and relative paths use the selected project. Every
operation is an exported function of the installed NGR package. Runtime
commands load the installed package and do not install dependencies. The CLI is
a development implementation; project acceptance is in progress.

| Task | Command form | Skill reference |
| --- | --- | --- |
| Bring resources from a source into the project | `ngr pull --from <manifest.json> [paths...]` | [Resources](skills/ngr/references/resources-manifest.md#resources) |
| Update the project from its recorded sources | `ngr pull [--force] [--dry-run] [paths...]` | [Resources](skills/ngr/references/resources-manifest.md#resources) |
| Compare the project with its sources | `ngr status [--check] [paths...]` | [Resources](skills/ngr/references/resources-manifest.md#resources) |
| Check the project against its declared checks | `ngr check` | [Resources](skills/ngr/references/resources-manifest.md#resources) |
| Render a master with the book, html, revealjs or docx profile | `ngr render <input.qmd> --profile <profile>` | [Render](skills/ngr/references/render.md) |
| Render or plan the artifacts of a manifest | `ngr render --manifest <file> [--dry-run]` | [Render](skills/ngr/references/render.md) |
| Upload an existing output | `ngr deploy <alias> <dir> [--prod]` | [Deploy](skills/ngr/references/deploy.md) |
| Register or create a Netlify site | `ngr deploy init <alias> <site-name> [--create]` | [Deploy](skills/ngr/references/deploy.md) |
| Configure a domain and HTTPS | `ngr deploy domain <alias> <domain> [--https]` | [Domains and recovery](skills/ngr/references/domains-recovery.md) |
| Remove a local site binding | `ngr deploy unbind <alias>` | [Domains and recovery](skills/ngr/references/domains-recovery.md) |
| Diagnose this installation | `ngr doctor` | |
| Show the package version and the build commit | `ngr --version` | |

`ngr --help` lists the commands, and `ngr <command> --help` gives the exact
arguments of each, including the `--manifest` forms of `deploy`. The
[CLI guide](https://kanameishi.github.io/NGR/articles/cli.html) and
[`cli/README.md`](cli/README.md) describe the project workflow, the source
manifest, and the render and deploy contracts.

## Skill

The consumer skill [`skills/ngr`](skills/ngr/SKILL.md) operates the installed
`ngr` command for a project. Resource incorporation, local rendering and
Netlify publication are separate operations; the skill combines them when the
request includes their effects. It requires the user's validation of the
source selection, master and profile, aliases, output paths, replacement policy
and publication site, account, mode and domain before it writes an executable
manifest or runs the dependent operation. The skill is approved in the agents
catalogue; this directory holds its producer prototype, from which the approved
copy is promoted.

## Installation

The R package and the `ngr` command are installed together from the repository
root with `sudo bash install/install.sh`; R must already be installed.
[`install/USAGE.md`](install/USAGE.md) documents the installer, its Windows
entry and the removal of the product. Requirements depend on the operation;
`cli/README.md` lists them.

## Documentation

[Public documentation](https://kanameishi.github.io/NGR/) is rendered by
pkgdown from `lib/vignettes/` and `lib/man/` and published to `gh-pages`; its
home page is [`lib/README.md`](lib/README.md), the entry of the R library.

Repository boundaries and maintainer rules are in `dev/ARCHITECTURE.md`.
