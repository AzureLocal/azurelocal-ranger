# Changelog

All notable changes to Azure Local Ranger will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Pre-release versions start at `0.5.0`. The first stable PSGallery release will be `1.0.0` once live-estate validation is complete.

## 1.0.0 (2026-04-18)


### Features

* add gMSA detection, secret rotation state, Azure Hybrid Benefit, and physical core billing count ([d8466f9](https://github.com/AzureLocal/azurelocal-ranger/commit/d8466f9669cb755743bf08b0646c5ded90266ce6))
* close issues [#36](https://github.com/AzureLocal/azurelocal-ranger/issues/36) [#37](https://github.com/AzureLocal/azurelocal-ranger/issues/37) [#38](https://github.com/AzureLocal/azurelocal-ranger/issues/38) — network device config import, docs audit, as-built templates ([7832892](https://github.com/AzureLocal/azurelocal-ranger/commit/783289209f255c1fe59c8f03fb170721f89b2dcd))
* close out v1.1.0 milestone work ([cd144ea](https://github.com/AzureLocal/azurelocal-ranger/commit/cd144eac2c5dc4ab4b4a5960403fe8d8d7e818b4))
* close v1.1.0 validation and docs sync ([2ab9c02](https://github.com/AzureLocal/azurelocal-ranger/commit/2ab9c0214ed3bac8ed68b844a84107e0cdc13474))
* deepen all 6 collectors, add docs roadmap, fix Tier 4 scope boundary, update fixtures ([16b7a1c](https://github.com/AzureLocal/azurelocal-ranger/commit/16b7a1c59511db37c0592d2507c958d11546d0ac))
* implement all 22 product direction gap issues ([#53](https://github.com/AzureLocal/azurelocal-ranger/issues/53)-74) ([05ec947](https://github.com/AzureLocal/azurelocal-ranger/commit/05ec947c6db027764d7bffdd4f68083b6891a1e9))
* **maproom:** add committed sample output for both modes + update synthetic fixtures ([cc1c70d](https://github.com/AzureLocal/azurelocal-ranger/commit/cc1c70d3bd32aaf39c84b2f03f3e30b44d1af76e))
* **maproom:** consume platform AzureLocal.Maproom in CI validation ([2ef0877](https://github.com/AzureLocal/azurelocal-ranger/commit/2ef0877496227581f23af082d1a53d98e785b444))
* **prereqs:** add RSAT AD check and -InstallPrerequisites switch ([76b36c5](https://github.com/AzureLocal/azurelocal-ranger/commit/76b36c55f8c21c2e9d2f7f8cb4e9bea108ca0e9a)), closes [#78](https://github.com/AzureLocal/azurelocal-ranger/issues/78)
* **testing:** add Operation TRAILHEAD field-testing cycle framework ([6a87263](https://github.com/AzureLocal/azurelocal-ranger/commit/6a87263c8ef4b4a6b414aecb7798286014023392))
* **testing:** add TRAILHEAD run logging system ([166d813](https://github.com/AzureLocal/azurelocal-ranger/commit/166d813d28743f0633d6fa5309c2e09cb3010858))
* update diagram catalog docs with full audience/trigger reference table ([93780df](https://github.com/AzureLocal/azurelocal-ranger/commit/93780df482116f8b534b9d8246a7da7a3d43b56c))
* **v1.2.0:** Arc Run Command transport, disconnected discovery, Spectre TUI, wizard ([8f05c26](https://github.com/AzureLocal/azurelocal-ranger/commit/8f05c26d69917e4aac10291427f7a416c0c5e5f7))
* **v1.3.0:** operator docs overhaul + full config parameter coverage ([#171](https://github.com/AzureLocal/azurelocal-ranger/issues/171), [#174](https://github.com/AzureLocal/azurelocal-ranger/issues/174)-[#179](https://github.com/AzureLocal/azurelocal-ranger/issues/179)) ([ece18b3](https://github.com/AzureLocal/azurelocal-ranger/commit/ece18b3d14e30427b9503d8d048c38bbc63babf5))
* v1.4.0 — Report Quality milestone ([#168](https://github.com/AzureLocal/azurelocal-ranger/issues/168), [#140](https://github.com/AzureLocal/azurelocal-ranger/issues/140), [#96](https://github.com/AzureLocal/azurelocal-ranger/issues/96), [#94](https://github.com/AzureLocal/azurelocal-ranger/issues/94)) ([e3a0892](https://github.com/AzureLocal/azurelocal-ranger/commit/e3a08929669d5893f13362723b924c4365f6aeab))
* v1.5.0 — Document Quality milestone ([#192](https://github.com/AzureLocal/azurelocal-ranger/issues/192), [#193](https://github.com/AzureLocal/azurelocal-ranger/issues/193), [#194](https://github.com/AzureLocal/azurelocal-ranger/issues/194), [#195](https://github.com/AzureLocal/azurelocal-ranger/issues/195), [#198](https://github.com/AzureLocal/azurelocal-ranger/issues/198)) ([75bc69e](https://github.com/AzureLocal/azurelocal-ranger/commit/75bc69eb809ae19193f65131aaad70932e2aad51))
* v1.6.0 batch 1 — auto-discovery + pre-run audit + wizard wrap ([#196](https://github.com/AzureLocal/azurelocal-ranger/issues/196), [#197](https://github.com/AzureLocal/azurelocal-ranger/issues/197), [#202](https://github.com/AzureLocal/azurelocal-ranger/issues/202), [#211](https://github.com/AzureLocal/azurelocal-ranger/issues/211), [#212](https://github.com/AzureLocal/azurelocal-ranger/issues/212)) ([bb79b89](https://github.com/AzureLocal/azurelocal-ranger/commit/bb79b89c8f86d8511f23f35fe7e79dee21035f20))
* v1.6.0 batch 2 — connectivity fallbacks ([#203](https://github.com/AzureLocal/azurelocal-ranger/issues/203), [#204](https://github.com/AzureLocal/azurelocal-ranger/issues/204)) ([a9313df](https://github.com/AzureLocal/azurelocal-ranger/commit/a9313dfed26149c34aa3a3def20168cb29c15c0d))
* v1.6.0 batch 3 — progress IPC, graduated WAF scoring, graceful degradation ([#213](https://github.com/AzureLocal/azurelocal-ranger/issues/213), [#214](https://github.com/AzureLocal/azurelocal-ranger/issues/214), [#206](https://github.com/AzureLocal/azurelocal-ranger/issues/206)) ([9de94d8](https://github.com/AzureLocal/azurelocal-ranger/commit/9de94d890349d5a6341d7a3d6433c7c9e13df7b1))
* v1.6.0 batch 4 — auth chain, AzContext handoff, Resource Graph ([#200](https://github.com/AzureLocal/azurelocal-ranger/issues/200), [#201](https://github.com/AzureLocal/azurelocal-ranger/issues/201), [#205](https://github.com/AzureLocal/azurelocal-ranger/issues/205)) ([9b176f3](https://github.com/AzureLocal/azurelocal-ranger/commit/9b176f33606b7a3b966001fb636c437e4a85f402))
* v1.6.0 batch 5 — output formats ([#207](https://github.com/AzureLocal/azurelocal-ranger/issues/207), [#208](https://github.com/AzureLocal/azurelocal-ranger/issues/208), [#209](https://github.com/AzureLocal/azurelocal-ranger/issues/209), [#210](https://github.com/AzureLocal/azurelocal-ranger/issues/210)) ([f28cac6](https://github.com/AzureLocal/azurelocal-ranger/commit/f28cac60bb1274e0a7c3a50d2d37a11f6b0835e9))
* **v2.0.0:** extended collectors, AHB cost analysis, weighted WAF scoring ([eb35c1e](https://github.com/AzureLocal/azurelocal-ranger/commit/eb35c1e3277011c9173fbf413b909f24a69389c4))
* **v2.1.0:** preflight hardening — ARM surfaces, deep CIM, Advisor ([240aa9e](https://github.com/AzureLocal/azurelocal-ranger/commit/240aa9e97ba5582f6fc547ffc6968bdcf28f3c59))
* **v2.2.0:** WAF Compliance Guidance — structured remediation, roadmap, gap-to-goal ([aa8cd72](https://github.com/AzureLocal/azurelocal-ranger/commit/aa8cd72b0f8277b4b4b98435422024183e396949))
* **v2.3.0:** Cloud Publishing ([cf5af0c](https://github.com/AzureLocal/azurelocal-ranger/commit/cf5af0c32c7a1baaf88ef21e0dd2fd55d1577371))
* **v2.5.0:** Extended Platform Coverage ([2a906e0](https://github.com/AzureLocal/azurelocal-ranger/commit/2a906e099756defc44f401423438f03737f14b14))
* **v2.6.3:** First-Run UX — 2-field invocation, node auto-discovery, wizard overhaul ([5624cec](https://github.com/AzureLocal/azurelocal-ranger/commit/5624cec2c4c43a524c4331c38f2fb9222b6cffa5))
* WinRM preflight fast-fail before collection ([#139](https://github.com/AzureLocal/azurelocal-ranger/issues/139)) ([16fdf48](https://github.com/AzureLocal/azurelocal-ranger/commit/16fdf4813c7475fbdb77909e5d4040a7aa9c9257))


### Bug Fixes

* **#303:** guard Get-Service with \$IsWindows — Linux runner compatibility ([1fe7b82](https://github.com/AzureLocal/azurelocal-ranger/commit/1fe7b822ffabee68a8b66118c1dd7ac832051eb0))
* **#306:** resolve short names to FQDNs inside Resolve-RangerNodeInventory ([a262dbe](https://github.com/AzureLocal/azurelocal-ranger/commit/a262dbed01e2a305f5c5953b607bd55f1573066f))
* **#314:** add -NetworkDeviceConfigs parameter to Invoke-AzureLocalRanger ([792fff6](https://github.com/AzureLocal/azurelocal-ranger/commit/792fff680bc03c220ba7319abd2afbd3179c2cfe))
* **#330:** return runResult to pipeline after Write-Host summary ([6971a53](https://github.com/AzureLocal/azurelocal-ranger/commit/6971a53cbc0a0991b9a9a7395050dad80f425fed))
* add reopened trigger to add-to-project workflow ([fe54f6d](https://github.com/AzureLocal/azurelocal-ranger/commit/fe54f6dc6fb7036c6f41a33b2e35a99ae22a279c))
* allow prerequisite checks without config ([fa6816d](https://github.com/AzureLocal/azurelocal-ranger/commit/fa6816da21c1f4622a97f865895d3c0cae3ae609))
* broken HTML/MD/DOCX tables + missing node data + add DOCX samples ([55dc471](https://github.com/AzureLocal/azurelocal-ranger/commit/55dc471e6e028a240890aba89e7032b805be7dca))
* **ci:** add permissions to release-please caller workflow; add missing status doc ([a32e7df](https://github.com/AzureLocal/azurelocal-ranger/commit/a32e7dfec56d4341284fca7d6326866b5511c1bf))
* **ci:** fix connectivity matrix skipping collectors with placeholder config ([43c1f0b](https://github.com/AzureLocal/azurelocal-ranger/commit/43c1f0bafd07c149134108975fea7631186aeac8))
* **ci:** remove release trigger from deploy-docs — blocked by Pages env protection ([7edbcf8](https://github.com/AzureLocal/azurelocal-ranger/commit/7edbcf83c3c8b44e015ba4b5f5a42bfb0a6eba75))
* **ci:** resolve 3 blocking CI failures in v1.2.0 code ([de31007](https://github.com/AzureLocal/azurelocal-ranger/commit/de31007c5f339a8cbd7e4a66bde31ca6da879ade))
* **ci:** serialise pages deployments — push and release events raced on concurrency group ([a600da7](https://github.com/AzureLocal/azurelocal-ranger/commit/a600da745b44cd4ec0ae7c5c92cce0313b4344f3))
* **ci:** stage module in AzureLocalRanger-named dir for Publish-Module ([3bfcb19](https://github.com/AzureLocal/azurelocal-ranger/commit/3bfcb19d52291abb66cfdec021fcc4bd2ad4055d))
* **ci:** update add-to-project solution option ID ([d7715e5](https://github.com/AzureLocal/azurelocal-ranger/commit/d7715e56968e112c3c5ebc92e0ab37857f542a9f))
* **ci:** use GITHUB_WORKSPACE for Publish-Module path ([a1fd194](https://github.com/AzureLocal/azurelocal-ranger/commit/a1fd19457196f0590a409bb3b671942c879deb97))
* **collector:** fix four P3 runtime bugs found during TRAILHEAD field test ([ed2e1e7](https://github.com/AzureLocal/azurelocal-ranger/commit/ed2e1e752d2d0db532c4f9c281e204be955ad5e3)), closes [#85](https://github.com/AzureLocal/azurelocal-ranger/issues/85) [#93](https://github.com/AzureLocal/azurelocal-ranger/issues/93)
* **collector:** use hashtable bracket access for hostNode in VM summary ([bac5099](https://github.com/AzureLocal/azurelocal-ranger/commit/bac50997810878676ca1a062b0f495c21e940c16))
* **config:** change default rootPath to fixed absolute path C:\AzureLocalRanger ([b861261](https://github.com/AzureLocal/azurelocal-ranger/commit/b861261eb22d66e258f1bc548faffee2bde498de))
* **diagrams:** guard empty names in Get-RangerSafeName and SVG layout; fix(config): null cluster target check; ops(trailhead): P7 log, CHANGELOG, cleanup old run logs ([4884840](https://github.com/AzureLocal/azurelocal-ranger/commit/48848404c111da5cb4a3b1032b6d3a57e2134b9f))
* **docs:** add Next Release v1.4.0 section to roadmap ([6877ccc](https://github.com/AzureLocal/azurelocal-ranger/commit/6877cccea5f811fdc691d168bbba637e2fabed2e))
* **docs:** move Next Release v1.4.0 to top of roadmap, remove duplicate section ([14fc16d](https://github.com/AzureLocal/azurelocal-ranger/commit/14fc16d684560f19109271b56e03da299c1dcb38))
* **docs:** remove out-of-docs link to PR template — breaks mkdocs strict build ([800d74f](https://github.com/AzureLocal/azurelocal-ranger/commit/800d74f4b7b721bbb01b5324c56d6d77b375d1c0))
* **docs:** rename milestone v1.5.0 → v1.4.0 in versioning table ([51f04fc](https://github.com/AzureLocal/azurelocal-ranger/commit/51f04fc86a377a5b64a5954f8a6c718a3c036dbf))
* **docs:** restructure roadmap — replace flat backlog with v2.0.0 and v3.0.0 milestone sections ([745955d](https://github.com/AzureLocal/azurelocal-ranger/commit/745955dd77e20580b03deed7b31b8a683dd061b2))
* **docs:** update version references to v1.3.0 across index, status, and roadmap ([7d12993](https://github.com/AzureLocal/azurelocal-ranger/commit/7d129939299430925678a236c269b7b85c68e129))
* **export:** add -AsHashtable to ConvertFrom-Json in Export-AzureLocalRangerReport ([89f2758](https://github.com/AzureLocal/azurelocal-ranger/commit/89f2758e33245db1e4aeabd11b70fa7dc1dda9c3))
* expose Overall/OverallStatus on Test-AzureLocalRangerPrerequisites return ([#258](https://github.com/AzureLocal/azurelocal-ranger/issues/258)) ([ada07b3](https://github.com/AzureLocal/azurelocal-ranger/commit/ada07b3f6e3ff1391ee62af9f32c058015aa3cc3))
* install yaml dependency in module ci ([d2f24a2](https://github.com/AzureLocal/azurelocal-ranger/commit/d2f24a273d0af003ed24c592fe8174bcccf7634e))
* **preflight:** eliminate retry waste, redundant probes, and transcript flood on credential resolution ([42ca701](https://github.com/AzureLocal/azurelocal-ranger/commit/42ca701335d4f7211f87118aa8fe80d64ca5fbbf))
* **prereqs:** detect Install-WindowsFeature availability instead of ProductType ([9ea6893](https://github.com/AzureLocal/azurelocal-ranger/commit/9ea68933b888df1436f308d4ad07d81b1eeed205))
* **psd1:** trim ReleaseNotes to unblock PSGallery publish ([8c97d6c](https://github.com/AzureLocal/azurelocal-ranger/commit/8c97d6cb049883fd541c1b3ceffe2a8e2830c4ff))
* release AzureLocalRanger 1.1.1 ([c1dbbbc](https://github.com/AzureLocal/azurelocal-ranger/commit/c1dbbbc3fb932c95bc7ee88acf8e0930c1323205))
* reopen [#26](https://github.com/AzureLocal/azurelocal-ranger/issues/26)-28 [#31](https://github.com/AzureLocal/azurelocal-ranger/issues/31) as open implementation issues; remove 'deferred/future' framing from roadmap backlog ([dd7735f](https://github.com/AzureLocal/azurelocal-ranger/commit/dd7735f5e6a8783ebf60dec86ef19d25d2b3c467))
* replace broken relative link with GitHub URL in versioning.md ([f525a4c](https://github.com/AzureLocal/azurelocal-ranger/commit/f525a4c81adf928d6197d89f49a63facac887fbf))
* resolve 7 bugs found during v1.0.0 release readiness testing ([306addb](https://github.com/AzureLocal/azurelocal-ranger/commit/306addbad206c00aff28138e9e6c551044397111))
* resolve all v1.1.2 regression bugs ([#160](https://github.com/AzureLocal/azurelocal-ranger/issues/160)-[#165](https://github.com/AzureLocal/azurelocal-ranger/issues/165)) ([38a1290](https://github.com/AzureLocal/azurelocal-ranger/commit/38a1290dc057b71426ec1484f658e301c61fd71b))
* restore ci and docs workflow validation ([72a4927](https://github.com/AzureLocal/azurelocal-ranger/commit/72a49270f02859a0d37de331302ec4d31b21d6ef))
* skip psgallery publish when version already exists ([e16b3aa](https://github.com/AzureLocal/azurelocal-ranger/commit/e16b3aa9d9f26e8435b588dc4d39702c6df7a864))
* stage module-only payload for psgallery publish ([9e78f42](https://github.com/AzureLocal/azurelocal-ranger/commit/9e78f424d3d246a30ad2b5e85dadd4ac173200be))
* **storage-networking:** derive per-pool resiliencySettingName from child virtual disks ([867fabc](https://github.com/AzureLocal/azurelocal-ranger/commit/867fabc52dce2038d8ab06f96d33baf8d7881309)), closes [#152](https://github.com/AzureLocal/azurelocal-ranger/issues/152)
* **tests:** fix 3 Pester failures blocking PSGallery publish ([b3ac2d1](https://github.com/AzureLocal/azurelocal-ranger/commit/b3ac2d10310fa0246c05ccdd535cfc8a21464842))
* **tests:** guard eventLogAnalysis null entries; install powershell-yaml on CI runner ([01ae2c7](https://github.com/AzureLocal/azurelocal-ranger/commit/01ae2c76e27c9e3d6a4a58603c3af75c7149c9c5))
* **tests:** skip WinRM cmdlet tests on Linux/macOS CI runners ([69b3361](https://github.com/AzureLocal/azurelocal-ranger/commit/69b33617c29bfee993fd4e57cbd581dc241d5af3))
* **tests:** update credential ordering tests and fix Test-NetConnection on Linux CI ([ec12cab](https://github.com/AzureLocal/azurelocal-ranger/commit/ec12cab2c82bd8a89736c972eaafc1f0854ff2b9))
* **tests:** v2.0.0 Pester uses [System.IO.Path]::GetTempPath() for CI ([d1c851e](https://github.com/AzureLocal/azurelocal-ranger/commit/d1c851e0b8c2e5b0a914a6c33fc2337c7bc8088a))
* **tests:** wrap Where-Object results in @() before .Count in Simulation.Tests.ps1 ([cb04314](https://github.com/AzureLocal/azurelocal-ranger/commit/cb04314deaafb87155df979692f6b1a80ee805f5))
* v1.2.1 — progress default, prereq output, Redfish retry, hardware partial ([d2368bf](https://github.com/AzureLocal/azurelocal-ranger/commit/d2368bf8bbdd64fb79f3af46ce5abd2846c259b7))
* v1.4.1 — Invoke-RangerWizard interactive gate ([#180](https://github.com/AzureLocal/azurelocal-ranger/issues/180)) ([d7d98cd](https://github.com/AzureLocal/azurelocal-ranger/commit/d7d98cd87b5e993020f0abf51282e4330a223917))
* **v2.6.1:** fix topology-cluster 0-node failure, licenseProfile 404 noise, Search-AzGraph type error ([5a979dd](https://github.com/AzureLocal/azurelocal-ranger/commit/5a979dd3cce97c197c3b6422f64ce629d988d3f4))
* **v2.6.2:** add pptx/json-evidence to validator whitelist, fix YAML config indentation ([14fa4d7](https://github.com/AzureLocal/azurelocal-ranger/commit/14fa4d719bae50f99c4c0b2334a315e89c25e2c0))
* **v2.6.4:** default config scaffold placeholders break bare Invoke-AzureLocalRanger ([#300](https://github.com/AzureLocal/azurelocal-ranger/issues/300)) ([96de4fb](https://github.com/AzureLocal/azurelocal-ranger/commit/96de4fbb54a729be54ebe5b85eb4f910656f2892))
* **v2.6.5:** BMC interactive prompt ([#312](https://github.com/AzureLocal/azurelocal-ranger/issues/312)) and LLDP passive reporting ([#313](https://github.com/AzureLocal/azurelocal-ranger/issues/313)) ([793cff1](https://github.com/AzureLocal/azurelocal-ranger/commit/793cff16de8d8bddcf3abb3972c495d8f3977e17))
* **v2.6.5:** resolve 0x8009030e, credential UX, cluster selection, azure-first phase ([9617286](https://github.com/AzureLocal/azurelocal-ranger/commit/961728618689439c7f8301fd7c790f8cae0c14dd))
* **wizard:** detect interactive host by name on Windows multi-session (AVD) ([8db4bd8](https://github.com/AzureLocal/azurelocal-ranger/commit/8db4bd8ea5cb5ebdd728673ef4a4a9cf62735ad9))

## [Unreleased]

## [2.6.5] — Credential UX & Discovery Hardening (in progress)

19 first-run friction and reliability issues, all found during live tplabs validation.

### Fixed

- **Credential prompt clarity (#302)** — `Get-Credential` prompts name the target system and expected account format.
- **WinRM silent-start (#303)** — `Invoke-RangerEnsureWinRmRunning` starts the WinRM service at run start.
- **Cluster / domain credential reuse (#304)** — domain credential reuses cluster credential when unconfigured.
- **Node FQDN resolver (#306)** — 4-step FQDN chain: pass-through → Arc map → cluster suffix → DNS.
- **Arc node FQDN extraction (#308)** — `properties.dnsFqdn` from Arc machines fed into `nodeFqdns` map.
- **Cluster selection UX (#309)** — auto-selection prints chosen cluster; numbered menu for multi-cluster subscriptions.
- **Azure-first discovery phase (#310)** — Azure discovery completes before any on-prem WinRM session opens.
- **Node inventory FQDN overwrite fix (#311)** — `Resolve-RangerNodeInventory` no longer overwrites Arc-discovered FQDNs.
- **BMC interactive prompt (#312)** — iDRAC collection prompts added before credential phase when no endpoints are configured.
- **LLDP passive reporting (#313)** — `Get-NetLldpNeighbor` replaces broken MSNdis WMI class; WMI retained as fallback.
- **`-NetworkDeviceConfigs` parameter (#314)** — exposed as direct CLI parameter on `Invoke-AzureLocalRanger`.
- **`-NetworkDeviceConfigs` directory expansion (#315)** — directory paths recursively expanded to `.txt`/`.cfg`/`.conf`/`.log` files.
- **Hardware collector auto-deselect (#316)** — hardware collector excluded from scope when no BMC endpoints are configured.
- **`tenantId` auto-fill (#317)** — filled from `(Get-AzContext).Tenant.Id` after cluster auto-discovery.
- **Log bootstrapping gap (#318)** — bootstrap-phase entries buffered and flushed to `ranger.log` with level filtering.
- **Interactive run-mode prompt (#319)** — prompts for `current-state` / `as-built` when `-OutputMode` is not set.
- **`-Debug`/`-Verbose` log file verbosity (#320)** — correctly elevates `$script:RangerLogLevel` to debug before run.
- **`-Debug`/`-Verbose` terminal output (#328)** — `Write-RangerLog` forces local `$VerbosePreference = 'Continue'` via module-scope flag; both terminal and log file receive debug entries.
- **BMC credential ordering (#326)** — BMC credential prompted immediately after IP entry, before WinRM credentials.
- **BMC interactive prompt stores plain strings (#324)** — IPs now stored as `{ host, node }` objects; hardware collector can read `.host`.
- **`-NetworkDeviceConfigs` paths stored as plain strings (#325)** — paths now stored as `{ path }` objects; networking parser no longer warns "missing path field".
- **`-Debug`/`-Verbose` preference-variable propagation — definitive fix (#322)** — detection via `$PSBoundParameters` in `Invoke-AzureLocalRanger`; injected through structural overrides.
- **Arc node discovery 'Argument types do not match' (#327)** — `$subscriptionId` and `$clusterRg` in `Resolve-RangerArcMachinesForCluster` now explicitly cast to `[string]` before use; same root cause as #261.
- **BMC Redfish 401 Unauthorized (#329)** — `Invoke-RangerRedfishRequest` now passes `-Authentication Basic` to `Invoke-RestMethod`; iDRAC requires Basic auth and returned 401 for every request without it.
- **Run-complete hashtable printed to console (#330)** — `Invoke-AzureLocalRanger` captures the runtime return value and emits a clean `Write-Host` summary (collector outcomes + output path + log path) instead of the raw ordered hashtable.
- **WAF SEC-007 spurious null-calculation warning (#331)** — data-unavailable case (calculation key defined but manifest field null) now logged at debug level; genuine rule-authoring errors (undefined key) keep the `Write-Warning`.
- **External verbose output missing from ranger.log (#332)** — `global:Write-Verbose` proxy installed alongside `global:Write-Warning`; all external module verbose output (Invoke-RestMethod HTTP tracing, PackageManagement, CIM, Az SDK) now written to `ranger.log` when running at debug level. Entries already written by `Write-RangerLog` are skipped to prevent duplicates.
- **Hardware collector probes iDRAC IPs with WinRM (#333)** — when `endpoint.node` is null and no cluster node FQDN matches, `$remoteNodeTarget` fell back to the BMC IP, causing `Invoke-RangerClusterCommand` to probe it with WinRM — producing 45-second timeouts per endpoint. `$hasWinRmTarget` flag now guards the VBS/DeviceGuard/OMI WinRM block; skipped with a debug log when the target is still the BMC IP.

## [2.6.4] — 2026-04-17

First-Run UX Patch — fixes a structural-placeholder leak that blocked the 2-field / zero-config invocation path advertised in v2.6.3. Same bug class as v2.6.3 #292, but for structural fields (`environment.*`, `targets.cluster.*`, `targets.azure.*`).

### Fixed

- **Default config scaffold placeholders break bare `Invoke-AzureLocalRanger` and the 2-field invocation (#300)** — `Get-RangerDefaultConfig` no longer ships placeholder values for `environment.name`, `environment.clusterName`, `environment.description`, `targets.cluster.fqdn`, `targets.azure.subscriptionId`, `tenantId`, `resourceGroup`, or `targets.bmc.endpoints`. The v2.6.3 auto-discovery cluster-select gate used `[string]::IsNullOrWhiteSpace($Config.environment.clusterName)` to decide whether to run `Select-RangerCluster`; with `clusterName` carrying the placeholder `'azlocal-prod-01'`, that check returned false and cluster-select was silently skipped. The annotated YAML template (`Get-RangerAnnotatedConfigYaml`) still ships its human-readable `[REQUIRED]` scaffold values for operators who prefer to edit a file — that path is untouched.

### Changed

- **Interactive prompt re-runs auto-discovery between answers (#300)** — `Invoke-RangerInteractiveInput` now prompts one field at a time and re-runs `Invoke-RangerAzureAutoDiscovery` after each answer. Supplying subscription + tenant at the first two prompts fires `Select-RangerCluster` on the next pass and auto-fills `clusterName`, `resourceGroup`, `cluster.fqdn`, and `nodes` from Arc — so the remaining prompts collapse to zero or one. Previous behavior was to collect every missing field in a single pass, then validate. Even when the operator gave Ranger everything it needed to auto-discover, the single run of auto-discovery had already happened before the prompts, so the values had no effect.
- **Prompt order now leads with Azure identifiers (#300)** — `Get-RangerMissingRequiredInputs` lists `subscriptionId` and `tenantId` before the fields that auto-discovery would fill (cluster FQDN, resource group, environment name). Operators who know nothing but those two can invoke bare `Invoke-AzureLocalRanger` and complete the run with exactly two keystroke-level answers.
- **Fixture-mode bypass in `Test-RangerConfiguration` (#300)** — the required-target check now respects fixture mode the same way `Get-RangerMissingRequiredInputs` does. Without the bypass, fixture-backed test runs failed `Test-RangerTargetConfigured` because the default config's cluster target is now legitimately empty instead of carrying placeholder values.

## [2.6.3] — 2026-04-17

First-Run UX — drop the required-input floor to two fields (tenantId +
subscriptionId), fill in the rest via Azure Arc auto-discovery, and rebuild
the setup wizard with full credential-method coverage and a proper YAML
serializer.

### Added

- **Cluster node auto-discovery (#294)** — `Invoke-RangerAzureAutoDiscovery` now also populates `targets.cluster.nodes` when the config leaves them empty. Priority: Arc HCI cluster `properties.nodes[]`, then a subscription-wide Arc machines query scoped to the cluster's resource group. Short names are promoted to FQDNs using the discovered cluster domain suffix. Operators can now run with just `clusterName` (plus subscription/tenant) and get a fully-populated node list before collection starts — no more empty collectors on minimal configs.
- **Three-field minimum invocation (#296)** — `Invoke-AzureLocalRanger` no longer requires `-ConfigPath` or `-ConfigObject`. Passing `-SubscriptionId -TenantId -ClusterName` on the command line (or any subset, with prompting for the rest in interactive mode) is now enough to start a run. `Import-RangerConfiguration` returns the built-in defaults when neither config input is supplied, and structural overrides + Arc auto-discovery fill in the rest. `environment.name` defaults to `clusterName` when left at the scaffold placeholder, so the 3-field flow passes validation without an explicit `-EnvironmentName`.
- **Two-field cluster auto-select (#297)** — new `Select-RangerCluster` enumerates `microsoft.azurestackhci/clusters` in the subscription. When a single cluster exists it's auto-selected; when multiple exist and the shell is interactive the operator gets a numbered menu; under `-Unattended` or when no interactive host is available, a multi-cluster subscription throws `RANGER-DISC-002` with clear disambiguation guidance. `RANGER-DISC-001` fires when the subscription contains no HCI clusters, and `RANGER-AUTH-001` fires when the caller lacks the permissions to list them. Called automatically from `Invoke-RangerAzureAutoDiscovery` whenever `clusterName` is absent but `subscriptionId` is set, so `Invoke-AzureLocalRanger -TenantId x -SubscriptionId y` now works end-to-end.

### Changed

- **Scope-gated device credential prompting (#295)** — `Resolve-RangerCredentialMap` no longer triggers the `Get-Credential` prompt chain for `bmc`, `switch`, or `firewall` credentials unless the relevant collector is in scope AND a matching target list is populated. Previously every run surfaced a BMC prompt even when no BMC endpoints were configured. Explicit `-BmcCredential` / switch / firewall credential overrides are still honored even when the target list is empty, so operators can pre-supply credentials for interactive target entry.
- **Wizard overhaul (#291)** — `Invoke-RangerWizard` has been substantially expanded. Credential strategies now cover all six supported paths (existing-context, run-time prompt, service-principal with optional `keyvault://` secret ref, managed-identity, device-code, azure-cli) instead of the original two. GUID fields (subscription, tenant, service-principal client ID) are validated and re-prompted inline. A new optional BMC section lets operators add iDRAC endpoints (+ username) directly from the wizard. The run-mode choice adds `as-built` alongside `current-state`. Before any save or run, the wizard prints the assembled config as YAML and asks for confirmation. Save now writes YAML (via `ConvertTo-RangerYaml`) by default and JSON only when the path ends in `.json` — fixing the prior bug where `.yml` files contained JSON. Existing files trigger an overwrite confirmation instead of being silently clobbered.

### Fixed

- **kv-ranger credential leak (#292)** — `Get-RangerDefaultConfig` no longer ships placeholder `keyvault://kv-ranger/*` password references for the `cluster`, `domain`, and `bmc` credential blocks. These placeholders survived the deep merge whenever a user config omitted the fields, causing the pre-check to try to resolve secrets against a Key Vault the operator never configured — producing DNS errors that looked like the operator's mistake. The default now carries null `username` and `passwordRef` for all three blocks, so missing credentials fall through to the interactive prompt (or fail cleanly under `-Unattended`).

## [2.5.0] — 2026-04-17

Extended Platform Coverage — workload/cost intelligence, multi-cluster
orchestration, and presentation-ready output.

### Added

- **Capacity headroom analysis (#128)** — `manifest.domains.capacityAnalysis` domain. Per-node + cluster totals for vCPU allocation, memory allocation, storage used, and pool allocated. Healthy / Warning / Critical status per dimension from configurable thresholds (default warn 80%, fail 90%).
- **Idle / underutilized VM detection (#125)** — `manifest.domains.vmUtilization` domain. Classifies each VM as idle / underutilized / healthy / stopped / no-counters from `vm.utilization` sidecar data (avg/peak CPU %, avg memory %). Emits rightsizing proposals (`proposedVcpu`, `proposedMemoryMb`) and aggregated potential-freed-resource savings.
- **Storage efficiency analysis (#126)** — `manifest.domains.storageEfficiency` domain. Per-volume dedup state, dedup mode, dedup ratio, saved GiB, thin-provisioning coverage. Emits a `wasteClass` tag (`over-provisioned`, `dedup-candidate`, `none`) and aggregate logical-vs-physical GiB.
- **SQL / Windows Server license inventory (#127)** — `manifest.domains.licenseInventory` domain. Enumerates guest-detected SQL instances (edition, version, core count, license model, AHB eligibility) and Windows Server instances with core totals, ready for compliance reporting.
- **Multi-cluster estate rollup (#129)** — `Invoke-AzureLocalRangerEstate` runs Ranger against every target in an estate config. Emits per-cluster packages plus `estate-rollup.json`, `estate-summary.html`, and `powerbi/estate-clusters.csv` with WAF score / AHB / capacity posture per cluster.
- **PowerPoint output (#80)** — new `pptx` output format. Builds a 7-slide executive overview OOXML `.pptx` via `System.IO.Packaging`. No Office or third-party-module dependency.
- **Import-RangerManualEvidence (#32)** — merges hand-collected evidence (network inventory, firewall exports, externally governed data) into an existing audit-manifest.json with provenance labels. `manifest.run.manualImports` records source, domain, and evidence file path.

### Changed

- Runtime pipeline runs v2.5.0 analyzers after all collectors complete and before schema validation so the new domains are subject to the same verification as collected data.

## [2.3.0] — 2026-04-17

Cloud Publishing — push Ranger run packages to Azure Blob Storage and stream
WAF telemetry to Log Analytics Workspace after every run.

### Added

- **Azure Blob publisher (#244)** — `Publish-RangerRun` uploads the run package (manifest, evidence, package-index, log, optionally reports + powerbi) to a named storage account. Auth chain: Managed Identity → Entra RBAC → SAS from Key Vault. SHA-256 idempotency skips unchanged blobs. Blob tags: `cluster`, `mode`, `toolVersion`, `runId`. `Invoke-AzureLocalRanger -PublishToStorage` triggers automatically post-run.
- **Catalog + latest-pointer blobs (#245)** — after each publish, writes `_catalog/{cluster}/latest.json` (run summary + artifact paths + WAF score snapshot) and merges `_catalog/_index.json` so downstream consumers resolve the latest run per cluster without listing.
- **Cloud Publishing guide + samples (#246)** — `docs/operator/cloud-publishing.md` with RBAC setup (Storage Blob Data Contributor), config schema, auth chain explanation, and troubleshooting. `samples/cloud-publishing/` with Bicep storage Bicep, KQL workbook, and Teams webhook starter.
- **Log Analytics Workspace sink (#247)** — `Invoke-AzureLocalRanger -PublishToLogAnalytics` posts one `RangerRun_CL` row (scores, AHB adoption, node/VM counts, cloud-publish status) and one `RangerFinding_CL` row per failing WAF rule to a DCE/DCR pair via the Logs Ingestion API. Offline mode available for tests.

## [2.2.0] — 2026-04-17

WAF Compliance Guidance — turn the WAF score into an actionable roadmap with
priority-ranked fix order, projected post-fix score, and a copy-pasteable
remediation script.

### Added

- **Structured remediation block per WAF rule (#236)** — every rule in `config/waf-rules.json` now carries `remediation.{rationale, steps, samplePowerShell, estimatedEffort, estimatedImpact, dependencies, docsUrl}`. Reports surface a new "Next Step" column in the Findings table and a full Remediation Detail section per failing rule. Schema version bumped to `2.2.0` with a new `prioritization` block defining severity, impact, and effort factors.
- **WAF Compliance Roadmap (#241)** — `Invoke-RangerWafRuleEvaluation` now returns a `roadmap` array bucketing failing rules into Now/Next/Later tiers by `priorityScore = (weight * severityMultiplier * impactFactor) / effortFactor`. Rendered as a ranked table in the technical tier; exported as `powerbi/waf-roadmap.csv`.
- **Gap-to-Goal projection (#242)** — `gapToGoal` result block with a greedy fix plan: *"Current 67%. Closing these 3 findings raises you to 82% (Excellent)."* Honours rule dependencies so prerequisites fix first. Exported as `powerbi/waf-gap-to-goal.csv`. Truncated at 5 entries or when the projected score crosses the next threshold.
- **Per-pillar WAF Compliance Checklist (#238)** — one subsection per pillar with every rule, status, weight, effort, next step, and a Signed Off column for handoff / sprint artefact use. Exported as `powerbi/waf-checklist.csv`.
- **`Get-RangerRemediation` (#243)** — new public command emits a copy-pasteable remediation script from an existing manifest. `-Format ps1|md|checklist`, `-Commit` for live cmdlets (dry-run by default), `-IncludeDependencies` to expand prerequisites, `-FindingId` to target specific rules. Substitutes `$ClusterName`, `$ResourceGroup`, `$SubscriptionId`, `$Region`, `$NodeName` from the manifest.

### Changed

- `Invoke-RangerWafRuleEvaluation` now returns `roadmap` and `gapToGoal` alongside the existing `pillarScores` and `ruleResults`.
- Every rule result carries `estimatedEffort`, `estimatedImpact`, and `priorityScore` for downstream consumers.

## [2.1.0] — 2026-04-16

Preflight Hardening — closes three auth gaps identified during the v2.0.0
post-release review. Every failure that would have surfaced mid-run now
surfaces in the pre-run audit.

### Added

- **Per-resource-type ARM probe (#235)** — `Invoke-RangerPermissionAudit` now issues a `Get-AzResource` against each v2.0.0 collector surface (`Microsoft.AzureStackHCI/logicalNetworks`, `Microsoft.AzureStackHCI/storageContainers`, `Microsoft.ExtendedLocation/customLocations`, `Microsoft.ResourceConnector/appliances`, `Microsoft.HybridCompute/gateways`, `Microsoft.AzureStackHCI/marketplaceGalleryImages`, `Microsoft.AzureStackHCI/galleryImages`). Per-surface result is recorded on `$script:RangerLastArmSurfaceChecks`. All surfaces Pass → audit `v2.0.0 ARM surfaces` check is Pass. Some Deny → Warn with the denied surface names. All Deny → Fail with actionable remediation.
- **Deep WinRM CIM probe (#234)** — new `Invoke-RangerCimDepthProbe` in `Modules/Private/72-CimDepthProbe.ps1`. Runs after the shallow WinRM preflight and issues a representative `Get-CimInstance` against `root/MSCluster` (`MSCluster_Cluster`), `root/virtualization/v2` (`Msvm_VirtualSystemManagementService`), and `root/Microsoft/Windows/Storage` (`MSFT_StoragePool`). Result captured in `manifest.run.remoteExecution.cimDepth` with per-namespace status (`ok`, `denied`, `missing-namespace`, `error`). `denied` overall raises a warning finding; `partial` logs the denied namespace list; `sufficient` is quiet. Non-blocking — warns rather than throws so operators with arc-only transport can still run.
- **Azure Advisor read probe (#233)** — `Invoke-RangerPermissionAudit` calls `Get-AzAdvisorRecommendation`. Success → Pass. 403 → Warn with "WAF Assessment Advisor section will be empty" messaging and explicit `Microsoft.Advisor/recommendations/read` permission naming. Provider not registered → Warn with `Register-AzResourceProvider -ProviderNamespace Microsoft.Advisor` remediation. `Az.Advisor` module missing → Skip with an optional-install hint. Never blocks the run because Advisor is advisory.

### Changed

- Overall readiness semantics unchanged from v1.6.0 — `Insufficient` throws, `Partial` warns and continues, `Full` is quiet.
- New checks are all skipped in fixture mode (same `isFixtureMode` gate that already guards the v1.6.0 pre-check).

## [2.0.0] — 2026-04-16

### Added — Collectors

- **Arc machine extensions per node (#215)** — per-node inventory of Arc extensions (AMA, Defender for Servers, Guest Configuration) with `typeHandlerVersion`, `provisioningState`, `autoUpgradeMinorVersion`, `enableAutomaticUpgrade`. Surfaced as a dedicated `Arc Extensions by Node` HTML/Markdown/DOCX table (landscape-oriented in PDF), an `Extensions` XLSX tab, and an `arc-extensions.csv` Power BI table. `domains.azureIntegration.arcExtensionsDetail` is a hashtable with `byNode` + `summary.amaCoveragePct`.
- **Logical networks + subnet detail collector (#216)** — `Microsoft.AzureStackHCI/logicalNetworks` with per-subnet `addressPrefix`, `vlan`, `ipPools`, `dhcpOptions`, `vmSwitchName` cross-reference, and `dnsServers`. New `Logical Networks` + `Logical Network Subnets` sections; `LogicalNetworks` + `Subnets` XLSX tabs; `logical-networks.csv` Power BI CSV.
- **Storage paths collector (#217)** — `Microsoft.AzureStackHCI/storageContainers` inventory with CSV cross-reference. New `Storage Paths` section; `StoragePaths` XLSX tab; `storage-paths.csv` Power BI CSV.
- **Custom locations collector (#218)** — `Microsoft.ExtendedLocation/customLocations` linked to Resource Bridge `hostResourceId`.
- **Arc Resource Bridge collector (#219)** — `Microsoft.ResourceConnector/appliances` with version, distro, infrastructure provider, status. Arc VMs now carry a `vmProvisioningModel` field (`hyper-v-native` | `arc-vm-resource-bridge`).
- **Arc Gateway collector (#220)** — `Microsoft.HybridCompute/gateways` with per-node routing detection (`arcGatewayNodeRouting`).
- **Marketplace + custom image collector (#221)** — `Microsoft.AzureStackHCI/marketplaceGalleryImages` and `galleryImages` with storage-path cross-reference and publisher / offer / SKU metadata.

### Added — Intelligence

- **AHB cost/licensing analysis (#222)** — `Invoke-RangerCostLicensingAnalysis` reads `softwareAssuranceProperties.softwareAssuranceStatus` as the cluster-level AHB signal, multiplies physical cores against the public $10/core/month rate, and emits current monthly cost, potential savings, and `ahbAdoptionPct` under `domains.azureIntegration.costLicensing`. New `Cost & Licensing` + `Cost & Licensing — Per Node` HTML/Markdown/DOCX/PDF sections with pricing footer. `CostLicensing` XLSX tab + `cost-licensing.csv` Power BI CSV.
- **VM distribution balance analysis (#223)** — `Invoke-RangerVmDistributionAnalysis` computes coefficient of variation across nodes. Balanced/warning/fail thresholds at CV < 0.2 / 0.2–0.3 / > 0.3 or any node > 2× mean. Surfaces as per-node table with CV-in-caption status.
- **Agent version grouping (#224)** — `Invoke-RangerAgentVersionAnalysis` groups nodes by Arc agent + OS version with drift summary (`uniqueVersions`, `latestVersion`, `maxBehind`, `status`). New `Arc Agent Versions` section.
- **Weighted WAF scoring (#225)** — per-rule `weight` field (1–3); warning severity awards 0.5× weight; graduated threshold bands still work; pillar and overall scores aggregate weighted awarded over weighted max. `scoreThresholds` (Excellent/Good/Fair/Needs Improvement) exposed on the evaluator result. New rules: SEC-007 (AMA coverage graduated), SEC-008 (agent version drift), COST-003 (AHB adoption graduated), REL-007–009 (logical networks, resource bridge, VM distribution), OE-007–009 (storage paths, custom locations, image provenance).

### Added — Commands and UX

- **`Export-RangerWafConfig` / `Import-RangerWafConfig` (#226)** — hot-swap WAF rule config. `-Validate` schema-checks without writing. `-Default` restores the shipped `waf-rules.default.json` backup. `-ReRun -ManifestPath` re-evaluates against an existing manifest.
- **`json-evidence` output format (#229)** — raw resource-only JSON payload with a minimal `_metadata` envelope; excludes `healthChecks`, `wafResults`, `summary`, `run`. Accepted by `Invoke-AzureLocalRanger -OutputFormats json-evidence` and `Export-AzureLocalRangerReport -Formats json-evidence`. Filename: `<runId>-evidence.json` under `reports/`.
- **`-SkipModuleUpdate` (#231)** — opt-out of automatic Az.* module install/update on startup for air-gapped environments. Install/update validation is invoked before pre-check.

### Added — Reliability

- **Concurrent collection guard (#230)** — second `Invoke-AzureLocalRanger` call in the same session emits a warning and returns without racing shared `script:` state; flag is released in a `finally` block.
- **Empty-data safeguard (#230)** — when collection completes with zero nodes, Ranger throws an actionable error naming the cluster target and WinRM / RBAC remediation paths instead of producing empty reports.
- **Module auto-install/update on startup (#231)** — required modules (`Az.Accounts`, `Az.Resources`, `Az.ConnectedMachine`, `Az.KeyVault`) are installed or updated via `Install-Module`/`Update-Module -Force -Scope CurrentUser` when below minimum version. Optional modules (`Az.StackHCI`, `Az.ResourceGraph`, `ImportExcel`) emit an info hint when missing. Install/update failures log a warning but do not abort the run.

### Added — Output

- **Portrait/landscape page switching (#227)** — `@page landscape-pg` CSS rule applied to sections flagged `_layout='landscape'` (Arc extensions, logical network subnets). Headless Edge/Chrome `--print-to-pdf` honours the rule.
- **Conditional status-cell coloring (#227)** — HTML data tables apply `status-Healthy` / `status-Warning` / `status-Failed` CSS classes per recognized status token (Healthy/Succeeded/Connected/Running/Up/Enabled/Yes vs Warning/Updating/Degraded vs Failed/Critical/Disconnected).
- **Pricing footer with dated reference (#228)** — every Cost & Licensing section includes `pricingReference.asOfDate` and the official Azure Local pricing URL.

### Changed

- **Manifest schema bump to `1.2.0-draft`** to reflect the new domain shapes under `azureIntegration.arcExtensionsDetail`, `networking.logicalNetworks`, `storage.storagePaths`, `azureIntegration.costLicensing`, and `virtualMachines.summary.vmDistribution*`.

## [1.6.0] — 2026-04-16

### Added — Auth and Discovery

- **Auto-discover resource group (#196)** — `Resolve-RangerClusterArcResource` falls back to a subscription-wide ARM search by cluster name when `targets.azure.resourceGroup` is absent; the discovered RG is written back into the resolved config for downstream callers.
- **Auto-discover cluster FQDN (#197)** — new `Invoke-RangerAzureAutoDiscovery` runs before prompts and validation. Pulls the FQDN from Arc properties (`dnsName`, `reportedProperties.clusterId`, or `name + domainName`), or composes it from a resolved Arc domain. Eliminates the field-by-field prompt when Azure credentials are present.
- **Multi-method Azure auth chain (#200)** — `Connect-RangerAzureContext` now supports `service-principal-cert` (certificate thumbprint or PFX path with optional password), tenant-matching existing-context reuse (no re-auth when the loaded context already matches the requested tenant), and sovereign-cloud environment forwarding.
- **Save-AzContext handoff (#201)** — new `Export-RangerAzureContext` and `Import-RangerAzureContext` helpers. Runs save the Az session to a temp file for handoff into a background runspace that imports it as its first action; temp file is deleted by default after import.
- **Azure Resource Graph single-query (#205)** — new `Get-RangerArmResourcesByGraph` runs a single `Search-AzGraph` KQL query for a configurable list of resource types, scoped optionally to subscription / RG / management group. `Resolve-RangerArcMachinesForCluster` now uses Resource Graph as the fast path with `Get-AzResource` fallback when `Az.ResourceGraph` is absent.

### Added — Connectivity

- **WinRM TrustedHosts + DNS fallback (#203)** — new `Resolve-RangerClusterFqdn` and `Resolve-RangerNodeFqdn` implement a passthrough → TrustedHosts scan → DNS `GetHostEntry` chain. Wired into `Invoke-RangerAzureAutoDiscovery` so on-prem environments resolve FQDNs without Azure.
- **Node / VM cross-RG fallback (#204)** — new `Resolve-RangerArcMachinesForCluster` runs an RG-scoped Arc machines query first, then a subscription-wide fallback when nodes live outside the cluster RG. Emits a `warning` per cross-RG node and reports them via `CrossRg`.

### Added — Commands and UX

- **`Invoke-AzureLocalRanger -Wizard` (#211)** — inline `-Wizard` / `-OutputConfigPath` / `-SkipRun` parameters on the main command dispatch to `Invoke-RangerWizard`. Missing-input prompts now surface `Invoke-AzureLocalRanger -Wizard` as the recommended alternative to field-by-field prompting.
- **`Test-RangerPermissions` (#202)** — new public command. Checks Azure context, Subscription Reader, HCI cluster read, Arc machine read, Key Vault secret access (when `keyvault://` refs exist), and `Microsoft.AzureStackHCI` / `Microsoft.HybridCompute` provider registration. `-OutputFormat console|json|markdown`.
- **`-SkipPreCheck` (#212)** — the pre-run permission audit runs by default. Failed audit aborts with actionable remediation; partial emits a warning and continues. Skipped automatically in fixture mode. Opt out via `-SkipPreCheck` or `behavior.skipPreCheck: true`.
- **File-based progress IPC (#213)** — new `Write-RangerProgressState`, `Read-RangerProgressState`, and `Remove-RangerProgressState` write atomic JSON snapshots to `$env:TEMP\ranger-progress-<RunId>.json`. Path-traversal-safe `RunId` sanitisation. Foundation for background-runspace progress reporting.

### Added — Resilience

- **Graceful degradation on partial Azure permissions (#206)** — new `Get-RangerArmErrorCategory` classifier (Authorization / NetworkUnreachable / NotFound / Throttled / Other) plus a skipped-resources tracker. `Resolve-RangerClusterArcResource` and Resource Graph queries record skips with category + reason; `manifest.run.skippedResources` surfaces partial runs. A warning finding is added when any skip occurred. New `behavior.failOnPartialDiscovery` (default `false`) aborts the run at end-of-collection when set.

### Added — Output formats

- **Headless-browser PDF (#207)** — new `Resolve-RangerHeadlessBrowser` and `Invoke-RangerHeadlessPdf`; the `pdf` format renders the HTML report through `msedge --headless=new --print-to-pdf` for high-fidelity output. The existing plain-text PDF writer remains the fallback when no browser is found. Sample output sizes jumped from ~40 KB plain-text to 440–812 KB rendered HTML.
- **DOCX OOXML tables (#208)** — `section.type='table'`, `'kv'`, and `'sign-off'` now render as real Word tables with header styling, borders, and caption rows. Previously these section types rendered as empty paragraphs.
- **XLSX formula-injection safety (#209)** — cell values that begin with `=`, `+`, `-`, or `@` are apostrophe-prefixed so Excel treats them as literal text. Existing multi-tab workbook, frozen header, and auto-filter behaviour retained.
- **Power BI CSV + star-schema export (#210)** — new `Invoke-RangerPowerBiExport` produces `nodes.csv`, `volumes.csv`, `storage-pools.csv`, `health-checks.csv`, `network-adapters.csv`, `_relationships.json` (star-schema manifest), and `_metadata.json`. Added `powerbi` to supported `OutputFormats`. All CSV values sanitised against formula injection and embedded newlines.
- **Graduated WAF scoring (#214)** — `Invoke-RangerWafRuleEvaluation` now supports a `thresholds` array with graduated point awards, named `calculation` references (`min` / `max` / `avg` / `sum` / `count` / `pct` aggregates pre-computed from the manifest), and `{value}` message substitution. Existing `check`-style pass/fail rules remain unchanged. Pillar and overall scores now weight by `awardedPoints` / `maxPoints`.

## [1.5.0] — 2026-04-16

### Added

- **As-built document redesign (#193)** — The as-built mid-tier is now an Installation and Configuration Record with per-node configuration, network address allocation, storage configuration, Azure integration, identity and security records, a validation record, and a known-issues/deviations register. Deployment past-tense framing throughout; minimal-color formal styling. `samples/output/iic-as-built/` regenerated.
- **Mode differentiation (#194)** — as-built now uses distinct tier names ("Installation and Configuration Record", "Technical As-Built"), a CONFIDENTIAL classification banner, and a "Post-Deployment As-Built Package" subtitle. current-state retains "Management Summary", "Technical Deep-Dive", Health Status traffic lights, and an INTERNAL banner. Field engineers can tell the two deliverables apart at a glance.
- **HTML report quality (#192)** — Inline architecture diagrams embedded under a new Architecture Diagrams section. Data tables use fixed layout with constrained column widths. Findings render as severity-colored callout boxes. A print stylesheet ensures clean browser-to-PDF output. Sign-off tables have visible signature lines.

### Fixed

- **Wizard default formats (#195)** — Default report formats changed from `html,markdown,json,svg` (where `json` was invalid) to `html,markdown,docx,xlsx,pdf,svg`. The prompt label now lists the valid set so operators can reference it inline.
- **Key Vault DNS error handling (#198)** — DNS resolution failures against Key Vault now emit an actionable error naming the likely causes (VPN not connected, wrong KV name, private endpoint unreachable). When `behavior.promptForMissingCredentials: true`, Ranger falls back to `Get-Credential` rather than aborting the run.

## [1.4.2] — 2026-04-16

### Fixed

- **TRAILHEAD test configs** — Added `credentials.domain` section to both `tests/trailhead/configs/tplabs-current-state.yml` and `tplabs-as-built.yml`. Without this section the module fell back to `keyvault://kv-ranger/domain-read`, which does not exist in the tplabs environment.
- **TRAILHEAD test configs** — Added `svg` and `drawio` to `output.formats` in both tplabs configs. `Invoke-RangerOutputGeneration` only calls `Invoke-RangerDiagramGeneration` when `svg` or `drawio` appears in the normalised formats list; omitting them silently skipped all diagram output.
- **New-RangerFieldTestCycle.ps1** — Removed `SupportsShouldProcess` from `[CmdletBinding()]` to eliminate parameter conflict with previously explicit `[switch]$WhatIf`.
- **deploy-docs.yml** — Removed `release: [published]` trigger. GitHub Pages environment protection allows deployments only from `main`; release-tag triggers always failed the environment protection check.

### Validated

- **Operation TRAILHEAD v1.4.2** — Full 8-phase (P0-P7) field validation cycle completed against live tplabs-clus01 (4-node Dell AX-760, TierPoint Labs, Raleigh NC). All 7 collectors succeeded (hardware partial due to firmware Redfish limitation, gracefully handled). All output formats generated: HTML, Markdown, JSON, XLSX, PDF, 13×SVG, 13×draw.io (33 files total). as-built vs current-state differentiation confirmed. Wizard (`Invoke-RangerWizard`) guided config + run confirmed. Pester 76/76 passing. WAF Assessment rule engine scored 48% overall ("At Risk"), 11/23 rules passing.

## [1.4.1] — 2026-04-16

### Fixed

- **Invoke-RangerWizard interactive gate (#180)** — `Test-RangerInteractivePromptAvailable` previously checked `[Console]::IsInputRedirected`, which returns `true` in VS Code terminal and Windows Terminal even when a real user is present. Now gates on `[Environment]::UserInteractive` only. Two regression tests added to `Config.Tests.ps1`.

## [1.4.0] — 2026-04-16

### Added

- **Issue #168** — HTML report rebuild. `ConvertTo-RangerHtmlReport` now renders type-aware section content: `type='table'` sections use styled `<table>` elements, `type='kv'` uses a two-column key-value grid, `type='sign-off'` renders a formal handoff table with Implementation Engineer / Technical Reviewer / Customer Representative rows. New section data shapes added for Node Inventory, VM Inventory, Storage Pool Capacity, Physical Disk Inventory, Network Adapter Inventory, Event Log Summary, and Security Audit. `ConvertTo-RangerMarkdownReport` updated with equivalent type-aware rendering for table, kv, and sign-off sections.
- **Issue #140** — Diagram engine quality. `ConvertTo-RangerSvgDiagram` rebuilt with two-pass layout: first pass assigns positions, second renders group containers (color-coded background rects with labels) then nodes and cubic bezier edges. `ConvertTo-RangerDrawIoXml` rebuilt with swim-lane group containers, per-kind node styles (volume, disk, adapter, workload, policy, bmc, hardware, monitor, heat), and orthogonal edge style. Near-empty diagrams (< 1 non-root node) return `$null` and record a skipped artifact instead of writing an unusable file.
- **Issue #96** — PDF output. `Write-RangerPdfReport` now prepends a cover page with title, cluster name, mode, version, generated date, and confidentiality notice. `Get-RangerReportPlainTextLines` renders type-aware plain text for PDF: pipe-delimited tables, aligned key: value pairs, and sign-off placeholders.
- **Issue #94** — WAF Assessment integration. New optional collector `Invoke-RangerWafAssessmentCollector` queries Azure Advisor recommendations and maps them to WAF pillars (Reliability, Security, Cost Optimization, Operational Excellence, Performance Efficiency). New rule engine (`Invoke-RangerWafRuleEvaluation`) evaluates 23 manifest-path rules from `config/waf-rules.json` — rules do not require re-collection and can be re-evaluated from any saved manifest. WAF Scorecard table (management + technical tiers) and WAF Findings detail table (technical tier) added to report payload. New `wafAssessment` manifest domain and fixture file.

### Fixed

- **Invoke-RangerWizard interactive gate** — `Test-RangerInteractivePromptAvailable` previously checked `[Console]::IsInputRedirected`, which returns `true` in VS Code terminal, Windows Terminal, and similar hosts even when a real user is present. The check now uses only `[Environment]::UserInteractive`, which correctly distinguishes interactive users from CI runners, service accounts, and scheduled tasks. Two unit tests added to `Config.Tests.ps1` to prevent regression.

## [1.3.0] — 2026-04-16

### Added

- **Issue #171** — Full config parameter coverage. Every `behavior.*`, `output.*`, and `credentials.azure.*` config key is now a direct runtime parameter on `Invoke-AzureLocalRanger`; parameters take precedence over config file values via `Set-RangerStructuralOverrides`.
- **Issue #174** — First Run guide (`docs/operator/first-run.md`): six-step linear guide from install to output with no decisions.
- **Issue #175** — Wizard guide (`docs/operator/wizard-guide.md`): full `Invoke-RangerWizard` walkthrough with example inputs and generated YAML.
- **Issue #176** — Command reference scenarios: nine copy-paste examples and parameter precedence documentation added to `docs/operator/command-reference.md`.
- **Issue #177** — Configuration reference (`docs/operator/configuration-reference.md`): every config key with type, default, required/optional, and Key Vault syntax.
- **Issue #178** — Understanding output guide (`docs/operator/understanding-output.md`): output directory tree, role-based reading path, collector status interpretation.
- **Issue #179** — Discovery domain enhancements: all 10 domain pages now include example manifest data, common findings, partial status guidance, and domain dependencies.

## [1.2.0] — 2026-04-16

### Added

- **Issue #26** — Arc Run Command transport. `Invoke-AzureLocalRanger` now routes WinRM workloads through Azure Arc Run Command (`Invoke-AzConnectedMachineRunCommand`) when cluster nodes are unreachable on ports 5985/5986. New functions: `Invoke-RangerArcRunCommand`, `Test-RangerArcTransportAvailable`. Transport mode configured via `behavior.transport` (auto / winrm / arc). Falls back gracefully when `Az.ConnectedMachine` is absent. `Az.ConnectedMachine` added to `ExternalModuleDependencies`.
- **Issue #30** — Disconnected / semi-connected discovery. A pre-run connectivity matrix (`Get-RangerConnectivityMatrix`) probes all transport surfaces (cluster WinRM, Azure management plane, BMC HTTPS) and classifies posture as `connected`, `semi-connected`, or `disconnected`. Collectors whose transport is unreachable receive `status: skipped` instead of failing mid-run. Full matrix stored at `manifest.run.connectivity`. New `behavior.degradationMode` config key (graceful / strict). New file: `Modules/Private/70-Connectivity.ps1`.
- **Issue #76** — Spectre.Console TUI progress display. A live per-collector progress bar using `PwshSpectreConsole` renders during collection when the module is installed and the session is interactive. Falls back to `Write-Progress` automatically. Suppressed in CI and `Unattended` mode. New file: `Modules/Private/80-ProgressDisplay.ps1`. New `-ShowProgress` parameter on `Invoke-AzureLocalRanger`. New `output.showProgress` config key.
- **Issue #75** — Interactive configuration wizard. `Invoke-RangerWizard` walks through a guided question sequence (cluster, nodes, Azure IDs, credentials, output, scope), then offers to save the config as YAML, launch a run, or both. Available as a public exported command.

## [1.1.2] — 2026-04-15

### Fixed

- **Issue #160** — `Get-RangerManifestSchemaContract` rewritten to return an inline hashtable instead of reading a file path. Eliminates `FileNotFoundException` for PSGallery installs where `repo-management/` is not present.
- **Issue #161** — `Get-RangerToolVersion` helper added to `Modules/Core/10-Manifest.ps1`. `New-RangerManifest` now reads `toolVersion` dynamically from the loaded module version instead of the previously hardcoded `'1.1.0'` default parameter value.
- **Issue #162** — `Invoke-RangerRedfishRequest` now passes `-Label 'Invoke-RangerRedfishRequest' -Target $Uri` to `Invoke-RangerRetry`. Retry log entries for BMC/Redfish calls now carry actionable label and target URI instead of empty strings.
- **Issue #163** — `$DebugPreference = 'Continue'` removed from the `debug` log-level branch of `Initialize-RangerRuntime`. `$DebugPreference` is unconditionally set to `'SilentlyContinue'`, preventing thousands of MSAL and Az SDK internal debug lines from flooding output.
- **Issue #164** — Null entries filtered from the collector messages array via `Where-Object { $null -ne $_ }` in `Invoke-RangerCollector`. Prevents `null` entries from propagating into manifest `messages` arrays and HTML/Markdown report output.
- **Issue #165** — `Get-RangerRemoteCredentialCandidates` now appends domain credential before cluster credential. Domain admin has WinRM PSRemoting rights by default; the LCM cluster account typically does not, so domain-first ordering eliminates redundant auth retries.

### Added

- **Issues #166 and #167** — 20 Pester unit tests added at `tests/maproom/unit/Execution.Tests.ps1` covering all 9 v1.1.2 regression bugs (#157–#165). Trailhead field validation run against live tplabs cluster (4-node Dell AX-760, Raleigh NC) confirmed all 6 collectors succeeded with zero auth retries, schema valid, `toolVersion=1.1.2`.

## [1.1.1] — 2026-04-16

### Fixed

- `Test-AzureLocalRangerPrerequisites` now supports the documented no-config invocation path again. Running it with no arguments returns a structured prerequisite result and skips config-specific validation cleanly instead of throwing `Either ConfigPath or ConfigObject must be supplied.`

## [1.1.0] — 2026-04-15

### Added

- **Issue #36** — Offline network device config import via `domains.hints.networkDeviceConfigs` hints: Cisco NX-OS and IOS parser extracting VLANs, port-channels/LAGs, interfaces, and ACLs. New `switchConfig` and `firewallConfig` keys added to the `networking` manifest domain. New private module `Modules/Private/60-NetworkDeviceParser.ps1`. 7 new Pester tests in `tests/maproom/unit/NetworkDevice.Tests.ps1` including IIC NX-OS fixture at `tests/maproom/Fixtures/network-configs/switch-nxos-sample.txt`.
- **Issue #38** — As-built mode now produces differentiated report content: Document Control block, Installation Register, and Sign-Off table injected into each tier report when `mode = as-built`. New `Modules/Outputs/Templates/10-AsBuilt.ps1` with three template section functions. `Modules/Outputs/Templates/` added to module load path in `AzureLocalRanger.psm1`. 2 new simulation tests covering as-built document control and sign-off content.
- **Issue #37** — Full documentation audit: Manifest Sub-Domains tables added to all 8 domain pages that were missing them (`networking`, `cluster-and-node`, `storage`, `hardware`, `virtual-machines`, `management-tools`, `performance-baseline`, `oem-integration`). New contributor docs: `simulation-testing.md` (complete simulation framework guide, IIC canonical data standard, fixture regeneration), `template-authoring.md` (template system design, how to add new report sections). `contributor/getting-started.md` updated to remove deleted page references and reflect current implementation focus. MkDocs nav updated for new contributor pages.
- **Issues #123 and #124** — Unattended and repeatable discovery runs: `Invoke-AzureLocalRanger` now supports `-Unattended` and `-BaselineManifestPath`, writes `run-status.json`, emits `manifest/drift-report.json`, and includes scheduler-ready samples for Task Scheduler and GitHub Actions.
- **Issue #153** — Storage reserve and provisioning analysis: the storage collector now models raw, usable, used, free, reserve-target, and safe-allocatable capacity per pool, surfaces thin-provisioning exposure, and adds storage posture findings to the manifest and reports.
- **Issues #132 and #134** — Arc-backed guest intelligence: VM inventory now falls back to Arc network-profile IP data when Hyper-V guest IPs are unavailable, and Azure integration inventory now tracks Arc ESU eligibility and enrollment state for supported Windows Server guests.
- **Issues #118, #131, and #77** — Delivery guidance for the next phase: added the detailed technical runtime flow diagram, recorded the update-mode design, and completed the terminal TUI alternatives survey with `PwshSpectreConsole` selected as the preferred rich-terminal path.
- **Issue #139** — WinRM preflight validation: `Invoke-AzureLocalRanger` now probes all configured cluster targets (VIP + nodes) via TCP 5985/5986 and `Test-WSMan` before any collector runs, and throws immediately with a human-readable per-target error summary if any target is unreachable. `Test-AzureLocalRangerPrerequisites` includes the same per-target probe in its "Cluster WinRM connectivity" check. Probe results are cached per `(ComputerName, credential)` for the duration of the run so subsequent `Invoke-Command` calls do not re-probe. 2 new unit tests: successful probe cached on second call, WSMan authentication failure.
- **Issue #156** — Intelligent remoting credential selection for non-domain-joined runners: Ranger now probes authorization with current context, cluster credentials, and domain credentials in priority order, records the selected remote execution identity in `manifest.run.remoteExecution`, and falls back from `Get-AzKeyVaultSecret` to `az keyvault secret show` when Az PowerShell secret resolution is unavailable on the runner.

### Fixed

- **Issue #103** — `Export-AzureLocalRangerReport`: Added `-AsHashtable` to `ConvertFrom-Json` to correctly handle mixed-case JSON keys in live manifests; changed `$manifest.run.mode` to bracket access `$manifest['run']['mode']` for consistent hashtable compatibility.
- **Issue #105** — Workload/identity/Azure collector: Changed `Select-Object -ExpandProperty hostNode` to `ForEach-Object { $_['hostNode'] }` and `Group-Object -Property hostNode` to `Group-Object -Property { $_['hostNode'] }` to fix hashtable VM inventory property access producing incorrect `avgVmsPerNode` and always-empty `highestDensityNode`.
- **Issue #107** — Diagram generation: `Get-RangerSafeName` now accepts null/empty input (returns `'unnamed'`), SVG layout loop skips nodes with null/empty id, SVG edge loop skips edges with null/empty source or target. Prevents storage-architecture diagram crash when storage pool/CSV has no friendly name.
- **Issue #108** — `Test-RangerTargetConfigured`: Fixed `@($null).Count -gt 0` returning true when `targets.cluster` is absent; added explicit null check before testing for fqdn/nodes; node and endpoint lists filtered for null/empty entries before count check.
- **Issue #121** — v1.1.0 milestone-close validation: live `tplabs` validation now succeeds from the standard config path, including automatic BMC endpoint hydration from sibling `variables.yml` when `targets.bmc.endpoints` is omitted, and collectors now preserve actionable findings without downgrading an otherwise complete collection to `partial`.

### Changed

- `domains.hints.networkDeviceConfigs` added to `Get-RangerDefaultConfig` default hints structure
- `networking` domain reserved template now includes `switchConfig` and `firewallConfig` keys
- `networking` domain summary now includes `importedSwitchConfigCount` and `importedFirewallConfigCount` counts
- Report payloads now expose drift state, storage reserve headroom, safe allocatable capacity, Arc IP fallback usage, and Arc ESU enrollment summaries across HTML, Markdown, and Office exports.
- Fixture-backed storage snapshots are normalized through the same storage analysis pipeline as live data so reserve and posture math stay consistent across real and simulated runs.
- Tests: 18 → 27 → 28 → 41 → 42 total, including new runtime, drift detection, storage analysis, and workload/Azure collector coverage.
- CI (`validate.yml` and new `ci.yml`) now runs all 41 unit tests via `run-pester: true` and PSScriptAnalyzer via `run-psscriptanalyzer: true` on every PR and push to main. Previously tests were disabled in CI. `tests/maproom/integration/` (requires live cluster) is excluded from automated runs.

### Known Issues

- **Issue #106** — Unreachable cluster nodes are silently excluded from collection without emitting a manifest finding. Retry attempt count is not tracked in `manifest.run` metadata.
- **Issue #93** — Storage domain collection fails silently on some node configurations due to script block parsing errors for the `sofs` helper.

## [0.5.0] — 2026-04-07

### Added

- Full collector suite: topology/cluster, hardware (Dell/Redfish), storage/networking, workload/identity/Azure, monitoring, management/performance
- Manifest-first design with `audit-manifest.json`, schema contract (`manifest-schema.json` v1.1.0-draft), and runtime schema validation
- Three-tier report generation (executive, management, technical) in HTML and Markdown from cached manifest only
- 18-diagram catalog (6 baseline + 12 extended) with variant-aware selection rules and draw.io XML + SVG output
- Simulation testing framework: synthetic IIC 3-node fixture, `New-RangerSyntheticManifest.ps1`, `Test-RangerFromSyntheticManifest.ps1`
- 18 Pester tests passing: schema, degraded scenarios, cached outputs, end-to-end fixture, 7 simulation tests
- Azure authentication: existing-context, managed identity, device-code, service principal, Azure CLI fallback
- Key Vault credential resolution via `keyvault://` URI references in config
- `-OutputPath` parameter on `Invoke-AzureLocalRanger` for user-controlled export destination
- Public docs foundation under `docs/` with architecture, operator, contributor, outputs, and domain pages
- `New-AzureLocalRangerConfig`, `Export-AzureLocalRangerReport`, `Test-AzureLocalRangerPrerequisites` public commands

### Changed

- Version bumped from `0.2.0` to `0.5.0` to reflect substantial implementation completeness ahead of PSGallery `1.0.0` release
- Roadmap rewritten in versioned-milestone format (Current Release, Next Release, Post-v1 Backlog, Long-term Vision) aligned with Azure Scout pattern
- `docs/project/status.md` removed — current delivery state folded into roadmap Current Release section
- `docs/project/documentation-roadmap.md` removed — internal planning artifact no longer relevant for public docs
- `mkdocs.yml` nav updated to remove deleted pages

## [0.2.0]

### Added

- initial repository skeleton
- documentation structure for project vision, architecture, collectors, diagrams, reports, and contribution guidance
- MkDocs Material configuration and navigation tree
- placeholder implementation directories with `.gitkeep` files

### Changed

- aligned GitHub Actions workflows with repo-management standards and sibling Azure Local MkDocs repositories
- added standard GitHub support files for code ownership, pull request review, and release automation
- removed standalone MkDocs dependency file in favor of inline workflow dependency installation
- removed the completed repo restructure plan after its decisions were reflected in the live repository structure and docs
