# Redaction

Ranger can pseudonymise the identifiers in everything it writes, so a package can be shared for support or review without exposing the environment. It is off by default.

```powershell
# During a run
Invoke-AzureLocalRanger -ConfigPath .\ranger.yml -Redact -RedactMapPath .\private\redaction-map.json -RedactTerm acmecorp

# From a saved manifest (the source package is never modified)
Export-AzureLocalRangerReport -ManifestPath .\manifest\audit-manifest.json -Formats html,markdown,docx,xlsx,pdf,svg,drawio,pptx,powerbi,json-evidence -Redact

# Publish a redacted copy of a finished package
Publish-RangerRun -PackagePath .\run-20261015 -ConfigPath .\ranger.yml -Redact
```

The same switch exists as the config keys `output.redact`, `output.redactMapPath` and `output.redactTerms`.

## What is replaced

| Identifier | Replacement | Notes |
| --- | --- | --- |
| IPv4 address | `192.0.2.N`, `198.51.100.N`, `203.0.113.N`, then `100.64.x.y` | Documentation ranges. `0.0.0.0`, `127.x`, `255.x` masks are left alone. APIPA addresses are replaced. |
| IPv6 address | `2001:db8::N` | `::1`, `::` and a bare `fe80::` prefix are left alone. |
| MAC address | `02:00:5E:xx:xx:xx` | Keeps the separator style (`:`, `-`, `.xxxx` or none) and the letter case. |
| Hostname, FQDN, cluster name | `host-NN`, `host-NN.example.test` | Node names, BMC names and the short label of every FQDN. |
| Serial and service tags | `SN-XXXXXXXX` | Any value under a key that says serial, service tag, asset tag, chassis or UUID. |
| Subscription, tenant, object GUIDs | A deterministic GUID | Marked with a `5ec0de` tail so a second pass leaves it alone. |
| Resource group names | `rg-redacted-NN` | Also inside ARM resource IDs (`/resourceGroups/<name>/`). |
| UPN and email | `user-NN@example.test` | The same user gets the same number. |
| Storage account, Key Vault, registry, Arc gateway names | `acct-redacted-NN` plus the service suffix | `*.blob.core.windows.net`, `*.vault.azure.net`, `*.azurecr.io`, `*.gw.arc.azure.com` and similar. |
| Down-level accounts, DNs, certificate subjects | `redacted-NN` | `DOMAIN\user`, `CN=`, `OU=`, `DC=`, `O=`, user profile folders. |
| SAS signatures, passwords, tokens, SNMP communities | `redacted-secret` | The key stays, the value goes. |
| Operator terms | `termNN` | Anything you pass with `-RedactTerm`, even inside longer names such as `csv-acmecorp-vmstore-01`. |

Names that contain a registered cluster, node, resource group or serial name are also replaced when they are embedded in a longer hyphenated name (for example `csv-<cluster>-vmstore-01`).

## How it works

1. The manifest is copied and every string value and key is rewritten. Identifiers are discovered from well-known keys (`node`, `fqdn`, `serialNumber`, `resourceGroup`, `domain`, `userName` ...) and from pattern matches in free text.
2. Every output format is rendered from the redacted copy: HTML, Markdown, JSON, JSON evidence, SVG, draw.io, DOCX, XLSX, PDF, Power BI CSV and PPTX. File and folder names use the redacted values (`ranger-redacted-...`).
3. Text artefacts that were written during the run (log, transcript, drift report, run status) are swept at the end. Raw evidence is not kept in a redacted run.
4. The mapping stays in memory. It is written only when you pass `-RedactMapPath` (or set `output.redactMapPath`); a relative path is placed next to the manifest. **That file reverses the redaction. Keep it out of any package you share or publish.** `Publish-RangerRun -Redact` never uploads it.

Pseudonyms are consistent inside one run or export and are repeatable across runs only for GUIDs and serials when you pass `-RedactSeed`. The same value always maps to the same pseudonym, and applying redaction twice changes nothing.

## What it does not cover

Redaction is best effort and works from the shape of Ranger's own data. Check these before you share a package:

- Guest VM names are pseudonymised where the VM inventory and placement lists carry them (and registered organisation and tenant display name keys), but not where they appear inside free text. VLAN and switch names and other free-form labels are not covered. Add them with `-RedactTerm`.
- Azure resource names that do not contain a registered cluster, node or resource group name (workspaces, data collection rules, custom locations). Add the common prefix with `-RedactTerm`.
- Two-label domain names that are not under a recognised key, and NetBIOS names outside `NetBIOSName` or `domain` keys.
- Event log message text and imported switch or firewall configuration text beyond the patterns above.
- Anything a collector adds in a future release under a key the rules do not know.

The Pester suite asserts that no identifier from the fixture manifests survives in any generated artefact (text, the XML parts of DOCX, XLSX and PPTX, PDF bytes and file names). It cannot know your environment: review a redacted package once before sharing it.
