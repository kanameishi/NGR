# Deploy and site registration

NGR uses the installed Netlify CLI. Real provider operations require its
authentication. Resolve the project root and read its `.netlify/sites.env`
mapping (`alias=UUID`), the selected artifact declarations and intended
publication mode. An alias, local path, provider site name and UUID are
different identities; use the mapping whose use the user explicitly validated
for this task. Its presence or UUID format alone does not validate a destination.

## Upload an existing output

```text
ngr deploy <alias> <directory>
ngr deploy <alias> <directory> --prod
ngr deploy --manifest <file> --only <aliases> --dry-run
ngr deploy --manifest <file> --only <aliases> [--prod]
```

Use the draft or production mode explicitly validated by the user; the CLI
default is draft and `--prod` publishes to production, but neither selects the
user's intent. If mode or destination lacks validation, ask and wait before
preparing a deploy contract or uploading. Once both are authorized,
proceed without repeating approval.

Verify that the selected output is the intended generation and has passed
the requested QA. Upload uses `--no-build`: it does not render, create sites,
write bindings or set domains. If the binding is missing and registration is
part of the request, complete [site registration](#register-or-create-a-site)
using its known site name, then upload.

Direct deploy requires an existing directory and registered alias. It has no
dry-run and imposes no `index.html` check. Manifest deploy requires
`<path>/index.html` for every selected website: a missing required output
fails, while a missing optional one skips before alias validation. Use the
requested website subset when a manifest also contains render-only DOCX;
do not change `required` to conceal a wrong selection.

Manifest dry-run checks local paths, website entry points and UUID-shaped
alias bindings. A fresh project can fail with `Alias not registered` even
in dry-run. Supply the real binding through registration when authorized;
do not invent UUIDs. This plan makes no provider calls and does not prove
authentication or that a recorded site still exists.

Real deploy validates sites, then uploads sequentially. Preserve the site UUID,
deploy identity, mode, response and returned URL for each attempt. The command
writes the response of each completed upload on stdout, also with `--quiet`.
Check the served artifact when claiming publication. On later failure, earlier
uploads remain live: stdout keeps their responses, and the error names the
uploaded and the remaining aliases and exits 1. Reconcile a timeout/unknown response with the exact provider
deploy before retrying, and resume only unfinished aliases.

## Register or create a site

```text
ngr deploy init <alias> <site-name>
ngr deploy init <alias> <site-name> --create [--account <slug>]
ngr deploy init --manifest <file> --only <aliases> --dry-run
ngr deploy init --manifest <file> --only <aliases> [--create] [--account <slug>]
```

Require explicit user validation of the site name (`siteSlug` in a manifest)
and intended account, directly or through an identified contract. Registration
looks up an existing site and writes the local binding. Add `--create` when
creating the missing site is authorized;
it is not needed to associate an existing site. Neither operation uploads
content or configures domains. Direct init has no dry-run.

Manifest init requires every selected `siteSlug` and rejects duplicate site
slugs across the whole manifest. Its dry-run prints the plan without reading
the provider or registry, so it cannot discover an existing alias conflict,
prove site availability or establish authentication.

After init, verify the actual provider UUID and corresponding local mapping.
An alias already pointing to another UUID is refused: reconcile the identities
instead of silently deleting the binding. If exact local replacement is
authorized, [unbind](domains-recovery.md#remove-a-local-binding) is the local
step before registering the intended site.

Creation may succeed before lookup/registry writing fails. A failure after a
completed creation or registration exits 1: stdout keeps one tab-separated line
per completed effect, with the alias and `created` with the site name or
`registered` with the UUID, and the error names those aliases and the ones not
registered. Preserve the known
site name/UUID and reconcile it through ordinary init before attempting any
new creation. A provider lookup error or timeout does not establish absence.
If NGR does not expose the provider observation needed to reconcile the
attempt, report that CLI limitation and preserve the known identity and
unresolved effect. Do not bypass NGR with a direct provider CLI/API call or
retry creation on an assumption of absence.

Continue with [Domains](domains-recovery.md) only when that effect is requested.
