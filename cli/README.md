# NGR CLI

The CLI lives in `cli/`; the R package remains independently buildable in
`lib/`. Follow the [public installation guide](https://kanameishi.github.io/NGR/articles/cli.html#install)
from the repository root. Installation and package tooling live in `install/`,
with macOS and Windows entries `install/install.sh` and `install/install.ps1`.
The CLI component checks the installed NGR package and never installs, updates
or removes R packages. The common entry coordinates the selected components.
Modified or foreign runtime files block replacement or removal.

Requirements depend on the operation. All commands use `cli/main.R` and the
installed NGR package. The macOS launcher uses Bash; Windows uses `ngr.cmd`
from CMD and `ngr.ps1` from PowerShell. Both are installed in the same bin directory.
DOCX composition needs Python >=3.9 with `lxml` in the interpreter selected by
R (`python3` on macOS, `python` on Windows). Provision it explicitly with
`python3 -m pip install lxml` or `python -m pip install lxml` on Windows,
using the environment that will run NGR. The installer checks Python's presence;
DOCX rendering checks `lxml` before invoking Quarto. Other profiles do not need it.
On Windows, staging a project
with symbolic links also uses Python's standard `os.symlink` operation to preserve
file/directory links, including dangling links. Rendering needs Quarto and
its selected engine. Manifest operations use the R package's JSON reader. Publication
uses the Netlify CLI; DNS diagnostics use dig when available. A scaffold's
declared checks and scientific content can require additional software.

## Project workflow

Run in the project directory, or select it with `--root DIR`. `DIR` must
exist; a relative `DIR` is resolved from the caller's
working directory. Source manifests, masters, artifact paths and
`.netlify/sites.env` resolve from the selected project. Operations retain
their existing path rules: supported absolute paths keep their destinations,
and Quarto masters remain project-relative. Without `--root`, the working
directory remains the base.
No enclosing Git checkout or `--project` argument is needed.

The option may appear before or after the command and also accepts
`--root=DIR`. Supply it once, before any `--` argument separator. For example,
from outside the project:

```sh
ngr --root /path/to/project pull --from /path/to/book/manifest.json
ngr render --root /path/to/project --manifest manifest.json --dry-run
```

The following commands illustrate separate operations. Replace the source
manifest, source ID, artifact alias and master with entries that exist in your
project; this is not a sequence that creates a complete scientific report.
`--force` authorizes replacement of differing managed resources.

```sh
ngr pull --from ngr --from /path/to/book/manifest.json
ngr status --check
ngr doctor
ngr pull --source sha scripts _fig --force
ngr render --manifest manifest.json --dry-run --only report
ngr render _master/book.en.qmd --profile book
ngr deploy --help
```

`pull` handles both incorporation and updates. The first invocation names each
source (`--from` is repeatable); `ngr` names the installed presentation base.
Later invocations use the registered associations, optionally narrowed by
repeatable `--source`. Positional paths are destination files or directory
prefixes. A partial initial incorporation stays partial on later default pulls.
A source is identified by its `id`, not by its location: naming a registered
source again with `--from` re-points it to that manifest and hydrates from
there, reporting the change. When a recorded location no longer exists, the
error names the source; pass `--from` with its current manifest.
Unknown sources/paths fail. `--source` and `--from` cannot be combined.

Missing files are created; identical files are retained. Differing managed files
require `--force`; existing seeds are always preserved. The entire selection is
preflighted before writing, including applied claims from unselected sources.
Different source bytes or ownership at the same destination are incompatible,
even with `--force`. Equal contributions can share a path. Case collisions and
file/directory conflicts fail. No files are removed, and no master is moved.
Extras and scientific data stay in the project. `--dry-run` validates the same
plan without writes; differing managed files still require `--force` to plan
their replacement. Ordinary write failures trigger restoration; crash or
concurrent-writer transactionality is not promised.

`status` compares source, project and per-file receipt; `--check` exits 1 for
drift/missing/retired files. Edited seeds are reported as project-owned.
`doctor` reports the loaded R package and runs the checks explicitly declared
by the registered sources. Source checks are argv arrays executed in the project,
so review a source before running its checks. Neither command updates resources.

## Source manifest

Each book owns a JSON manifest and can map arbitrary folders within its source
tree to shared project folders. Paths are canonical relative paths; symlinks,
parent traversal and resources targeting `.git`, `.ngr`, `oq`, `gmsp` or the
project manifest are rejected.

```json
{
  "schemaVersion": 1,
  "id": "my-book",
  "resources": [
    {"from": "chapters", "to": "_chapters", "ownership": "managed"},
    {"from": "masters", "to": "_master", "ownership": "managed"},
    {"from": "masters/book.qmd", "to": "_master/book.qmd", "ownership": "seed"}
  ],
  "artifacts": [],
  "checks": []
}
```

A file entry may restate one file already covered by a directory entry of the
same source to give it a different ownership; here every master is updated by
`pull` except `book.qmd`, which the project owns after the first incorporation.
Any other repeated destination within a source is rejected.

`artifacts` can seed an empty project artifact list; an existing nonempty list
remains project-owned. Source authors supply the family, paths and optional
publication identities. String values may contain `{project_id}`, which is
replaced by the lowercase alphanumeric form of `params.project_id` from the
project's `params.yml` (`AR-SABP0` becomes `arsabp0`). While that id is missing,
or still equal to the one the source ships in its own `params.yml` seed, no
artifact is seeded and `pull` says so; set the id and pull again. The SHA
scaffold declares its 21 artifacts with `{project_id}-<alias>` site names and
`{project_id}-<alias>.srk.ar` domains. The hosting domain belongs to the
scaffold; NGR itself names none.

Each scaffold declares its resources in its own `manifest.json`. The project's
`manifest.json` records its composition and is read by TOC, transmittal and
render-stamp consumers. These are separate objects in separate directories;
the source manifest is never copied over the project's manifest.
The installed base supplies formatting resources, including `bib/apa.csl`;
the scientific bibliography belongs to the book source. The base does not
claim `bib/references.bib`.
`scaffolds.<id>` records the source manifest
path, enrolled selection, applied source claims, checks and per-file receipts.
Managed receipts retain `commit`, `dirty`, `md5` and add SHA-256; seeds never gain
a receipt for customized local bytes. A source outside Git reports the revision
recorded in a `BUILD_INFO` file beside its manifest, which the CLI installer
writes for the installed base; without that record the revision is `unknown`,
renders are marked DRAFT and content hashes remain exact. Partial updates preserve other file receipts.
Legacy provenance without a source association requires explicit `--from`.

### Moving an existing project to NGR

A project created with the earlier tools keeps its artifacts in
`qrt.manifest.json`, with a `scaffolds` block of receipts written by those
tools. NGR does not read that file name and never writes to it; the two files
stay side by side while the move is verified, and the earlier tools keep
operating the project during that time. On a preserved copy: copy the file to
`manifest.json` (do not rename it), delete the copy's `scaffolds` block, keep
`artifacts` unchanged, then run

```sh
ngr pull --from ngr --from /path/to/sha/manifest.json --force
```

The pull records new receipts for every file, preserves project seeds and
brings the scaffold's `manifest.json` readers with `scripts/`. Verify NGR and
the earlier tools in the same tree; once everything checks out, remove
`qrt.manifest.json` in a later commit of the project. See the
[scaffold guide](https://kanameishi.github.io/NGR/articles/scaffolds.html#existing-psha-projects).

## Render and deploy

Render retains the direct profiles book, html, revealjs and docx, including
composed Word books, nested masters, temporary staging, DOCX correction, custom
manifest outputs and existing static artifacts. Publication retains the
`deploy`, `deploy init`, `deploy domain` and `deploy unbind` forms, direct and
manifest selection, draft/production, site creation, domains, TLS and DNS
diagnostics. `deploy init` registers sites; it does not incorporate resources.
See `ngr render --help` and `ngr deploy --help` for exact arguments.

The single `cli/main.R` interprets the arguments, prints results and sets the
exit status; every operation is an exported function of the installed NGR
package, loaded through normal R library resolution. `--help` needs no
library. The command and the installed NGR package share one version: a
command that needs the library names a missing one instead of failing inside
it, and `ngr --version` reports the package version, the payload and the
recorded build. `pull`, `status` and source checks use `NGR::pullResources()`,
`NGR::compareResources()` and `NGR::checkResources()`. These APIs also work
from R without the CLI. `NGR::quartoRender()` owns staging, YAML composition,
publication provenance, Quarto execution, DOCX repair and output delivery.
The CAN compositor, semantic filters and prepared components are distributed
inside the R package and resolved through `system.file()`. The canonical family kit in `install/`
checks the installed version and the declared exports before replacing the
CLI; an older package must be updated separately.
`NGR::quartoRenderManifest()` owns batch selection, preflight and execution.
Static and legacy map entries represent external products; NGR never runs their
producer scripts. Netlify operations use `netlifyRegister()`, `netlifyDeploy()`,
`netlifyDomain()` and `netlifyUnbind()` from the package, and their manifest
forms `netlifyRegisterManifest()`, `netlifyDeployManifest()` and
`netlifyDomainManifest()`. Publication uploads
existing directories with `--no-build`; dry runs do not contact the provider.
Preflight precedes batch mutations; a later failure can retain earlier completed
effects.

### Identity in the page footer

Books and HTML documents print a page footer with the title and an identity
line. NGR takes that line from `footer-meta` when the master or the project
configuration declares it; otherwise from the project's `params.yml`, joining
`params.author` and `params.consultant.name` with a comma; otherwise the footer
carries the title and the render stamp only. The scaffold declares no logo and
no corporate name: a project that needs them adds them to its own
configuration.

### CAN Word reports

The master supplies `title` and `lang`; English is used when `lang` is absent.
Cover labels follow English or Spanish, including regional language tags.
NGR reads the project's existing `params.yml`: `params.client.name` for the
client, `params.consultant.name` for the consultant and `params.project_id` for
the project code. The title and these values must be non-empty single-line
strings. A missing or invalid project field fails before Quarto with its key
and `params.yml` in the diagnostic.

The cover, inner title page, header and footer use the same automatic `dd/mm/yyyy` render date
as the `Printed` stamp. NGR does not read a master `srk` block or a manual
issue date. No additional project fields are required: document number,
revision, distribution and other Word-specific details remain blank for
editing in Word. Existing project masters and `params.yml` need no migration
for this metadata contract.

The inner title page uses the CAN contact layout. Optional `address` lists and
`web` strings under `params.client` and `params.consultant` fill its contact
columns; absent values remain blank. Its file name is the delivered DOCX name.
The profile enables a Word table of contents. Content before the first Heading1,
such as the index and signatures, uses Roman page numbering; the body starts at 1.
Word may require a manual table-of-contents update. The compositor does not request
automatic field updates when opening the document.

The DOCX profile requires `number-sections: true` and a CAN-compatible
`styles/reference.docx`. Each appendix file listed under the master's `appendices`
needs exactly one numbered level-1 heading with an explicit `{#sec-...}` identifier.
A book without that declaration receives a diagnostic and no CAN appendix dividers.
Part entries are supported. Quarto resolves citations, bibliography and crossrefs
for the entire document once; Python then composes the cover, inner title page and
appendix dividers. A chapter titled “Appendices” is still a chapter: migrate its
content to the explicit master declaration. Existing master seeds are not replaced
by `pull`; review and migrate them separately. Retire any duplicated legacy cover
blocks in the report source, preserving the intended signature page.
Native tables receive CAN styles. Preformatted tables retain widths, grids,
merges and repeated headers. Input bodies with internal section breaks, including
landscape sections, are rejected before replacing an existing output.

Existing projects require an explicit resource migration. Inspect with
`ngr status styles/reference.docx yml/_quarto-docx.yml`; after reviewing local
customizations, update those managed resources with
`ngr pull --source ngr styles/reference.docx yml/_quarto-docx.yml --force`.
The updated profile removes the old `appendix-style.lua` heuristic. Pull does not
delete retired project files; an old unused copy may remain. Render never replaces
project styles. Compatible customized references must retain the required CAN
style roles and `srk.title/company/project/date` header/footer controls.

The canonical reference is generated in `lib/inst/docx/reference.docx`; the scaffold
copy must be identical. See [resource generation](../lib/inst/docx/README.md).

## Focused checks

With an authorized installed candidate and a test destination, run:

```sh
NGR_TEST_BIN=/absolute/prefix/bin/ngr NGR_TEST_ROOT=/absolute/test/root python3 -B -m unittest discover -s cli/tests -v
```

These tests exercise the installed public interface. Remote publication requires
separate explicitly selected destinations; local checks do not certify Netlify
service behavior.
