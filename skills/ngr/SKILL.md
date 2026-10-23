---
name: ngr
description: "Operate the installed NGR CLI to incorporate project resources, render Quarto books, documents and presentations, and register or publish their outputs on Netlify. Use for NGR consumer workflows and their manifests, not NGR source maintenance or upstream scientific calculations."
---

# NGR

Use the installed `ngr` command. Resource incorporation, local rendering and
Netlify publication are separate operations; combine them when the user's
request includes their effects. A consumer workflow needs the project and
installed product, not a checkout of NGR or its internal helpers.

## Start from the project

Use the project directory explicitly validated by the user for this task. Run
there. When invocation from another directory is needed, use
`ngr --root <project> ...`; the directory must exist. Relative manifests,
masters, outputs and `.netlify/sites.env` use that root. Masters remain
project-relative. Supply `--root` once, before any `--` separator.

Read the indicated contract for the requested operation, then use the relevant
reference. Any value or decision assumed or inferred by the agent is invented
and invalid until explicitly validated by the user. The user may validate a
value or an identified contract/source for this task; preserve validation
already given. File existence, valid schema, recorded provenance, defaults,
examples or another agent's choices do not provide that validation.
Approval of a file does not validate absent choices; "usual settings" or
"do it quickly" does not supply them.

Require it for source/selection, master/profile, aliases, output paths,
replacement policy and publication site/account/mode/domain before writing an
executable manifest or running the dependent operation. Ask for any missing
choice and wait; indicated sources may be inspected and a non-executable
proposal prepared meanwhile. Rendered products and other results computed
with validated inputs and methods are outputs, not permission to fill missing
inputs. Prepare or correct a manifest only with those inputs validated and
within the requested scope, preserving receipts and scientific data.

| Task | Instructions |
| --- | --- |
| Incorporate, update or restore resources; compare drift; run declared checks | [Resources](references/resources-manifest.md#resources) |
| Prepare or select artifact declarations | [Artifact manifests](references/resources-manifest.md#artifact-manifests) |
| Render a master or selected artifacts and verify the result | [Render](references/render.md) |
| Register/create a site or upload existing output | [Deploy](references/deploy.md) |
| Configure domains/HTTPS or remove a local site binding | [Domains and recovery](references/domains-recovery.md) |

For a render that must survive disconnection, or an attempt being resumed,
also read [Long jobs](references/long-jobs.md).

`ngr --version` identifies the installed interface; the command shares the
version of the NGR package. Use these instructions directly for
the documented operations. If a command is unavailable or contradicts this
contract, inspect `ngr --version` and that operation's `--help` to resolve the
specific mismatch. Missing software is a prerequisite to report, not a reason
to install or switch to source execution implicitly.

For a request for commands only, read [Recipe evidence](references/recipe-evidence.md)
and provide the commands in the selected project context without executing
renders or publication. Describe supporting evidence
at its actual level: help/parser support establishes syntax; a dry-run establishes
a plan; a prior real run establishes only its recorded operation, version,
inputs and result. Reuse relevant evidence without rerunning expensive work.
An available flag or old output does not create a reason to add an option,
change the selected aliases/language or regenerate scientific products.

## Complete the requested operation

Execute the resolved scope and check its actual result: copied resources,
final rendered artifact, local site binding or remote deploy. Keep the command,
project root, selection, exit status and output/site identity sufficient to
distinguish this attempt. A dry-run or an intermediate `Output created` line
does not establish completion.

If a batch fails, preserve its successful prefix and distinguish failed,
unattempted and unknown entries. Resume only the unfinished authorized scope
after resolving the cause. Rendering consumes the project's data; it does not
generate missing scientific results. Publication uploads existing output;
render success alone does not authorize it.
