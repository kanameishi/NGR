# Resources and artifact manifests

## Resources

Read the project's `manifest.json` and the source declaration involved. The
project file records `scaffolds` associations/receipts and an `artifacts` array;
let `pull` maintain the resource records. A source file declares its own `id`
and resources. Both can be called `manifest.json`; they are different objects.

To incorporate the installed base and an already identified source:

```text
ngr pull --from ngr --from <source-manifest.json> --dry-run
ngr pull --from ngr --from <source-manifest.json>
ngr status --check
```

Include only the sources needed by the task. `--from ngr` supplies `yml/`,
`styles/`, `lua/` and `bib/apa.csl`; it does not supply a scientific master or
data. If a render lacks those base resources, a scoped base pull can prepare
them when the user's explicit validation covers that source and selection.
Missing resources do not authorize choosing a source. A scientific scaffold
likewise requires validation of its identified source before pull.

Subsequent operations reuse registered locations and selections:

```text
ngr pull --source <id> [destination-paths...]
ngr pull --source <id> --force <destination-path>
ngr status --source <id> --check [destination-paths...]
ngr status --from <source-manifest.json> [destination-paths...]
```

`--source` and `--from` can repeat. Positional paths select destination files
or subtrees. Without paths, `--from` selects the whole source; an ordinary pull
uses its enrolled selection. `status --from` compares without changing the
association. To repair a moved source, use `pull --from <new-manifest>` only
after confirming its `id`; the same id repoints its recorded location.

| Observation | Action |
| --- | --- |
| Managed files differ | Compare source and local edits; use `--force` on the exact paths when replacing those edits is within the task. Ordinary pull refuses differing managed files. |
| Customized seed | Preserve it. `project-seed` is expected, and `--force` never replaces an existing seed. |
| Two sources claim incompatible content at one destination | Resolve which source/content the project should use; force cannot arbitrate this conflict. |
| Source file retired or extra local file present | Pull does not delete it. Do not turn an update into a cleanup. |

`status` reports `equal`, `different`, `missing`, `retired` or `project-seed`,
and may append `locally-modified` for a change against its receipt. With
`--check`, drift exits 1; customized seeds alone do not count as drift. Check
the report as well as the exit status. After pull, verify the selected files
and that project-specific seeds/extra files remain intact. Ordinary write
failures have rollback handling; interruption or concurrent writers are not
covered by that guarantee.

### Declaring a source

When preparing a source declaration is requested, use inputs, destinations and
ownership explicitly validated by the user. Existing files alone do not settle
those choices. This example supplies styles as managed resources
and an editable report as a seed:

```json
{
  "schemaVersion": 1,
  "id": "reports",
  "resources": [
    {"from": "styles", "to": "styles", "ownership": "managed"},
    {"from": "report.qmd", "to": "report.qmd", "ownership": "seed"}
  ]
}
```

`from` is relative to the source manifest; `to` is relative to the project.
Use confined relative paths without `..` or symlinks. Resources cannot supply
project-owned scientific data or producer input/output roots. A source may
also declare artifact seeds: pull fills an empty project `artifacts` array,
preserving an existing nonempty one. If a seed uses `{project_id}`, resolve
the real `params.project_id` from the user-validated project contract; a missing
or template value leaves artifact seeding pending. Inspect the declarations before
rendering or publishing.

### Check

```text
ngr check --source <id>
```

Check validates source claims and runs its recorded `checks` in the project
directory. Read those checks before execution: each is an argv array, such as
`["Rscript", "scripts/check.R"]`, and can write files or run calculations.
Use check when those checks serve the requested task; it is not mandatory
before every render. A failure names the check/source to diagnose and may
reflect missing project inputs.

## Artifact manifests

Use the existing artifact manifest when the user has explicitly validated it
for this task. When creating one, use only validated masters, profiles, aliases
and output choices, using schema version 2; ask and wait before filling any
missing choice. Keep valid V1 contracts unless migration is requested. NGR does not read
`qrt.manifest.json`; if it is the only old declaration, translate its intended
products into the current schema only after the user validates that source and
its intended products for the migration; preserve it while checking the result.

Example: render `report.qmd` to a deliberately named HTML directory and also
produce its Word version. These aliases and paths are examples, not defaults.

```json
{
  "schemaVersion": 2,
  "artifacts": [
    {
      "alias": "report-web", "kind": "quarto",
      "renderSource": "report.qmd", "profile": "html",
      "path": "html/custom-gallery", "required": true,
      "siteSlug": null, "domain": null
    },
    {
      "alias": "report-word", "kind": "quarto",
      "renderSource": "report.qmd", "profile": "docx",
      "path": "docx", "required": true
    }
  ]
}
```

Preserve `scaffolds` and other existing project fields when editing its
`artifacts`; do not replace a populated project manifest with this example.

| Field | Contract |
| --- | --- |
| `alias` | Unique nonempty selection identity; also selects a deploy registry entry. |
| `kind` | V2: `quarto`, `static` or `map`. |
| `renderSource`, `profile` | Quarto: source path and `book`, `html`, `revealjs` or `docx`. Static: both null. Map: nonempty producer path and null profile; NGR never runs that producer. |
| `path` | Quarto HTML: `html/<name>`, one directory below `html`, with name other than `.` or `..`. It **does choose the actual destination**, independently of the master stem. DOCX: exactly `docx`, producing `<master-stem>.docx` there. External entries name their existing output directory. |
| `required` | Boolean controlling the final missing-output check, not whether a selected Quarto source must exist. |
| `siteSlug`, `domain` | Omitted/null until needed, otherwise nonempty strings. Site registration requires the selected entries' site names; domain operations require their hostnames. Neither is derived from the alias. |

Both versions require a nonempty `artifacts` array. V1 represents static
entries with null source/profile and Quarto entries with a source/profile
pair; it has no separate map behavior.

### Selection and planning

```text
ngr render --manifest manifest.json --only report-web,report-word --dry-run
ngr render --manifest manifest.json --only report-web,report-word
```

`--only` and `--except` accept comma-separated aliases; no selector means all.
Unknown aliases and empty selections fail. Execution follows the manifest's
array order, even if `--only` lists another order. Establish dependencies from
the included content; NGR does not schedule a dependency graph.

Render checks output claims across the whole manifest, including unselected
entries, and compares them case-insensitively. HTML entries can avoid an
otherwise shared destination by declaring distinct `html/<name>` paths.
DOCX claims include the source stem: two different stems can share `docx`,
but equal stems collide. A subset cannot hide an existing collision.

Use the final destinations and the limits of the plan described in
[Render](render.md). Keep requiredness, aliases and publication selections
faithful to the task instead of changing them to bypass an error.
