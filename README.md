# NGR

[Documentation](https://kanameishi.github.io/NGR/) · [R package](lib/)

| Component | Source | Status |
|---|---|---|
| R package | [lib/](lib/) | Existing package |
| CLI | [cli/](cli/) | Development implementation; project acceptance in progress |
| Application | [app/](app/) | Planned |
| Skill | [skills/ngr/](skills/ngr/) | Producer prototype; the approved and installed copy lives in agents `skills/ngr` and is promoted from here |
| MCP | [mcp/](mcp/) | Planned |

Public documentation is rendered by pkgdown from `lib/vignettes/` and
`lib/man/`, then published to `gh-pages`.

## Installation and use

Use the common macOS, Linux or Windows installer from the repository root to
install the R library and CLI together. Follow the
[installation and CLI guide](https://kanameishi.github.io/NGR/articles/cli.html).
Runtime commands load the installed package and do not install dependencies.

The repository is private. Public documentation is on
[GitHub Pages](https://kanameishi.github.io/NGR/).

Open the RStudio project inside `lib/` for package development.
