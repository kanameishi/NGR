# Domains and local bindings

## Bind a domain

Resolve the project, exact alias/UUID in `.netlify/sites.env`, requested
hostname and HTTPS intent. Registration and upload do not configure a domain.

```text
ngr deploy domain <alias> <hostname> --dry-run
ngr deploy domain <alias> <hostname> [--https]
ngr deploy domain --manifest <file> --only <aliases> [--https] --dry-run
ngr deploy domain --manifest <file> --only <aliases> [--https]
```

Use a hostname without a URL scheme or path. Manifest mode takes `domain`
from the declarations; every selected entry needs one, and duplicates across
the whole manifest fail. Require the user's explicit validation of the hostname
and HTTPS intent, directly or through that manifest; ask and wait when absent
instead of inventing a domain from the alias.

Dry-run requires local bindings but does not check the provider's current
domain or DNS. Real execution checks existing-domain conflicts before changing
sites. Direct mode also offers `--rebind`, which clears the current domain
before rebinding; use it for an authorized replacement/recovery, not as a
routine retry. Manifest mode has no `--rebind`.

`--https` can enable forced HTTPS and provision TLS. NGR diagnoses DNS but
does not create DNS records. Success can carry warnings about missing `dig`,
unmanaged DNS or unreadable/unready nameservers. Preserve those observations:
they identify work still needed before an end-to-end serving claim.

Verify according to the requested result:

| Result | Evidence |
| --- | --- |
| Domain binding | Provider associates the hostname with the intended site UUID. |
| DNS serving | Authoritative records resolve the requested hostname as intended. |
| HTTPS | That hostname serves HTTPS with a valid certificate. |
| Published content | The intended current artifact is served at that URL. |

A task limited to binding can close with that observed effect and state which
serving layers remain unverified. A later batch failure does not revert earlier
bindings. A failure after a completed effect exits 1 with one tab-separated
line per completed effect on stdout: the alias, then `cleared` with the site
UUID, `bound` with the domain or `https` with the domain; the error names those
aliases and the ones not configured. Reconcile changed/unknown sites and resume
the unfinished scope.

## Remove a local binding

```text
ngr deploy unbind <alias>
```

Read the current mapping and remove the requested alias. Verify that it is
absent and other entries remain intact. Unbind only edits `.netlify/sites.env`;
it does not delete a remote site, clear its domain or upload content. If the
request includes rebinding, continue with the resolved destination using
[site registration](deploy.md#register-or-create-a-site).
