# Scaffolds, project folders and shared builders

## Incorporation and updates

`ngr pull` incorporates resources and updates resources already
associated with a project. Run it from the project directory. It reads
locally available sources; it does not clone, fetch or select their Git
branches.

The installed NGR base supplies `styles/`, `yml/`, `lua/` and
`bib/apa.csl`. A separate book scaffold supplies its chapters,
figure/table blocks, report masters, captions, scientific bibliography
and project seeds. Its location is selected by its own `manifest.json`;
it need not be inside the NGR checkout.

With a SHA source already available at the indicated path:

``` sh
ngr pull --from ngr --from /path/to/sha/manifest.json
ngr status --check
```

The project records both source paths. Later updates use those
associations:

``` sh
ngr pull
ngr pull --source sha _fig _tbl scripts --force
```

The first update requires no repeated source path. The second explicitly
permits replacing differing managed files in the named destination
folders. Existing seeds remain project-owned even with `--force`.

A source is identified by its `id`, not by where it lives. To hydrate
from another copy of a registered source, or after moving the project or
the source, name its manifest again:

``` sh
ngr pull --from /another/location/sha/manifest.json --force scripts
```

The project then follows that location until another `--from` re-points
it.

## Source and destination structure

Each source has its own manifest beside its resources. The manifest maps
source paths to destination paths and declares `managed` or `seed`
ownership:

``` json
{
  "schemaVersion": 1,
  "id": "book",
  "resources": [
    {"from": "content/chapters", "to": "_chapters", "ownership": "managed"},
    {"from": "masters", "to": "_master", "ownership": "managed"},
    {"from": "masters/book.qmd", "to": "_master/book.qmd", "ownership": "seed"}
  ]
}
```

A file entry may restate one file already covered by a directory entry
of the same source to give it a different ownership. Here `pull` keeps
every master up to date except `book.qmd`, which becomes project-owned
after it is first seeded.

The source layout is independent of the project layout. Several sources
may contribute to `_chapters/`, `_fig/` or `_tbl/`; NGR does not insert
a folder named after each source. Distinct files coexist. Contributions
to the same path must have identical content and ownership. Conflicts
are rejected before any copying, including claims from sources not
selected by the current command. `--force` does not choose a winner
between incompatible sources.

A source may also seed the project’s artifact list. Its string values
can name the project through `{project_id}`, the lowercase alphanumeric
form of `params.project_id` in the project’s `params.yml`. Nothing is
seeded while that id is missing or still the placeholder shipped by the
source; set it and run `ngr pull` again.

The project’s `manifest.json` records artifacts, source associations and
per-file provenance. The source manifest is not copied over it. NGR does
not create a second resource database in `.ngr/`.

For the current SHA scaffold:

| Destination | Responsibility |
|----|----|
| `_master/` | Deck, hub and transmittal masters kept up to date by `pull`; `book.{es,en}.qmd` and `docx.{es,en}.qmd` are seeded once and then project-owned |
| `_chapters/`, `_fig/`, `_tbl/` | Shared destinations for narrative and executable Quarto blocks |
| `_book/`, `_docx/`, `_revealjs/` | Format-specific composition; source blocks, not generated output |
| `_captions/`, `_scope/`, `_results/` | Scaffold captions and report sections |
| `scripts/` | Scaffold consumers and remaining builders; see migration status below |
| `bib/` | Scientific bibliography from the scaffold; CSL formatting from NGR |
| `_local/`, `params.yml` | Project-owned seeds and customizations |
| `oq/`, `gmsp/`, `data/`, `run/` | Project data and producer records, excluded from resource-source destinations, together with `manifest.json`, `hazard.json` and `newmark.json` |
| `html/`, `docx/` | Rendered output, separate from scaffold source folders |

Updating never deletes project extras or files retired from a source. An
obsolete script is removed separately after its consumers have migrated
and local ownership has been checked. A directory is not obsolete merely
because some of its builders moved into the R package.

## Figure and table builders

The installed R package owns reusable representation: plot and table
builders with explicit arguments and return values. A scaffold owns
narrative, captions, composition and preparation of the data passed to
those functions. Scientific calculations remain with their scientific
producer.

This applies inside `scripts/fig/` and `scripts/tbl/`: shared
representation belongs in NGR; a scaffold-specific selection can remain
with its consumer. Moving every script unchanged into a package would
preserve hidden dependencies on project globals. Renaming colliding
scripts would leave duplicated implementations.

**Builder migration is pending.** SHA retains its figure and table
scripts, including `scripts/fig/UHS.R`, which calls the existing
[`buildPlot()`](https://kanameishi.github.io/NGR/reference/buildPlot.md)
API. Resource composition tests and successful renders do not establish
a new builder architecture. Any extraction must first justify its
responsibility and benefit against direct use of the existing NGR APIs.

Two themes can also have incompatible setup scripts or parameter
schemas. The engine detects conflicting paths; it cannot reconcile their
R semantics. A combined report requires compatible consumers and a
master that composes them.

## Existing PSHA projects

A project created with the earlier tools keeps its artifacts and
publication destinations in `qrt.manifest.json`, together with a
`scaffolds` block of per-file receipts written by those tools. NGR does
not read that file name and never writes to it. Work on a preserved copy
first. The two manifests coexist during verification: the earlier tools
keep operating the project until their file is removed in a later
commit.

1.  Copy `qrt.manifest.json` to `manifest.json`, keeping the original in
    place.
2.  Delete the copy’s `scaffolds` block. Those receipts describe copies
    made by the earlier tool; the next step records new ones for every
    file. Keep `artifacts` unchanged, including `siteSlug` and `domain`.
3.  Incorporate the sources, allowing managed files to be replaced:

``` sh
ngr pull --from ngr --from /path/to/sha/manifest.json --force
ngr status --check
ngr doctor
```

Name destination folders after the manifests to enroll only part of a
source. Parameters, `_local/` and the four book and DOCX masters stay as
the project has them. The scaffold’s manifest readers
(`scripts/setup/toc.R`, `transmittal.R`, `utils.R`) arrive with
`scripts/` and read `manifest.json`. Render the project’s masters and
compare against the earlier tools’ output; once everything checks out,
remove `qrt.manifest.json` in a separate commit of the project.
