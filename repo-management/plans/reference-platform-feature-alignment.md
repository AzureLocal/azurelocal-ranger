# Reference Platform Feature Alignment — Three-App Roadmap

**Date:** 2026-04-16  
**Apps covered:** AzureLocal Ranger, AzureLocal S2D Cartographer, Azure Scout  
**Status:** Issues filed for Ranger and S2D Cartographer. Azure Scout section is for the owner of that repo to action.

---

## How to Use This Document

- **Ranger issues** are filed under two milestones: [Platform Intelligence — Auth, Discovery & Output](#ranger--platform-intelligence-milestone) (auth, discovery, core outputs) and [Extended Collectors & WAF Intelligence](#ranger--extended-collectors--waf-intelligence-milestone) (new collectors, WAF scoring, PDF polish).
- **S2D Cartographer issues** are filed under the [S2D Cartographer milestone](#app-2-azurelocal-s2d-cartographer).
- **Azure Scout** issues are not yet filed — take this section to the Azure Scout repo and create issues there.

---

## App 1: Azure Local Ranger

### Platform Intelligence Milestone (existing — #18)

These were already filed as part of the Platform Intelligence milestone. Listed here for completeness.

| Issue | Title |
|---|---|
| [#195](https://github.com/AzureLocal/azurelocal-ranger/issues/195) | Wizard default format list wrong |
| [#196](https://github.com/AzureLocal/azurelocal-ranger/issues/196) | Auto-discover resource group from subscription + cluster name |
| [#197](https://github.com/AzureLocal/azurelocal-ranger/issues/197) | Auto-discover cluster FQDN from Azure Arc |
| [#198](https://github.com/AzureLocal/azurelocal-ranger/issues/198) | Key Vault DNS failure — hard crash, no fallback |
| [#200](https://github.com/AzureLocal/azurelocal-ranger/issues/200) | Multi-method Azure auth chain |
| [#201](https://github.com/AzureLocal/azurelocal-ranger/issues/201) | Save-AzContext / Import-AzContext for background runspaces |
| [#202](https://github.com/AzureLocal/azurelocal-ranger/issues/202) | Pre-run RBAC and resource provider permission audit |
| [#203](https://github.com/AzureLocal/azurelocal-ranger/issues/203) | WinRM TrustedHosts + DNS FQDN resolution fallback |
| [#204](https://github.com/AzureLocal/azurelocal-ranger/issues/204) | Node/VM cross-resource-group fallback lookup |
| [#205](https://github.com/AzureLocal/azurelocal-ranger/issues/205) | Azure Resource Graph single-query discovery |
| [#206](https://github.com/AzureLocal/azurelocal-ranger/issues/206) | Graceful degradation on partial Azure permissions |
| [#207](https://github.com/AzureLocal/azurelocal-ranger/issues/207) | PDF output via headless Edge/Chrome |
| [#208](https://github.com/AzureLocal/azurelocal-ranger/issues/208) | Word (DOCX) output via OOXML ZIP |
| [#209](https://github.com/AzureLocal/azurelocal-ranger/issues/209) | XLSX output via ImportExcel module |
| [#210](https://github.com/AzureLocal/azurelocal-ranger/issues/210) | Power BI CSV + star-schema manifest |
| [#211](https://github.com/AzureLocal/azurelocal-ranger/issues/211) | Invoke-AzureLocalRanger -Wizard parameter |
| [#212](https://github.com/AzureLocal/azurelocal-ranger/issues/212) | Invoke-AzureLocalRanger -SkipPreCheck parameter |
| [#213](https://github.com/AzureLocal/azurelocal-ranger/issues/213) | File-based progress IPC for background runspaces |
| [#214](https://github.com/AzureLocal/azurelocal-ranger/issues/214) | Graduated threshold scoring in waf-rules.json |

---

### Extended Collectors & WAF Intelligence Milestone (#19)

New issues filed from reference platform analysis — items not covered by Platform Intelligence.

#### Extended ARM Collectors

| Issue | Title | Priority |
|---|---|---|
| [#215](https://github.com/AzureLocal/azurelocal-ranger/issues/215) | Arc machine extension collection per node | High |
| [#216](https://github.com/AzureLocal/azurelocal-ranger/issues/216) | Logical networks and subnet detail collector | High |
| [#217](https://github.com/AzureLocal/azurelocal-ranger/issues/217) | Storage paths (CSV/SMB) collector | Medium |
| [#218](https://github.com/AzureLocal/azurelocal-ranger/issues/218) | Custom locations collector | Medium |
| [#219](https://github.com/AzureLocal/azurelocal-ranger/issues/219) | Arc Resource Bridge collector | Medium |
| [#220](https://github.com/AzureLocal/azurelocal-ranger/issues/220) | Arc Gateway collector | Low |
| [#221](https://github.com/AzureLocal/azurelocal-ranger/issues/221) | Marketplace and custom image collector | Medium |
| [#222](https://github.com/AzureLocal/azurelocal-ranger/issues/222) | Arc-licensed machine collector + Azure Hybrid Benefit detection | High |
| [#223](https://github.com/AzureLocal/azurelocal-ranger/issues/223) | VM distribution balance analysis | Low |
| [#224](https://github.com/AzureLocal/azurelocal-ranger/issues/224) | Agent version grouping and software version report | Low |

#### WAF & Scoring

| Issue | Title | Priority |
|---|---|---|
| [#225](https://github.com/AzureLocal/azurelocal-ranger/issues/225) | Weighted WAF scoring — weight 1–3, warnings = 0.5× weight | High |
| [#226](https://github.com/AzureLocal/azurelocal-ranger/issues/226) | WAF config JSON download and upload/hot-swap via CLI | Medium |

#### PDF & Output Enhancements

| Issue | Title | Priority |
|---|---|---|
| [#227](https://github.com/AzureLocal/azurelocal-ranger/issues/227) | Portrait/landscape page switching and conditional cell coloring in PDF | Medium |
| [#228](https://github.com/AzureLocal/azurelocal-ranger/issues/228) | Pricing footer with dated reference in reports | Low |
| [#229](https://github.com/AzureLocal/azurelocal-ranger/issues/229) | JSON evidence export — raw data, no assessment metadata | Medium |

#### Operational Robustness

| Issue | Title | Priority |
|---|---|---|
| [#230](https://github.com/AzureLocal/azurelocal-ranger/issues/230) | Concurrent collection guard and empty-data safeguard | Medium |
| [#231](https://github.com/AzureLocal/azurelocal-ranger/issues/231) | Module auto-install and auto-update validation on startup | Medium |

---

## App 2: AzureLocal S2D Cartographer

**Milestone:** [Reference Alignment — Visualization, Scoring & Output](https://github.com/AzureLocal/azurelocal-s2d-cartographer/milestone/13)

### WAF / Scoring

| Issue | Title | Priority |
|---|---|---|
| [#57](https://github.com/AzureLocal/azurelocal-s2d-cartographer/issues/57) | Graduated threshold scoring and partial-credit rules for health checks | High |
| [#58](https://github.com/AzureLocal/azurelocal-s2d-cartographer/issues/58) | Named calculation references — pre-computed aggregates | High |
| [#59](https://github.com/AzureLocal/azurelocal-s2d-cartographer/issues/59) | Health check config JSON download and upload/hot-swap | Medium |

### Diagrams & Visualization

| Issue | Title | Priority |
|---|---|---|
| [#60](https://github.com/AzureLocal/azurelocal-s2d-cartographer/issues/60) | vis.js interactive topology diagram | High |
| [#61](https://github.com/AzureLocal/azurelocal-s2d-cartographer/issues/61) | html2canvas diagram capture → embed in PDF and Word | Medium |

### Report Output

| Issue | Title | Priority |
|---|---|---|
| [#62](https://github.com/AzureLocal/azurelocal-s2d-cartographer/issues/62) | Page-break-aware table helper with automatic header repeat | High |
| [#63](https://github.com/AzureLocal/azurelocal-s2d-cartographer/issues/63) | Portrait/landscape page switching per PDF section | Medium |
| [#64](https://github.com/AzureLocal/azurelocal-s2d-cartographer/issues/64) | Conditional cell coloring by status and severity | Medium |
| [#65](https://github.com/AzureLocal/azurelocal-s2d-cartographer/issues/65) | JSON evidence export — raw data, no scoring metadata | Medium |
| [#68](https://github.com/AzureLocal/azurelocal-s2d-cartographer/issues/68) | Azure Hybrid Benefit and licensing cost savings calculation | High |

### Progress & UX

| Issue | Title | Priority |
|---|---|---|
| [#66](https://github.com/AzureLocal/azurelocal-s2d-cartographer/issues/66) | Full-screen progress overlay with named collection stage labels | Medium |
| [#67](https://github.com/AzureLocal/azurelocal-s2d-cartographer/issues/67) | Per-section search and filter input in HTML report | Medium |

### Operational Robustness

| Issue | Title | Priority |
|---|---|---|
| [#69](https://github.com/AzureLocal/azurelocal-s2d-cartographer/issues/69) | Concurrent collection guard and empty-data safeguards | Medium |

---

## App 3: Azure Scout

> **Action required:** Take this section to the Azure Scout repo and file issues there.  
> Issues are not yet created. Use the descriptions below as issue bodies.

### Authentication & Session

1. **Auto device-code login with no browser pop-up on headless servers**
   - On startup call `/api/auth/status`; if no context, trigger `Connect-AzAccount -UseDeviceAuthentication`. Device code appears in terminal — no browser required on server.

2. **Auth status banner — UPN and subscription name on login success**
   - Display authenticated UPN and subscription name in the dashboard header. Show yellow warning banner on auth failure.

3. **Save-AzContext / Import-AzContext for background collection runspace**
   - After login, `Save-AzContext -Path $tempFile`. Background runspace calls `Import-AzContext -Path $ctxPath` as its first action. Temp file deleted after import.

4. **Post-login management group access probe**
   - After login, call `Get-AzManagementGroup` to verify tenant-level access. Surface count in login success message. If authorization fails, emit cyan tip with required role.

5. **10-minute AbortController timeout on collection fetch**
   - Wrap the main data fetch in an AbortController with a 10-minute timeout. On timeout, surface a user-friendly message ("Collection timed out — your environment may be large. Try scoping to a specific subscription.").

---

### Resource Discovery

6. **Management Group hierarchy collection**
   - `Get-AzManagementGroup -Expand -Recurse` for full parent/child tree. Capture display name, name (code), parent, children array, type.

7. **All subscriptions with state and tags**
   - `Get-AzSubscription` with state and tag collection. Loop for per-subscription resource collection.

8. **Custom and Built-in Policy Definitions and Initiatives**
   - `Get-AzPolicyDefinition -Custom` and `-Builtin`. `Get-AzPolicySetDefinition`. Count custom only for summary totals; include built-ins for display.

9. **Policy Assignments with scope, enforcement mode, and parameters**
   - `Get-AzPolicyAssignment` — scope, enforcement mode (Default/DoNotEnforce), not-scopes, parameters.

10. **Role Assignments — display name, sign-in name, role, scope, object type**
    - `Get-AzRoleAssignment` tenant-wide.

11. **VNets, subnets, DNS servers, service endpoints, and VNet peerings**
    - `Get-AzVirtualNetwork` per subscription. Peerings from `.VirtualNetworkPeerings` property — state, forwarded traffic, gateway transit, remote address space.

12. **VPN Gateways — type, SKU, active-active, BGP**
    - `Get-AzResource -ResourceType Microsoft.Network/virtualNetworkGateways` + `Get-AzVirtualNetworkGateway`.

13. **Azure Firewalls with rule collection detail via Invoke-AzRestMethod**
    - `Get-AzFirewall`. Detect policy-based vs classic. For policy-based: `Get-AzFirewallPolicy` + `Invoke-AzRestMethod` to retrieve rule collection groups with full per-rule source/destination/protocol detail.

14. **Virtual WAN and hub collection**
    - `Get-AzVirtualWan` + hub details. Branch-to-branch and VNet-to-VNet traffic flags.

15. **Network Security Groups — rule counts and subnet/NIC associations**
    - `Get-AzNetworkSecurityGroup`. Custom rule count, default rule count, associated subnets, associated NICs.

16. **Private DNS Zones with VNet links and registration flags**
    - `Get-AzPrivateDnsZone` + `Get-AzPrivateDnsVirtualNetworkLink`. Record set count, link count, per-link registration-enabled.

17. **Private Endpoints with NIC lookup for private IPs**
    - `Get-AzPrivateEndpoint`. NIC lookup via `Invoke-AzRestMethod` for private IP addresses. Service connection group IDs and status.

18. **Cost Management Budgets**
    - `Get-AzConsumptionBudget` — amount, time grain, current spend per subscription.

19. **Resource Locks — level and notes**
    - `Get-AzResourceLock` — CanNotDelete/ReadOnly, notes, resource name.

20. **Tag aggregation — unique values per key across all subscriptions**
    - Aggregate all resource and resource group tags; group by key showing all unique values.

21. **Cross-subscription context switching with restore**
    - `Set-AzContext` per subscription mid-loop; restore original context after each sub.

22. **Module auto-install and auto-update on startup**
    - `Install-Module`/`Update-Module -Force -Scope CurrentUser` for each required Az module. PSGallery failure silently falls back to installed version.

---

### WAF / Scoring

23. **Dual scoring engine — CAF compliance + WAF alignment**
    - Two separate external JSON configs: `scoring-config.json` (7 CAF categories) and `waf-config.json` (5 WAF pillars). Computed independently; both surfaces in reports.

24. **CAF scoring — 7 categories with partial-points rules**
    - Management Group Hierarchy, Policy-Driven Governance, IAM, Network Topology, Security, Cost Management, Resource Organization. Each check can have `partialPoints.condition` and `partialPoints.points` for graduated credit.

25. **WAF pillar scoring with named calculation references and graduated thresholds**
    - Five pillars. Named aggregate metrics pre-computed from inventory (`mgCount`, `policyAssignmentCount`, `vnetCount`). `thresholds` array per check. `{variable}` interpolation in messages.

26. **WAF config hot-swap via browser file upload**
    - Upload replacement `waf-config.json` via browser file picker. Validate JSON before accepting. Re-run assessment immediately without server restart.

27. **WAF config download as JSON**
    - Download button in dashboard triggers browser download of active `waf-config.json`.

28. **Hardcoded fallback assessment when config fails to load**
    - If `waf-config.json` cannot be fetched, fall back to a hardcoded assessment function. Log warning but do not abort.

---

### Diagrams & Visualization

29. **vis.js VNet topology diagram — VNets, VMs, peering edges**
    - VNet nodes (purple box), VM nodes (SVG icon). Peering edges: green if Connected, red if not. VM-to-VNet edges: dashed, labeled with subnet name. Node tooltips show address space/location or VM size/OS/power state.

30. **Click node → Resource Details side panel**
    - Click any VNet or VM node → side panel slides in from right showing full properties. Peering row click in table also triggers side panel.

31. **Reset View and Fit to Screen diagram controls**
    - Two buttons above the diagram. Fit uses 1000ms ease-in-out-quad animation.

32. **html2canvas diagram capture → embed as PNG in PDF**
    - Capture the live vis.js canvas at 2× scale via html2canvas. Embed the PNG in the PDF export at a dedicated Architecture Diagram page.

33. **AVD-style hierarchical diagram for MG hierarchy visualization**
    - Top-down hierarchical layout showing MG → Subscription → Resource Group tree. Color-coded by level. Useful as an alternative to the VNet topology.

---

### Progress & UX

34. **Background runspace collection — HTTP listener stays responsive**
    - `[runspacefactory]::CreateRunspace()` + `BeginInvoke()`/`EndInvoke()`. Main thread keeps serving HTTP requests during long tenant scan.

35. **File-based progress IPC — runspace writes temp JSON, client polls every 800ms**
    - Background runspace writes `$env:TEMP\azscout-progress-<runId>.json` after each step. HTTP server reads and serves at `/api/progress`. Client polls at 800ms. Progress caps at 95%, jumps to 100% on complete.

36. **Named collection stages with step/totalSteps percentage**
    - Define 11+ named stages. Progress percentage = step/totalSteps × 95.

37. **Concurrent collection guard**
    - If collection already running, return `{collecting: true}`. Refresh rejects if collection in progress. Client double-polls on `{collecting: true}` before giving up.

38. **Cached inventory — serve without re-collecting**
    - If `$script:InventoryData` is non-empty, serve it immediately without triggering a new run. Refresh explicitly clears cache and progress file.

39. **Per-section search/filter inputs**
    - Text input above each table, filters `tbody tr` rows by `textContent.toLowerCase()`. Clear (×) button resets.

40. **Clickable rows → side panel (VMs, peerings)**
    - Table rows open the Resource Details side panel on click.

41. **`start.cmd` Windows batch launcher + `start.sh` for cross-platform**

---

### Report Output

42. **14 summary KPI cards on overview**
    - MGs, Subscriptions, Policy Definitions, Initiatives, Assignments, Role Assignments, VNets, Peerings, Virtual WANs, Private DNS Zones, Private Endpoints, VMs, Budgets, Locks.

43. **Full firewall policy rule drill-down**
    - Per rule collection group tree with per-rule source/destination/protocol columns. Rule type determines column layout (App rules vs Network rules vs NAT rules).

44. **Governance section — budgets table, locks table, tag chips**
    - Lock level badge: CanNotDelete = red (danger), ReadOnly = amber (warning). Tags rendered as key=value chips.

45. **Policy enforcement mode badge — Default = green, DoNotEnforce = warning**

46. **Scope truncation with full tooltip on hover**
    - Truncate ARM scope strings to 80 characters; show full path in `title` attribute.

47. **Custom `addTable()` PDF helper with page-break-aware header repeat**
    - Blue header row, alternating row fill (white/light grey), header re-renders on page break.

48. **`addSubSection()` / `addBullet()` / `getStatusEmoji()` PDF text helpers**
    - `getStatusEmoji()` maps status → `[PASS]`/`[WARN]`/`[FAIL]` (no Unicode, PDF-safe).

49. **JSON evidence export — resources only, no assessment metadata**
    - Resources-only payload with `_metadata` envelope. Explicitly excludes `bestPractices`, `summary`, `explanations`. Timestamped filename.

---

### Error Handling & Resilience

50. **Per-subscription try/catch/continue — DNS/token errors skip sub**

51. **AuthorizationFailed on MG → role requirement hint (cyan)**

52. **MG resource-provider false error swallowed**

53. **Firewall policy rule parse errors logged per rule collection group — collection continues**

54. **Empty-data guard with diagnostic hint**

55. **Pipeline HadErrors check — error messages extracted and logged as warnings**

56. **Runspace disposed in `finally` block**

57. **Client double-poll guard on `{collecting: true}` response**

---

## Testing Principles (All Apps)

1. Every feature issue specifies unit tests in its body. All unit tests must run against fixture data — no live cluster or live Azure required.
2. Integration smoke tests are documented in the issue and run against the named test environment before the issue is closed.
3. No regression: all existing passing tests must continue to pass.
4. For S2D Cartographer: use the existing maproom fixture set. Add named fixtures for new edge cases (e.g., `zero-volumes`, `unbalanced-vms`, `all-ahb-enabled`).
5. For Ranger: all new collectors must have fixture files in `tests/maproom/fixtures/`.

---

*Generated from reference platform analysis — 2026-04-16*
