# S2D Capacity Calculator — Rewrite Spec

**Source:** `S2D_Capacity_Calculator.xlsx` (15 sheets, ~880 formulas)
**Target stack:** React + TypeScript, client-side calc, no backend
**Output format:** This spec shows every formula in both Excel syntax and TypeScript translation

This document is everything an LLM (Claude Code, Cursor, Copilot) needs to scaffold a faithful web rewrite of the calculator. It is organized so you can feed the whole file — or individual section — into an agentic coding tool.

Companion files in this directory:
- `types.ts` — TypeScript interfaces for the central state (copy directly into your project)
- `formulas.ts` — shared formula primitives (copy directly into your project)
- `workbook-dump.json` — machine-readable dump of every cell, value, and formula in the source workbook (feed to agents for verification)

---

## Table of contents

1. [What the calculator does](#1-what-the-calculator-does)
2. [Architecture for the React rewrite](#2-architecture-for-the-react-rewrite)
3. [Central state (recap)](#3-central-state-recap)
4. [Data flow & dependency graph](#4-data-flow--dependency-graph)
5. [Shared formulas & helpers](#5-shared-formulas--helpers)
6. [Excel-isms and translation gotchas](#6-excel-isms-and-translation-gotchas)
7. **Per-tab breakdown:**
   - [7.1 Hardware Inputs](#71-hardware-inputs)
   - [7.2 AVD Planning](#72-avd-planning)
   - [7.3 Workload Planner](#73-workload-planner)
   - [7.4 SOFS Planner](#74-sofs-planner)
   - [7.5 Volume Detail](#75-volume-detail)
   - [7.6 Capacity Report](#76-capacity-report)
   - [7.7 Compute Report](#77-compute-report)
   - [7.8 Final Report](#78-final-report)
   - [7.9 Drive Layout Comparison](#79-drive-layout-comparison)
   - [7.10 Thin Provisioning](#710-thin-provisioning)
   - [7.11 Volume Health Check](#711-volume-health-check)
   - [7.12 Advanced Settings](#712-advanced-settings)
   - [7.13 References](#713-references)
   - [7.14 How to Use](#714-how-to-use)
   - [7.15 To Do](#715-to-do)
8. [PowerShell template strings](#8-powershell-template-strings)
9. [Validation rules (dropdown options)](#9-validation-rules-dropdown-options)
10. [Conditional formatting summary](#10-conditional-formatting-summary)
11. [Suggested React component tree](#11-suggested-react-component-tree)
12. [Test plan — parity checks](#12-test-plan--parity-checks)

---

## 1. What the calculator does

This is a pre-sales / deployment-planning tool for sizing an Azure Local (formerly Azure Stack HCI / Storage Spaces Direct) cluster. Users enter:

- **Cluster hardware:** nodes, drives, CPU, RAM
- **Workloads:** AVD session hosts + FSLogix, AKS on Azure Local, infrastructure VMs, dev/test, backup/archive, custom
- **Optional SOFS cluster** for hosting FSLogix profiles separately

The calculator returns:

- Available storage capacity after overhead/reserve/infra volume
- Per-scenario storage footprint (logical + after-resiliency pool footprint)
- Compute fit analysis (vCPU/RAM demand vs. cluster, including N+1 failover)
- A ready-to-deploy volume creation table with **both** TB (decimal, for reference) and TiB (binary, for PowerShell / WAC)
- Copy-paste PowerShell commands for volume creation
- A post-deployment audit ("Volume Health Check") that compares what was actually built to what was recommended

Critical UX intent — the entire workbook obsesses over **TB vs TiB**. Manufacturers sell drives in decimal TB; Windows/PowerShell/WAC report in binary TiB and even *label them* as "TB". The "Rosetta Stone" section on the Hardware Inputs tab exists specifically to stop the user from typing the wrong unit into `New-Volume -Size`. Preserve this in the rewrite — every volume size should show both units, with the TiB column visually highlighted (the workbook uses yellow background on those columns).

---

## 2. Architecture for the React rewrite

The workbook is actually a good fit for React. Mapping principles:

| Excel concept | React equivalent |
|---|---|
| Input cell (blue on yellow) | Controlled form input bound to state |
| Computed cell (blue on light blue) | `useMemo` selector over state |
| Cross-sheet reference (`'Hardware Inputs'!C8`) | Reading the same state field from any component |
| Dropdown (data validation) | `<select>` with a typed string union |
| Conditional formatting | Tailwind class applied from a selector |
| Merged cells / layout | Grid + flex layout, no special handling |
| Array formulas | Plain TS array reduce |
| Infrastructure volume conditional resiliency | One function, called from everywhere |

**Recommended stack inside React + TS:**

- **State:** Zustand (single store) or React Context + `useReducer`. The state shape is in `types.ts` — it's ~80 fields and flat-ish, so either works. Zustand is simpler to test and has no provider wrapping.
- **Computation:** All derived values are pure functions in `formulas.ts` + per-tab selector files (e.g. `selectors/hardware.ts`, `selectors/workload.ts`). Components call these through `useMemo`.
- **Forms:** Use controlled inputs. No need for react-hook-form — every field writes directly to the Zustand store. Validation is inline (min/max + dropdown enums from types).
- **Styling:** Tailwind. The workbook's color language (blue-on-yellow = input, green = good, red = bad, orange = caution, gray = label) maps cleanly to Tailwind utility classes. Keep it.
- **Persistence:** `localStorage` with a schema version, so a user can save a configuration and come back to it. The workbook lets users save the .xlsx; the web version should offer import/export of a JSON configuration.
- **Export:** Offer PDF export (use `react-to-pdf` or print CSS) and a "Copy PowerShell" button for the deployment commands.

**What NOT to do:**

- Do *not* build a spreadsheet grid. The workbook only uses grid layout because Excel is a grid. The rewrite should be a form-driven SPA with tab navigation. The "report" tabs become read-only summary views.
- Do *not* use a formula engine library (HyperFormula, formula.js). Translating the ~60 unique formula patterns to hand-written TS is faster, more maintainable, and eliminates a large dep.
- Do *not* store computed values in state. Only user inputs live in state; everything else is derived.

**Suggested folder layout:**

```
src/
├── state/
│   ├── store.ts              # Zustand store
│   ├── types.ts              # from this spec
│   └── defaults.ts           # DEFAULT_STATE from types.ts
├── formulas/
│   ├── index.ts              # re-exports
│   ├── core.ts               # from formulas.ts
│   ├── avd.ts                # AVD-specific selectors
│   ├── workload.ts           # Workload Planner selectors
│   ├── sofs.ts               # SOFS selectors
│   ├── volumes.ts            # Volume Detail selectors
│   └── compute.ts            # Compute math
├── tabs/
│   ├── HardwareInputs.tsx
│   ├── AvdPlanning.tsx
│   ├── WorkloadPlanner.tsx
│   ├── SofsPlanner.tsx
│   ├── VolumeDetail.tsx
│   ├── CapacityReport.tsx
│   ├── ComputeReport.tsx
│   ├── FinalReport.tsx
│   ├── DriveLayoutComparison.tsx
│   ├── ThinProvisioning.tsx
│   ├── VolumeHealthCheck.tsx
│   ├── AdvancedSettings.tsx
│   └── HowToUse.tsx
├── components/
│   ├── TabBar.tsx
│   ├── NumericInput.tsx
│   ├── DropdownInput.tsx
│   ├── StatusBadge.tsx        # PASS/FAIL/WARNING pill
│   ├── TbTibCell.tsx          # shows both units with Rosetta tooltip
│   └── PowerShellBlock.tsx    # copy-to-clipboard code block
└── App.tsx
```

---

## 3. Central state (recap)

The state shape is fully defined in `types.ts`. At a glance:

```ts
interface CalculatorState {
  hardware: HardwareInputs;          // Hardware Inputs tab
  avd: AvdInputs;                    // AVD Planning tab
  workload: WorkloadPlannerInputs;   // Workload Planner tab (non-AVD scenarios)
  sofs: SofsInputs;                  // SOFS Planner tab
  advanced: AdvancedSettings;        // Advanced Settings tab (incl. overrides)
  healthCheck: VolumeHealthCheckInputs; // Volume Health Check tab
}
```

Scenario enable flags live under `avd.enabled`, `workload.aksEnabled`, `workload.infraEnabled`, `workload.devTestEnabled`, `workload.backupEnabled`, `workload.customEnabled`, and `sofs.enabled`. Every derived formula gates on these flags — disabled scenarios return 0 for all their outputs.

---

## 4. Data flow & dependency graph

**The graph is almost entirely a DAG rooted at `hardware` and `advanced`.** Only `healthCheck` is an island (it only reads `hardware` and runs its own post-deployment audit logic).

```
Hardware Inputs ──┬──► Workload Planner ──► Volume Detail ──► Capacity Report
                  │        ▲                     │            │
                  │        │                     ▼            ▼
                  ├──► AVD Planning ─────┐  Final Report   Compute Report
                  │        │             │        ▲
                  │        ▼             │        │
                  └──► SOFS Planner ─────┘        │
                  │                               │
                  └──► Drive Layout Comparison ───┘
                  │
                  └──► Volume Health Check  (standalone — only reads Hardware)

Advanced Settings ──► (Infra volume size, capacity efficiency)
                  └─► Overrides table (optional intercept on ~35 computed fields)
```

**Calculation order** (for the `useMemo` selectors in the rewrite):

1. `hardwareDerived` — capacity drives, raw capacity, usable pool, reserve, available capacity, cluster vCPU/RAM, N+1 values
2. `advancedDerived` — infra volume footprint (depends on `hardware.nodes`), capacity efficiency factor
3. `avdDerived` — session host volume, profile volume, users/host, session hosts needed, compute demand, effective vCPU
4. `sofsDerived` — SOFS internal pool sizing (reads `hardwareDerived` + `avdDerived` for profile demand)
5. `workloadDerived` — AKS, infra, dev/test, backup, custom footprints; total footprint; remaining pool; pool utilization; compute demand totals
6. `volumeDetailRows` — one row per scenario, pulling from the above
7. `reportViews` — Capacity Report, Compute Report, Final Report, Drive Layout Comparison are all thin views over the above selectors
8. `healthCheckDerived` — independent; only reads `hardwareDerived`

---

## 5. Shared formulas & helpers

The full implementations are in `formulas.ts`. A summary of what they do and where they're used:

### 5.1 `resiliencyEfficiency(type, nodes)` → number

The single most important helper. The workbook repeats this nested IF at least **20 times** across Workload Planner, AVD Planning, SOFS Planner, Volume Detail, Drive Layout Comparison, and Final Report. Consolidate to one function. Dual Parity has a tiered efficiency based on node count:

| Resiliency | Efficiency |
|---|---|
| Two-Way Mirror | 0.5 |
| Three-Way Mirror | 1/3 (0.333) |
| Nested Two-Way Mirror | 0.25 |
| Dual Parity, nodes ≥ 16 | 0.8 |
| Dual Parity, nodes 9-15 | 0.75 |
| Dual Parity, nodes 7-8 | 2/3 (0.667) |
| Dual Parity, nodes < 7 | 0.5 |

**Excel (canonical form):**
```excel
IF(type="Three-Way Mirror",1/3,
IF(type="Two-Way Mirror",0.5,
IF(type="Dual Parity",
  IF(nodes>=16,0.8,
  IF(nodes>=9,0.75,
  IF(nodes>=7,2/3,0.5))),
IF(type="Nested Two-Way Mirror",0.25,1/3))))
```

**TS:** see `resiliencyEfficiency` in `formulas.ts`.

### 5.2 TB ↔ TiB conversion

```ts
TB_TO_TIB(tb) = tb * (1000/1024)^3  // ≈ 0.9313 TiB per TB
TIB_TO_TB(tib) = tib * (1024/1000)^3
```

**Excel equivalent:** `=tb*(1000/1024)^3` (appears ~30 times)

**⚠ Note:** `Hardware Inputs!C11` (the drive-size display helper) uses `(1000/1024)^4` instead of `^3`. This is almost certainly a bug in the source workbook — a 7.68 TB drive should be ~6.98 TiB (^3), and the workbook does output 6.98. The `^4` there multiplies by an additional 1000/1024 ≈ 0.977 which, combined with the intermediate rounding, happens to land on the same 6.98 value for common drive sizes. For all other cells the workbook uses `^3`. **In the rewrite, use `^3` everywhere** — including for the Rosetta Stone drive display.

### 5.3 Overcommit ratio parsing

The dropdown gives strings `"1:1"`, `"2:1"`, `"3:1"`, `"4:1"`. The workbook parses the first character. The TS helper just does `parseInt(ratio.split(":")[0])`.

### 5.4 Capacity pipeline

```ts
totalCapacityDrives   = nodes * capacityDrivesPerNode
totalRawCapacityTb    = totalCapacityDrives * driveSizeTb
usablePerDriveTb      = driveSizeTb * capacityEfficiencyFactor (0.92)
totalUsablePoolTb     = totalCapacityDrives * usablePerDriveTb
reserveTb             = min(nodes, 4) * usablePerDriveTb   // 1 drive per node up to 4
infraVolumeFootprintTb = infraLogical / (nodes>=3 ? 1/3 : nodes==2 ? 0.5 : 1)
availableCapacityForVolumesTb = pool - reserve - infra
```

### 5.5 Compute pipeline

```ts
logicalVCpuPerNode = physicalCores * (hyperthreading ? 2 : 1)
usableRamPerNodeGb = ramPerNodeGb - hostOsReservedGb
totalClusterVCpu   = logicalVCpuPerNode * nodes
totalClusterRamGb  = usableRamPerNodeGb * nodes
nPlusOneVCpu       = logicalVCpuPerNode * (nodes - 1)
nPlusOneRamGb      = usableRamPerNodeGb * (nodes - 1)
```

### 5.6 Generic volume footprint

```ts
footprintTb(logicalTb, resiliency, nodes) =
  logicalTb === 0
    ? 0
    : round(logicalTb / resiliencyEfficiency(resiliency, nodes), 2)
```

Used for every scenario on Workload Planner. In Excel this is inlined at every scenario total because there are no user-defined functions; in the rewrite it's one call.

### 5.7 Status/badge formulas

The workbook uses string concatenation to build status labels like `"✓ PASS — 0 of 128 vCPU (0%)"` or `"✗ FAIL"`. In the rewrite, return an object `{ status: "pass"|"fail"|"warn", message: "..." }` and render a `<StatusBadge>` component. The 70% utilization threshold appears in multiple places as a "Caution: Above 70%" intermediate state — preserve that as a distinct `"warn"` status.

---

## 6. Excel-isms and translation gotchas

Things in the workbook that don't map 1:1 and need a design decision in the rewrite:

### 6.1 Volatile `NOW()` in report timestamps

`Compute Report!B3` and `Final Report!B3` both embed `NOW()` in a "Last updated" string. In Excel this recalcs on every open; in React you want `new Date()` computed at render time, formatted with `Intl.DateTimeFormat`. Not a state field.

### 6.2 Array formula at `Workload Planner!C126`

```excel
{=(C14>0)+(C23>0)+(C54>0)+(C70>0)+(C87>0)+(C102>0)+(C109>0)
  +SUMPRODUCT(('Volume Detail'!D13:'Volume Detail'!D16>0)*1)}
```

This is just a count of enabled scenarios + non-zero SOFS volume rows. In TS it's a one-liner:
```ts
const volumeCount =
  [avdSessionHostLogical, avdProfileLogical, aksLogical, infraLogical,
   devTestLogical, backupLogical, customLogical].filter(v => v > 0).length
  + sofsVolumeRows.filter(r => r.sizeTb > 0).length;
```

### 6.3 PowerShell commands built as Excel string concatenations

`Final Report!B82:B92` generate `New-Volume ...` commands using nested `IF`, `TEXT`, `&` and literal `"""`. These are fragile in Excel and ugly to translate. In the rewrite, use a template literal function per command (see §8) that reads straight from state. Do NOT try to preserve the string-concat formulas.

### 6.4 The resiliency efficiency formula is not *quite* identical everywhere

A few instances of the nested IF have subtle differences:

- **Volume Detail H6:H12:** same pattern, but with the final fallback returning `1/3` (default if blank)
- **AVD Planning D22** (profile efficiency label): wrapped in `IF(C17<>"S2D Volume (local)","n/a", ...)` because profile resiliency doesn't apply to external storage
- **Workload Planner scenario efficiency labels (D53, D69, D86, D101, D108):** use `CONCATENATE(TEXT(..., "0%"), " eff.")` for display

Treat these as UI adapters — the underlying number comes from `resiliencyEfficiency()`. Only the string formatting differs.

### 6.5 Infrastructure volume footprint depends on node count

`Advanced Settings!C14`:
```excel
=ROUND(C13/IF('Hardware Inputs'!C8>=3,1/3,IF('Hardware Inputs'!C8=2,0.5,1)),2)
```

So a 250 GB logical infra volume becomes 0.75 TB footprint at 3+ nodes (three-way mirror), 0.50 TB at 2 nodes, or 0.25 TB at 1 node. Preserve this — it's a small but important quirk because it changes the "available capacity for volumes" at the top of Hardware Inputs.

### 6.6 `SOFS!C13` (resiliency) is a pull from `AVD Planning!C22`

SOFS uses whatever resiliency the user picks for AVD profiles. This is a design decision baked into the sheet — changing SOFS internal resiliency requires changing the AVD profile resiliency. Preserve this coupling or loosen it explicitly; don't silently separate them.

### 6.7 Override/unlock system in Advanced Settings

The workbook has a `LOCKED`/`UNLOCKED` dropdown at `Advanced Settings!C28` and a table at `B30:E73` with an `Override` column. Pattern for each row:

```excel
E31: =IF(D31<>"",D31,C31)
```

This is the "active value" of the field — use the override if set, otherwise use the normal computed value. Every downstream reference should read from `E31` (the active value). In the rewrite this is the `advanced.overrides` map in state: selectors should check `state.advanced.overrides[key]` before computing. The `LOCKED` state disables the override UI but shouldn't prevent reads (the workbook's locking is just cell protection, and Kris himself built the override section to escape that). Default `LOCKED`, show a banner when `UNLOCKED`, and require explicit unlock to enable editing.

### 6.8 `SOFS-NodeN-Vol` rows auto-expand

`Volume Detail!B13:B16` builds 4 SOFS volume rows, each gated by `'SOFS Planner'!C9>=N`:

```excel
B13: =IF('SOFS Planner'!$C$6="No","","SOFS-Node1-Vol")
B14: =IF('SOFS Planner'!$C$6="No","",IF('SOFS Planner'!C9>=2,"SOFS-Node2-Vol",""))
B15: =IF('SOFS Planner'!$C$6="No","",IF('SOFS Planner'!C9>=3,"SOFS-Node3-Vol",""))
B16: =IF('SOFS Planner'!$C$6="No","",IF('SOFS Planner'!C9>=4,"SOFS-Node4-Vol",""))
```

SOFS node count is capped at 3 in the dropdown, so row 16 never renders in practice. But the formula supports 4. In the rewrite, generate this as `Array.from({length: sofs.sofsNodes}, (_, i) => ({name: \`SOFS-Node${i+1}-Vol\`, ...}))` rather than four hand-crafted rows.

### 6.9 Dead constant `Compute Report!F23`

Cell `F23` (SOFS VMs overcommit) contains `0.04236111111111111` — this is a date fraction / formatting accident, not a real value. The row should show "1:1" as the label (SOFS VMs are not overcommitted — see the comment in the sheet). Render it as `"1:1"` in the rewrite.

### 6.10 `Workload Planner!C125` sums SOFS volume logical twice if you're not careful

```excel
C125: =C14+C23+C54+C70+C87+C102+C109+SUM('Volume Detail'!D13:'Volume Detail'!D16)
```

The SOFS volumes on Volume Detail are pulled from `SOFS Planner!C30 / sofsNodes`, so summing them across D13:D16 gives back the SOFS profile footprint. This is the "total usable logical capacity" — the SOFS contribution is the profile storage as seen from the compute cluster's side. Don't double-count.

---

(continues in section 7)

---

## 7. Per-tab breakdown

Each tab section follows the same structure:

1. **Purpose** — one-sentence summary
2. **Inputs** — user-editable fields (with dropdown options if applicable)
3. **Calculations** — every non-trivial formula, showing Excel syntax and TS translation
4. **UI intent** — what the tab *looks* like and how it should feel
5. **Notes** — gotchas specific to this tab

Cells that are pure cross-sheet pulls (e.g. `='Hardware Inputs'!C8`) are called out as "linked" without re-deriving them. Headers, labels, and cosmetic cells are omitted unless they carry computed text.

---

### 7.1 Hardware Inputs

**Purpose:** Primary cluster hardware configuration. Everything else depends on this.

**Inputs (all state → `hardware` + `advanced.capacityEfficiencyFactor`):**

| Cell | Field | Type | Default | Dropdown options |
|---|---|---|---|---|
| C8 | `nodes` | number | 3 | 1–16 |
| C9 | `driveMedia` | enum | All-NVMe (No Cache) | All-NVMe (No Cache), NVMe + SSD (NVMe is Cache) |
| C10 | `capacityDrivesPerNode` | number | 4 | free text, min 2 |
| C11 | `driveSizeTb` | number | 7.68 | free text |
| C12 | `cacheDrivesPerNode` | number | 0 | only used if NVMe+SSD |
| C13 | `defaultProvisioning` | enum | Fixed (Thick) | Fixed (Thick), Thin |
| C39 | `physicalCoresPerNode` | number | 32 | free text |
| C40 | `hyperthreading` | enum | Yes | Yes, No |
| C41 | `ramPerNodeGb` | number | 256 | free text |
| C42 | `hostOsReservedRamGb` | number | 32 | free text (typical 16-32) |

**Calculations:**

```
C11 display helper:
  Excel: =IF(C11>0,"Windows shows: "&TEXT(C11*(1000/1024)^4,"0.00")&" TiB","e.g. 1.6, 3.2, 7.68")
  TS:    driveSizeTb > 0
           ? `Windows shows: ${(TB_TO_TIB(driveSizeTb)).toFixed(2)} TiB`
           : "e.g. 1.6, 3.2, 7.68"
  Note:  Excel uses ^4 here — bug. Use TB_TO_TIB (^3) in the rewrite.

C16: Total capacity drives
  Excel: =C8*C10
  TS:    totalCapacityDrives(nodes, capacityDrivesPerNode)

C17: Cache drives
  Excel: =IF(C9="NVMe + SSD (NVMe is Cache)",C8*C12,0)
  TS:    driveMedia === "NVMe + SSD (NVMe is Cache)" ? nodes * cacheDrivesPerNode : 0

C18: Total raw capacity (TB)
  Excel: =C16*C11
  TS:    totalRawCapacityTb(totalCapacityDrives, driveSizeTb)

C19: Usable capacity per drive (TB)
  Excel: =C11*'Advanced Settings'!C8
  TS:    usableCapacityPerDriveTb(driveSizeTb, advanced.capacityEfficiencyFactor)

C20: Total usable pool before reserve (TB)
  Excel: =C16*C19
  TS:    totalUsablePoolTb(totalCapacityDrives, usablePerDriveTb)

C21: Reserve (TB)
  Excel: =MIN(C8,4)*C19
  TS:    reserveTb(nodes, usablePerDriveTb)

C22: Infrastructure volume footprint (TB)
  Excel: ='Advanced Settings'!C14
  TS:    infraVolumeFootprintTb(advanced.infraVolumeLogicalTb, nodes)

C24: AVAILABLE CAPACITY FOR VOLUMES (TB)
  Excel: =C20-C21-C22
  TS:    availableCapacityForVolumesTb(pool, reserve, infraFootprint)

C26: WAC display (TiB)
  Excel: =ROUND(C24*1000/1024,2)
  TS:    round(availableTb * (1000/1024), 2)
  Note:  ⚠ This is WRONG in the workbook too — should be ^3 not just /1024.
         It divides by 1024 once instead of (1000/1024)^3. A 62.84 TB pool
         shows "61.37 TiB" when it should show "58.52 TiB". Fix in rewrite
         by using TB_TO_TIB(availableCapacityForVolumesTb).
```

**TB vs TiB Rosetta Stone (rows 28-36):** Entirely derived cells showing the same `driveSizeTb` value rendered as vendor TB, PowerShell TiB, WAC TiB, and the yellow "New-Volume -Size" value pulled from `Volume Detail!F35`. This is a UI component, not calculations. Render as a 5-row table with the user's drive size across each representation.

**Compute capacity (rows 38-50):**

```
C45: Logical vCPU per node
  Excel: =IF(C40="Yes",C39*2,C39)
  TS:    logicalVCpuPerNode(physCores, hyperthreading === "Yes")

C46: Usable RAM per node (GB)
  Excel: =C41-C42
  TS:    usableRamPerNodeGb(ramPerNodeGb, hostOsReservedGb)

C47: Total cluster vCPU
  Excel: =C45*C8
  TS:    totalClusterVCpu(logicalVCpuPerNode, nodes)

C48: Total cluster usable RAM
  Excel: =C46*C8
  TS:    totalClusterRamGb(usableRamPerNode, nodes)

C49: N+1 vCPU
  Excel: =C45*(C8-1)
  TS:    nPlusOneVCpu(logicalVCpuPerNode, nodes)

C50: N+1 RAM
  Excel: =C46*(C8-1)
  TS:    nPlusOneRamGb(usableRamPerNode, nodes)
```

**Resiliency reference table (rows 52-60):** Static data. Render as a lookup table component. This is informational — not used in any formulas.

**UI intent:** Three-column form. Left = label, center = input/computed (colored), right = help text. Shows the Rosetta Stone prominently in a highlighted box because it's the #1 support question. Preserve the ⚠ icons and the "do NOT use this in PowerShell" warning on C24/C26.

**Notes:**
- The Rosetta Stone table (`C30:E34`) includes a reference to `'Volume Detail'!F35` (the "1 volume per node" quick-start size). This is a forward reference in the calc order but Volume Detail's F35 only depends on Hardware Inputs, so there's no cycle.
- `C11`'s `^4` is a bug — see §6.

---

### 7.2 AVD Planning

**Purpose:** Single source of truth for every AVD configuration field. Workload Planner, Compute Report, Final Report, Volume Detail, and SOFS Planner all pull from here.

**Inputs (state → `avd`):**

| Cell | Field | Type | Default | Dropdown |
|---|---|---|---|---|
| C6 | `enabled` | Yes/No | No | Yes, No |
| C9 | `sessionHostVms` | number | 32 | |
| C10 | `osDiskGb` | number | 127 | |
| C11 | `dataDiskGb` | number | 50 | |
| C12 | `hostResiliency` | resiliency | Two-Way Mirror | 4 options |
| C17 | `profileStorageLocation` | enum | S2D Volume (local) | S2D Volume (local), SOFS (separate cluster), External/Azure Files/ANF |
| C18 | `totalUsers` | number | 1300 | |
| C19 | `concurrentUsers` | number | 300 | |
| C20 | `profileSizeGb` | number | 5 | |
| C21 | `growthBuffer` | number (%) | 0.3 | |
| C22 | `profileResiliency` | resiliency | Three-Way Mirror | 4 options |
| C28 | `vcpuPerHost` | number | 8 | |
| C29 | `ramPerHostGb` | number | 32 | |
| C30 | `overcommitRatio` | enum | 4:1 | 1:1, 2:1, 3:1, 4:1 |
| C31 | `vcpuPerUser` | number | 2 | |
| C32 | `ramPerUserGb` | number | 4 | |
| C76-C78 | User type mix sizes | number | 2, 5, 15 | |
| D76-D78 | User type mix %s | number | 0.3, 0.5, 0.2 | sum should = 1.0 |
| C89 | `bandwidthPerSessionMbps` | number | 3 | |

**Calculations — Section 1 (Session Hosts):**

```
C12: Host efficiency label
  Excel: =CONCATENATE(TEXT(resiliencyEff(C12, HW!C8),"0%")," eff.")
  TS:    resiliencyEfficiencyLabel(hostResiliency, nodes)

F12: Resiliency recommendation warning
  Excel: =IF(C12=IF('Hardware Inputs'!C8>=3,"Three-Way Mirror","Two-Way Mirror"),
              "","Note: "&HW!C8&"-node cluster default = "&IF(HW!C8>=3,"Three-Way Mirror","Two-Way Mirror"))
  TS:    const recommended = nodes >= 3 ? "Three-Way Mirror" : "Two-Way Mirror";
         return hostResiliency === recommended
           ? ""
           : `Note: ${nodes}-node cluster default = ${recommended}`;

C13: Session host volume logical (TB)
  Excel: =IF($C$6="No",0,IF(C9=0,0,ROUND(C9*(C10+C11)/1024,2)))
  TS:    enabled !== "Yes" ? 0 : avdSessionHostVolumeLogicalTb(vms, osGb, dataGb)

F13: 64 TB max volume warning
  Excel: =IF(C13>64,"WARNING: Exceeds 64 TB max volume size!","")
  TS:    sessionHostLogical > 64 ? "WARNING: Exceeds 64 TB max volume size!" : ""

C14: Session host footprint in pool
  Excel: =IF(C13=0,0,ROUND(C13/resiliencyEff(C12, HW!C8),2))
  TS:    volumeFootprintTb(sessionHostLogical, hostResiliency, nodes)
```

**Calculations — Section 1 (FSLogix Profiles):**

```
D22: Profile efficiency label (or "n/a" if external)
  Excel: =IF(C17<>"S2D Volume (local)","n/a",
              CONCATENATE(TEXT(resiliencyEff(C22, HW!C8),"0%")," eff."))
  TS:    profileStorageLocation !== "S2D Volume (local)"
           ? "n/a"
           : resiliencyEfficiencyLabel(profileResiliency, nodes);

C23: Profile volume logical
  Excel: =IF($C$6="No",0,IF(C18=0,0,ROUND((C18*C20*(1+C21))/1024,2)))
  TS:    enabled !== "Yes" ? 0 : avdProfileVolumeLogicalTb(totalUsers, profileSizeGb, growthBuffer)

C24: Profile footprint in pool (0 if external storage)
  Excel: =IF(OR($C$6="No",C17<>"S2D Volume (local)"),0,
              IF(C23=0,0,ROUND(C23/resiliencyEff(C22, HW!C8),2)))
  TS:    (enabled !== "Yes" || profileStorageLocation !== "S2D Volume (local)")
           ? 0
           : volumeFootprintTb(profileLogical, profileResiliency, nodes);

C25: AVD total footprint
  Excel: =C14+C24
  TS:    sessionHostFootprint + profileFootprint
```

**Calculations — Section 1 (Compute):**

```
C33: Users per session host (max)
  Excel: =IF($C$6="No",0,MIN(INT(C28/C31),INT(C29/C32)))
  TS:    enabled !== "Yes" ? 0 : avdUsersPerSessionHost(vcpuPerHost, ramPerHost, vcpuPerUser, ramPerUser)

C34: Session hosts needed
  Excel: =IF($C$6="No",0,IF(C33=0,0,ROUNDUP(C19/C33,0)))
  TS:    enabled !== "Yes" ? 0 : avdSessionHostsNeeded(concurrentUsers, usersPerHost)

C35: Session host VM check (PASS/FAIL string)
  Excel: =IF($C$6="No","",IF(C9>=C34,"✓ PASS — "&C9&" VMs ≥ "&C34&" needed",
                               "✗ FAIL — Need "&C34&" VMs but only "&C9&" configured"))
  TS:    Return {status, message} object, render via <StatusBadge>

C36: Total AVD vCPU demand
  Excel: =IF($C$6="No",0,C9*C28)
  TS:    enabled !== "Yes" ? 0 : sessionHostVms * vcpuPerHost

C37: Total AVD RAM demand (GB)
  Excel: =IF($C$6="No",0,C9*C29)
  TS:    enabled !== "Yes" ? 0 : sessionHostVms * ramPerHost

C38: Effective vCPU (with overcommit)
  Excel: =IF($C$6="No",0,ROUND(C36/overcommitDivisor(C30),0))
  TS:    enabled !== "Yes" ? 0 : avdEffectiveVCpu(totalVCpuDemand, overcommitRatio)
```

**Calculations — Section 1 (Compute Fit Check, C41:C44):** All four are status strings with the pattern `IF(enabled!="Yes","",IF(demand<=available, pass, fail))`. Convert to `{status, message}` objects and render with `<StatusBadge>`.

**Calculations — Section 2 (Density Matrix, rows 46-57):**

```
C49: Effective vCPU per host (after overcommit)
  Excel: =C28*VALUE(LEFT(C30,FIND(":",C30)-1))
  TS:    vcpuPerHost * overcommitDivisor(overcommitRatio)

C52: Max users per host, CPU-limited (at current settings)
  Excel: =INT(C49/C31)
  TS:    Math.floor(effectiveVCpuPerHost / vcpuPerUser)

D52: Max users per host, RAM-limited
  Excel: =INT(C29/C32)
  TS:    Math.floor(ramPerHost / ramPerUser)

E52: Binding constraint
  Excel: =IF(C52<=D52,"CPU","RAM")
  TS:    cpuLimit <= ramLimit ? "CPU" : "RAM"

Sensitivity grid (rows 54-57): iterates vCPU-per-user = 2,4,6,8
  C55:F55: =INT($C$49/<col_value>)   → cpuLimited[v] = Math.floor(effectiveVCpuPerHost / v)
  C56:F56: =INT($C$29/$C$32)  (RAM constraint is constant here, just referenced)
  C57:F57: =MIN(col_cpu, col_ram)    → Math.min(cpuLimited[v], ramLimited)
```

**Calculations — Section 3 (Host Pool Scale-Out, rows 62-70):**

```
C65: Concurrency ratio
  Excel: =IF(C63>0,C64/C63,0)
  TS:    totalUsers > 0 ? concurrentUsers / totalUsers : 0

C68: Session hosts needed (concurrent)
  Excel: =IF(C66>0,ROUNDUP(C64/C66,0),0)
  TS:    usersPerHost > 0 ? Math.ceil(concurrentUsers / usersPerHost) : 0

C69: +1 host for N+1 redundancy
  Excel: =C68+1
  TS:    sessionHostsNeeded + 1

C70: Matches configured VM count?
  Excel: =IF(C69<=C9,"✅ Yes (≤"&C9&" VMs)","❌ No — need "&C69&" but only "&C9&" planned")
  TS:    StatusBadge pattern
```

**Calculations — Section 4 (FSLogix Estimator, rows 76-83):**

```
E76:E78: User count per type
  Excel: =ROUND(D76*$C$18,0)
  TS:    round(pct * totalUsers, 0)

F76:F78: Storage per type (TB)
  Excel: =ROUND(E76*C76/1024,2)
  TS:    round(count * sizeGb / 1024, 2)

D79: Mix total % (should = 1.0)
  Excel: =SUM(D76:D78)
  TS:    taskPct + knowledgePct + powerPct

E79: Total user count
  Excel: =SUM(E76:E78)

F79: Total profile storage (TB)
  Excel: =SUM(F76:F78)

C80: Weighted avg profile size (GB)
  Excel: =IF(E79>0,SUMPRODUCT(C76:C78,E76:E78)/E79,0)
  TS:    totalCount > 0
           ? (taskSizeGb*taskCount + knowledgeSizeGb*knowledgeCount + powerSizeGb*powerCount) / totalCount
           : 0

D80: Comparison to input C20
  Excel: =IF(ABS(C80-C20)<1,"✅ Matches your input (±1 GB)","⚠️ Your input uses "&C20&" GB")
  TS:    Math.abs(weightedAvg - profileSizeGb) < 1 ? "✅ Matches" : `⚠️ Your input uses ${profileSizeGb} GB`
```

**Calculations — Section 5 (Network Bandwidth, rows 89-92):**

```
C90: Concurrent sessions (linked from C19)
C91: Peak bandwidth needed (Mbps)
  Excel: =C89*C90
  TS:    bandwidthPerSession * concurrentUsers

D91: Display as Gbps
  Excel: =ROUND(C91/1000,1)&" Gbps"
  TS:    `${round(peakMbps / 1000, 1)} Gbps`

C92: Per-node bandwidth (Mbps)
  Excel: =IF(HW!C8>0,ROUND(C91/HW!C8,0),0)
  TS:    nodes > 0 ? round(peakMbps / nodes, 0) : 0

D92: Per-node status
  Excel: =IF(C92>10000,"⚠️ Exceeds 10 GbE per node",
               IF(C92>1000,"⚠️ Exceeds 1 GbE per node","✅ Within 1 GbE per node"))
  TS:    perNode > 10000 ? "⚠️ Exceeds 10 GbE"
         : perNode > 1000 ? "⚠️ Exceeds 1 GbE"
         : "✅ Within 1 GbE"
```

**Calculations — Section 6 (Gold image):** Linked values + static typical ranges. No calc beyond `C100 = C98 + C99`.

**Calculations — Section 7 (Readiness Checklist, rows 108-114):** All `IF(condition, "✅ PASS", "❌ FAIL")` + descriptive strings. Map to a list of check objects:

```ts
interface ReadinessCheck {
  label: string;
  pass: boolean;
  detail: string;
}

const checks: ReadinessCheck[] = [
  { label: "Enough VMs for concurrent users?",
    pass: sessionHostsNeededWithNPlusOne <= sessionHostVms,
    detail: `Need ${sessionHostsNeededWithNPlusOne} hosts, have ${sessionHostVms} configured` },
  { label: "User mix % totals 100%?",
    pass: Math.abs(mixTotal - 1) < 0.001,
    detail: `Task ${pct(taskPct)} + Knowledge ${pct(knowledgePct)} + Power ${pct(powerPct)}` },
  { label: "Profile storage location set?",
    pass: profileStorageLocation !== "",
    detail: profileStorageLocation === "S2D Volume (local)" ? "Profiles on cluster storage" : "External — no S2D capacity used" },
  { label: "Network bandwidth per node < 10 GbE?",
    pass: perNodeMbps <= 10000,
    detail: `${round(perNodeMbps, 0)} Mbps per node (${round(perNodeMbps/1000, 1)} Gbps)` },
  { label: "Weighted profile size ≈ input?",
    pass: Math.abs(weightedAvgGb - profileSizeGb) <= 2,
    detail: `Weighted avg: ${weightedAvgGb.toFixed(1)} GB vs input: ${profileSizeGb} GB` },
  { label: "vCPU fit (all nodes, with overcommit)?",
    pass: effectiveVCpu <= totalClusterVCpu,
    detail: `${effectiveVCpu} of ${totalClusterVCpu} vCPU (${pct(effectiveVCpu/totalClusterVCpu)})` },
  { label: "RAM fit (all nodes)?",
    pass: ramDemandGb <= totalClusterRamGb,
    detail: `${ramDemandGb} of ${totalClusterRamGb} GB (${pct(ramDemandGb/totalClusterRamGb)})` },
];
```

**UI intent:** Seven clearly numbered sections with section headers. The readiness checklist at the bottom gives a quick visual scan of "is this config valid?" — render as rows with colored status pills. The density matrix is a small 3×4 grid. Prominent "Enable AVD scenario?" toggle at top that greys out everything when No.

**Notes:**
- This tab is the heaviest and most formula-rich input tab. In React, break it into sub-components: `<AvdStorage/>`, `<AvdCompute/>`, `<AvdDensityMatrix/>`, `<AvdScaleOut/>`, `<AvdEstimator/>`, `<AvdNetwork/>`, `<AvdChecklist/>`.
- The `F12` warning should fire when a user picks a resiliency inconsistent with their node count (e.g. Two-Way Mirror on a 3-node cluster).

---

### 7.3 Workload Planner

**Purpose:** Container for all non-AVD scenarios (AKS, Infra, Dev/Test, Backup, Custom) plus the master capacity/compute summary that rolls up everything including AVD and SOFS.

**Inputs:** see `WorkloadPlannerInputs` in `types.ts`. The AVD section (rows 7-37) is entirely linked from `AVD Planning`, not edited here.

**Calculations — linked block (rows 8-37):** All pulled from AVD Planning. Display-only.

**Calculations — Scenario 2 AKS (rows 44-63):**

```
C54: AKS volume logical (TB)
  Excel: =IF($C$44="No",0,ROUND(((C47+C48)*C49/1024)+C51+C52,2))
  TS:    aksEnabled !== "Yes"
           ? 0
           : round(((controlPlaneNodes + workerNodes) * osDiskGb / 1024) + pvTb + dataServicesTb, 2)

C55: AKS total footprint (TB)
  Excel: =IF(C54=0,0,ROUND(C54/resiliencyEff(C53,HW!C8),2))
  TS:    volumeFootprintTb(aksLogical, aksResiliency, nodes)

C62: Total AKS vCPU demand
  Excel: =IF(C44="No",0,(C47*C57)+(C48*C59))
  TS:    aksEnabled !== "Yes"
           ? 0
           : controlPlaneNodes * cpVcpu + workerNodes * workerVcpu

C63: Effective AKS vCPU (with overcommit)
  Excel: =IF(C44="No",0,ROUND(((C47*C57)+(C48*C59))/overcommitDivisor(C61),0))
  TS:    aksEnabled !== "Yes" ? 0 : round(rawVCpuDemand / overcommitDivisor(aksOvercommit), 0)

AKS RAM demand (appears in row 136 as D136):
  Excel: =IF(C44="No",0,(C47*C58)+(C48*C60))
  TS:    controlPlaneNodes * cpRamGb + workerNodes * workerRamGb
```

**Calculations — Scenario 3 Infrastructure VMs (rows 66-77):**

```
C70: Infra volume logical (TB)
  Excel: =IF($C$66="No",0,IF(C67=0,0,ROUND(C67*C68/1024,2)))
  TS:    infraEnabled !== "Yes" || infraVmCount === 0
           ? 0
           : round(infraVmCount * avgDiskGb / 1024, 2)

C71: INFRA total footprint
  Excel: =IF(C70=0,0,ROUND(C70/resiliencyEff(C69,HW!C8),2))
  TS:    volumeFootprintTb(infraLogical, infraResiliency, nodes)

C76: Total infra vCPU demand
  Excel: =IF(C66="No",0,C67*C73)
  TS:    infraEnabled === "Yes" ? infraVmCount * avgVcpu : 0

C77: Effective infra vCPU
  Excel: =IF(C66="No",0,ROUND((C67*C73)/overcommitDivisor(C75),0))
  TS:    infraEnabled === "Yes" ? round(rawVCpu / overcommitDivisor(infraOvercommit), 0) : 0
```

**Calculations — Scenario 4 Dev/Test (rows 83-94):** Identical pattern to Infrastructure VMs, substituting dev/test fields.

**Calculations — Scenario 5 Backup/Archive (rows 99-103):**

```
C102: Backup volume logical
  Excel: =IF($C$99="No",0,C100)
  TS:    backupEnabled === "Yes" ? backupVolumeTb : 0

C103: Backup total footprint
  Excel: =IF(C102=0,0,ROUND(C102/resiliencyEff(C101,HW!C8),2))
  TS:    volumeFootprintTb(backupLogical, backupResiliency, nodes)
```

Note: backup has no compute demand (C99's RAM/vCPU cells in the totals at row 136+ are zero because backup VMs aren't modeled — if a customer needs Veeam VMs those go in Infrastructure or Custom).

**Calculations — Scenario 6 Custom (rows 105-110):** Same pattern as Backup. User enters raw TB + resiliency.

**Calculations — Capacity Summary (rows 113-129):**

```
C114: Available pool capacity
  Excel: ='Hardware Inputs'!C24   (linked)

C116-C122: Per-scenario footprint (linked from each scenario's total row)

C123: SOFS VM volumes footprint
  Excel: =SUM('Volume Detail'!F13:'Volume Detail'!F16)
  TS:    sofsVolumeRows.reduce((sum, r) => sum + r.footprintTb, 0)

C124: TOTAL PHYSICAL FOOTPRINT
  Excel: =SUM(C116:C123)
  TS:    sum of all 8 scenario footprints

C125: TOTAL USABLE VOLUME CAPACITY
  Excel: =C14+C23+C54+C70+C87+C102+C109+SUM('Volume Detail'!D13:'Volume Detail'!D16)
  TS:    sum of all LOGICAL volume sizes (AVD host + AVD profile + AKS + infra + devtest + backup + custom + SOFS volumes)

C126: Volume count (array formula)
  Excel: {=(C14>0)+(C23>0)+(C54>0)+(C70>0)+(C87>0)+(C102>0)+(C109>0)
            +SUMPRODUCT(('Volume Detail'!D13:'Volume Detail'!D16>0)*1)}
  TS:    const sizes = [avdHost, avdProfile, aks, infra, devTest, backup, custom];
         return sizes.filter(s => s > 0).length
              + sofsVolumeRows.filter(r => r.sizeTb > 0).length;

F126: Volume count advisory
  Excel: =IF(MOD(C126,HW!C8)=0,"Volume count is multiple of node count.",
               "Tip: Microsoft recommends multiple of node count ("&HW!C8&").")
  TS:    volumeCount % nodes === 0
           ? "Volume count is multiple of node count."
           : `Tip: Microsoft recommends multiple of node count (${nodes}).`

C128: REMAINING POOL CAPACITY
  Excel: =C114-C124
  TS:    availablePoolCapacity - totalPhysicalFootprint

F128: Remaining capacity status
  Excel: =IF(C128<0,"OVER CAPACITY!",
               IF(C124/C114>0.7,"Caution: Above 70%.","Healthy."))
  TS:    remaining < 0 ? "OVER CAPACITY!"
         : utilization > 0.7 ? "Caution: Above 70%."
         : "Healthy."

C129: Pool utilization (0-1)
  Excel: =IF(C114=0,0,C124/C114)
  TS:    pool > 0 ? footprint / pool : 0
```

**Calculations — Compute Summary (rows 131-146):**

```
C132: Cluster total vCPU   = HW!C47 (linked)
C133: Cluster total usable RAM = HW!C48 (linked)

Rows 135-139 build a per-scenario compute demand table:
  Raw vCPU | RAM (GB) | Effective vCPU (after overcommit)
  S1 AVD:     C35    | C36      | C37      (linked from AVD Planning C36, C37, C38)
  S2 AKS:     C62    | formula  | C63
  S3 Infra:   C76    | formula  | C77
  S4 DT:      C93    | formula  | C94
  SOFS VMs:  'SOFS Planner'!C46 | C47 | =C139 (SOFS not overcommitted)

D136 (AKS RAM): =IF(C44="No",0,(C47*C58)+(C48*C60))
D137 (Infra RAM): =IF(C66="No",0,C67*C74)
D138 (DevTest RAM): =IF(C83="No",0,C84*C91)

C141: TOTAL vCPU DEMAND            = SUM(C135:C139)
C142: TOTAL EFFECTIVE vCPU         = SUM(E135:E138)+C139    // note: SOFS not reduced
C143: TOTAL RAM DEMAND             = SUM(D135:D139)

C145: REMAINING vCPU               = C132 - C141
C146: REMAINING RAM                = C133 - C143

F145/F146: Status messages, same 70% / OVER CAPACITY / Healthy pattern
```

**Calculations — N+1 Failover Check (rows 148-152):**

```
C149: N+1 vCPU available = HW!C49 (linked)
C150: N+1 RAM available  = HW!C50 (linked)

C151: N+1 vCPU fit
  Excel: =IF(C141<=C149,"✓ PASS — "&C141&" of "&C149&" vCPU ("&ROUND(C141/C149*100,0)&"%)",
                          "✗ FAIL — Need "&C141&" but N+1 only has "&C149&" vCPU")
  TS:    StatusBadge with message template

C152: N+1 RAM fit — same pattern with C143/C150
```

**Calculations — Overcommit Sensitivity (rows 155-159):**

```
For each ratio in [1:1, 2:1, 3:1, 4:1]:
  C156-C159: AVD effective vCPU at that ratio
    Excel: =IF(C8="No",0,ROUND(C35/ratio,0))
    TS:    avdEnabled === "Yes" ? round(avdRawVcpuDemand / ratio, 0) : 0

  D156-D159: Total effective vCPU at that ratio
    Excel: =C156+E136+E137+E138+E139
    TS:    avdEff + aksEff + infraEff + devTestEff + sofsVCpu

  E156-E159: Fit check (all nodes)
    Excel: =IF(D_<=HW!C47,"✓ PASS","✗ FAIL")
    TS:    total <= totalClusterVCpu ? "pass" : "fail"

  F156-F159: Fit check (N+1)
    Excel: =IF(D_<=HW!C49,"✓ PASS","✗ FAIL")
    TS:    total <= nPlusOneVCpu ? "pass" : "fail"
```

The point of this table is to show the user which overcommit ratio their cluster can actually sustain. Render as a 4-row table.

**UI intent:** Scenario accordions (one per S2-S6). Each accordion has an Enable toggle at the top. When collapsed/disabled, show the scenario name and a "— Disabled" pill. When enabled, show the full input form for that scenario. Below the accordions, a prominent "Capacity Summary" card showing pool utilization as a progress bar (green < 70%, yellow 70-100%, red > 100%). Then a "Compute Summary" card with vCPU/RAM fit bars. Then the N+1 check, then the overcommit sensitivity table.

**Notes:**
- The AVD section at the top (rows 7-37) is entirely read-only — all fields are pulled from AVD Planning. Render as a collapsed summary card with a "Edit in AVD Planning →" link.
- Row 161 has a note: "Hyper-V supports vCPU overcommit (standard for AVD). Memory is NOT overcommitted." Keep this as a permanent footer.

---

### 7.4 SOFS Planner

**Purpose:** Sizes a *separate* SOFS cluster (not the Azure Local compute cluster) for hosting FSLogix profile containers via CA SMB shares. Only relevant when the user sets AVD Planning!C17 to "SOFS (separate cluster)" — otherwise this tab is informational.

**Inputs (state → `sofs`):** see `types.ts`.

**Calculations:**

```
C11: Drive capacity (auto-calculated, back-solved from profile demand)
  Excel: =IF($C$6="No",0,IF(C30=0,0,ROUNDUP(C30/(C9*C10*C19*C14-1),2)))
  TS:    if (!enabled || profileFootprint === 0) return 0;
         return roundUp(profileFootprint / (sofsNodes * drivesPerNode * resiliencyEff * capEffFactor - 1), 2);
  Note:  This is an inverse sizing formula — given the profile demand, tell the
         user what drive size they need in each SOFS node. The "-1" subtracts
         the 1-drive-per-node reserve. ROUNDUP means "round up to nearest 0.01 TB".

C13: Resiliency (linked from AVD Planning C22)
  Excel: =IF($C$6="No","",'AVD Planning'!C22)
  TS:    enabled ? avd.profileResiliency : ""

C18: Total raw capacity
  Excel: =IF($C$6="No",0,C9*C10*C11)
  TS:    enabled ? sofsNodes * drivesPerNode * driveCapacity : 0

C19: Resiliency efficiency
  Excel: same nested IF as elsewhere, but using SOFS's own C9 for node count
  TS:    enabled ? resiliencyEfficiency(sofsResiliency, sofsNodes) : 0

C20: Usable capacity (after resiliency + overhead)
  Excel: =IF($C$6="No",0,ROUND(C18*C19*C14,2))
  TS:    enabled ? round(raw * eff * capEffFactor, 2) : 0

C21: Drive reserve = largest drive capacity
  Excel: =IF($C$6="No",0,C11)
  TS:    enabled ? driveCapacity : 0

C22: Available for volumes
  Excel: =IF($C$6="No",0,MAX(0,ROUND(C20-C21,2)))
  TS:    enabled ? Math.max(0, round(usable - reserve, 2)) : 0
```

**FSLogix Profile Demand (rows 25-32):**

```
C26-C28: Linked from Workload Planner C18, C20, C21

C29: Profile logical demand
  Excel: =IF($C$6="No",0,ROUND((C26*C27*(1+C28))/1024,2))
  TS:    enabled ? sofsProfileLogicalDemandTb(users, profileSizeGb, growthBuffer) : 0

C30: Profile footprint on SOFS (after resiliency)
  Excel: =IF($C$6="No",0,IF(C19=0,0,ROUND(C29/C19,2)))
  TS:    enabled ? sofsProfileFootprintTb(logical, resiliency, sofsNodes) : 0

C31: Remaining SOFS capacity after profiles
  Excel: =IF($C$6="No",0,ROUND(C22-C30,2))
  TS:    enabled ? round(available - footprint, 2) : 0

C32: Capacity utilization
  Excel: =IF($C$6="No",0,IF(C22=0,0,C30/C22))
  TS:    enabled && available > 0 ? footprint / available : 0
```

**IOPS Estimate (rows 35-40):**

```
C37: Concurrent users (linked from Workload Planner!C19)

C39: Steady-state total IOPS
  Excel: =IF($C$6="No",0,C37*C35*IF(C15="Split",3,1))
  TS:    sofsSteadyIops(concurrent, steadyPerUser, containerType)

C40: Peak storm IOPS
  Excel: =IF($C$6="No",0,ROUND(((C37*(1-C38)*C35)+(C37*C38*C36))*IF(C15="Split",3,1),0))
  TS:    sofsPeakStormIops(concurrent, stormPct, steadyPerUser, stormPerUser, containerType)
```

Split containers triple IOPS because FSLogix creates 3 VHDs per user (profile, Office/ODFC, other) instead of 1.

**SOFS VM Compute (rows 43-47):**

```
C45: SOFS VM count
  Excel: =IF($C$6="No",0,C9)
  TS:    enabled ? sofsNodes : 0

C46: Total SOFS vCPU demand
  Excel: =IF($C$6="No",0,C45*C43)
  TS:    enabled ? sofsNodes * vcpuPerSofsVm : 0

C47: Total SOFS RAM demand
  Excel: =IF($C$6="No",0,C45*C44)
  TS:    enabled ? sofsNodes * ramPerSofsVmGb : 0
```

**Readiness Checklist (rows 51-54):** Four checks, same pattern:

```
C51: Capacity: SOFS can hold all profiles?
  TS:    !enabled ? "N/A" : remainingSofsCapacity >= 0 ? "PASS" : "FAIL"

C52: Utilization under 80%?
  TS:    !enabled ? "N/A" : utilization <= 0.8 ? "PASS" : "FAIL"

C53: Node count matches resiliency type?
  Excel: =IF($C$6="No","N/A",
          IF(OR(
            AND(C13="Two-Way Mirror",C9>=2),
            AND(C13="Three-Way Mirror",C9>=3),
            AND(C13="Dual Parity",C9>=4),
            AND(C13="Nested Two-Way Mirror",C9>=4)
          ),"PASS","FAIL"))
  TS:    !enabled ? "N/A" : sofsNodes >= resiliencyMinNodes(sofsResiliency) ? "PASS" : "FAIL"

C54: Separate cluster check (always returns "VERIFY")
  Excel: =IF($C$6="No","N/A","VERIFY")
  TS:    enabled ? "VERIFY" : "N/A"
  Note:  This one can't be auto-checked — it requires the user to confirm SOFS
         is on a separate cluster. Render as a manual checkbox.
```

**Static notes (rows 57-61):** 5 informational sentences about Microsoft support boundaries for SOFS. Render as an expandable `<Callout variant="info">`.

**UI intent:** Enable toggle at top. When disabled, show one sentence: "SOFS is only relevant when AVD profiles use a separate file server cluster. Set 'Profile storage location' to 'SOFS (separate cluster)' in AVD Planning to use this tab." When enabled, three cards: Cluster Hardware, FSLogix Demand, IOPS Estimate. Then the compute sub-card and the readiness checklist.

**Notes:**
- `C11` is the unusual cell on this tab — it's an inverse solve for drive size given the profile demand. Users can't edit it; it's auto-calculated. In the UI, show as a "Recommended drive size: X TB" card, not an input.
- SOFS dropdown for `sofsNodes` is restricted to `2, 3` in the source workbook. Matches Microsoft's SOFS guidance.


---

### 7.5 Volume Detail

**Purpose:** Per-volume deployment reference table. This is what the user copies into WAC or PowerShell to actually create volumes. Also includes a "Quick-Start" section that ignores the workload planning entirely and just proposes one volume per node sized to fill the pool.

**Inputs:** None. This tab is 100% derived.

**Calculations — Per-scenario table (rows 6-16):**

Each row is a one-liner that pulls the scenario's name, resiliency, logical size, and footprint from Workload Planner, then computes:

- **Column D (Calculator Only, TB):** linked from workload planner logical size
- **Column E (ENTER IN WAC/PS, TiB):** `=IF(D=0,0,ROUND(D*(1000/1024)^3,2))` → `TB_TO_TIB(logicalTb)` rounded to 2
- **Column F (Pool Footprint, TB):** linked from workload planner footprint
- **Column G (Copies):** `=IF(C="Two-Way Mirror","2x",IF(C="Three-Way Mirror","3x","parity"))` → `resiliencyCopies(resiliency)`
- **Column H (Efficiency):** resiliencyEfficiency(...)
- **Column I (Status):** `=IF(D=0,"— Disabled",IF(D>64,"FAIL: >64 TB","PASS"))`

Rows 6-12 are hand-coded scenarios (AVD-SessionHosts, AVD-Profiles, AKS-Cluster, Infra-VMs, DevTest-VMs, Backup-Archive, Custom). Rows 13-16 are SOFS volumes, each gated on `sofs.enabled && sofs.sofsNodes >= N`:

```
Row 13: always visible if SOFS enabled (SOFS-Node1-Vol)
Row 14: visible if sofs.sofsNodes >= 2
Row 15: visible if sofs.sofsNodes >= 3
Row 16: visible if sofs.sofsNodes >= 4 (unreachable in current dropdown)

SOFS volume size per row = 'SOFS Planner'!C30 / 'SOFS Planner'!C9
(profile footprint divided evenly across SOFS nodes)
```

**In the rewrite:** Generate this as a single array of `VolumeRow` objects:

```ts
interface VolumeRow {
  name: string;
  resiliency: ResiliencyType;
  logicalTb: number;      // calculator only
  sizeTib: number;        // ← USE THIS in WAC/PS
  footprintTb: number;
  copies: "2x" | "3x" | "parity";
  efficiency: number;
  status: "pass" | "fail" | "disabled";
  enabled: boolean;       // false if logicalTb === 0
}

function volumeRows(state: CalculatorState): VolumeRow[] {
  const rows: VolumeRow[] = [];
  // AVD, AKS, Infra, DevTest, Backup, Custom (7 rows)
  // + N SOFS rows where N = state.sofs.enabled ? state.sofs.sofsNodes : 0
  return rows;
}
```

Render as a table. The E column must be visually distinct (yellow background in the workbook) — this is the WAC/PS-correct value. Add a tooltip: "PowerShell's -Size parameter uses TiB despite saying 'TB'. Use this value."

**Calculations — Totals row (23):**

```
D23: =SUM(D6:D16)
E23: =SUM(E6:E16)
F23: =SUM(F6:F16)
I23: =COUNTIF(I6:I16,"PASS")&" of "&COUNTIF(I6:I16,"<>"&"— Disabled")&" PASS"
  TS: const enabled = rows.filter(r => r.status !== "disabled");
      const passing = enabled.filter(r => r.status === "pass");
      return `${passing.length} of ${enabled.length} PASS`;
```

**Fit Check (row 26):**

```
B26: =IF('Workload Planner'!C128<0,
         "FAIL: Exceeds pool by "&TEXT(ABS('Workload Planner'!C128),"0.00")&" TB. Remove workloads or add drives.",
         IF('Workload Planner'!C129>0.7,
           "WARNING: "&TEXT('Workload Planner'!C129,"0.0%")&" utilization — limited rebuild headroom.",
           "PASS: "&TEXT('Workload Planner'!C129,"0.0%")&" utilized. Healthy headroom for drive failure repair."))
TS: if (remaining < 0) return {status: "fail", message: `Exceeds pool by ${abs(remaining).toFixed(2)} TB. Remove workloads or add drives.`};
    if (utilization > 0.7) return {status: "warn", message: `${pct(utilization, 1)} utilization — limited rebuild headroom.`};
    return {status: "pass", message: `${pct(utilization, 1)} utilized. Healthy headroom for drive failure repair.`};
```

**Quick-Start Volumes (rows 31-43):** A separate section that proposes "1 volume per node" (Microsoft's default best practice, up to 4 nodes), ignoring the workload planning entirely. Useful for just showing "here's what you *could* do with this hardware".

```
B35: Label
  Excel: ='Hardware Inputs'!C8&" volumes (1 per node)"
  TS:    `${nodes} volumes (1 per node)`

C35: Volume count = HW!C8
D35: Resiliency
  Excel: =IF(HW!C8>=3,"Three-Way Mirror",IF(HW!C8=2,"Two-Way Mirror","Two-Way Mirror"))
  TS:    nodes >= 3 ? "Three-Way Mirror" : "Two-Way Mirror"

E35: Calculator TB per volume
  Excel: =IF(C35=0,0,MIN(64,ROUNDDOWN('Advanced Settings'!E35 * resiliencyEff(D35, HW!C8) / C35, 2)))
  TS:    const cap = advanced.overrides.availableCapacityForVolumesTb ?? hardware.availableCapacityForVolumesTb;
         if (count === 0) return 0;
         return Math.min(64, roundDown(cap * resiliencyEfficiency(resiliency, nodes) / count, 2));
  Note:  Notice this uses `Advanced Settings!E35` (the override-aware active value)
         rather than Hardware Inputs!C24 directly. In the rewrite, always read
         capacity through the override layer.

F35: TiB per volume (the one users type into PowerShell)
  Excel: =IF(E35=0,0,ROUND(E35*(1000/1024)^3,2))
  TS:    TB_TO_TIB(tbPerVolume) rounded to 2

G35: Pool footprint
  Excel: =IF(E35=0,0,ROUND(C35*E35/resiliencyEff(D35,HW!C8),2))
  TS:    count * tbPerVolume / resiliencyEfficiency(resiliency, nodes)

H35: Usable total (TB)
  Excel: =IF(E35=0,0,ROUND(C35*E35,2))
  TS:    count * tbPerVolume

I35: Fits?
  Excel: =IF(G35=0,"",IF(G35<='Advanced Settings'!E35,"PASS","OVER"))
  TS:    footprint <= availableCapacity ? "pass" : "over"
```

**Quick-Start PowerShell (rows 41-43):** Generates a one-liner `New-Volume` command. See §8 for the full template handling.

**UI intent:** Two sections. (1) Workload-based table — rendered from `volumeRows(state)`. (2) Quick-Start card — a separate collapsible panel showing "If you don't want to plan specific workloads, here's a balanced default." The yellow TiB column is the hero of both sections — call it out visually.

**Notes:**
- Volume Detail is the single most important output of the calculator from a user's perspective. They read this tab and run PowerShell. Make the UI unambiguous.
- The 64 TB per-volume cap is a hard Microsoft limit. Don't let a single volume exceed it.

---

### 7.6 Capacity Report

**Purpose:** One-page executive summary of storage capacity. Printed and shared with customers.

**Inputs:** None. All linked.

**Calculations:** Every cell is a link to Hardware Inputs or Workload Planner. No new math. See `workbook-dump.json` for the exact mapping.

**Structure:**
- **Executive Summary (rows 4-18):** Cluster Nodes, Drive Config, Capacity Drives, Drive Size, Raw Capacity, After Overhead, Pool Reserve, Infra Volume, AVAILABLE POOL, WAC Display, Workload Footprint, Usable Volume Capacity, Remaining Free, Pool Utilization.
- **Capacity Terms glossary (rows 20-30):** Static definitions of raw/usable/pool/reserve/infra/available/volume size/footprint/efficiency/TB vs TiB. Copy verbatim as help text.
- **Why Reserve Is Critical (rows 32-35):** 3 sentences explaining drive failure → rebuild → why reserve matters.
- **Drive Sizing Advisory (rows 37-42):** 5 tips about smaller vs larger drives.

**UI intent:** Single-column report view with large numbers for the key metrics. Include a "Print" button. Consider using Tailwind's `@media print` classes to hide navigation when printing.

**Notes:**
- This tab is 100% read-only. Implement as a dumb presentational component that takes `state` via the store and renders.
- Row 30 contains the critical TB vs TiB warning. Make it a bright callout.

---

### 7.7 Compute Report

**Purpose:** Compute-specific analog of the Capacity Report. Shows vCPU and RAM demand by scenario plus N+1 failover analysis.

**Inputs:** None. All linked.

**Calculations:**

```
B3: Last updated timestamp
  Excel: ="All values linked... Last updated: "&TEXT(NOW(),"mm/dd/yyyy hh:mm AM/PM")
  TS:    `All values linked to Hardware Inputs and Workload Planner tabs. Last updated: ${formatDateTime(new Date())}`
  Note:  Compute at render time, NOT stored in state.

Rows 5-15: linked from Hardware Inputs (nodes, cores, HT, vCPU, RAM, etc.)
Rows 19-23: per-scenario demand (linked from Workload Planner rows 135-139)
  One row per enabled scenario, showing: Status | vCPU | RAM | Overcommit | Eff. vCPU

F23 SOFS overcommit display:
  Excel: 0.04236111111111111  (dead constant — see §6.9)
  TS:    render literal string "1:1" (SOFS VMs are not overcommitted)

Row 24: TOTALS = SUM(D19:D23), SUM(E19:E23), SUM(G19:G23)

Row 27: REMAINING vCPU
  Excel: =C11-G24
  TS:    totalClusterVCpu - totalEffectiveVCpu

Row 28: vCPU Utilization
  Excel: =IF(C11=0,0,G24/C11)
  TS:    totalClusterVCpu > 0 ? totalEffectiveVCpu / totalClusterVCpu : 0

Row 30-31: same pattern for RAM

Rows 33-38: N+1 Failover Analysis table
  Check | Demand | Available | Utilization | Status | Headroom
  vCPU all nodes, RAM all nodes, N+1 vCPU (1 node down), N+1 RAM (1 node down)

Rows 40-49: AVD Session Host Detail — mostly linked; notable:
  F43: User type label
    Excel: =IF(WP!C30<=1,"Light user",IF(WP!C30<=2,"Medium user","Power user"))
    TS:    vcpuPerUser <= 1 ? "Light user" : vcpuPerUser <= 2 ? "Medium user" : "Power user"

  F45: Bottleneck label (vCPU or RAM)
    Excel: If CPU limit < RAM limit, "vCPU"; else if CPU limit > RAM limit, "RAM"; else balanced
    TS:    cpuLimit < ramLimit ? "Bottleneck: vCPU"
           : cpuLimit > ramLimit ? "Bottleneck: RAM"
           : "Balanced"

  F48: Math description
    Excel: ="⌈ "&WP!C19&" users ÷ "&WP!C32&" users/host ⌉"
    TS:    `⌈ ${concurrentUsers} users ÷ ${usersPerHost} users/host ⌉`

Rows 51-56: vCPU Overcommit Sensitivity — linked from Workload Planner rows 155-159
```

**UI intent:** Similar to Capacity Report — dense text summary with status pills. The per-scenario demand table and the sensitivity table are the main visual elements. Again, print-friendly layout.

---

### 7.8 Final Report

**Purpose:** Comprehensive one-page summary combining capacity + compute. This is the "print and email to the customer" deliverable.

**Inputs:** None. All linked. 238 formulas but every one is a cross-sheet pull or a minor transformation.

**Sections:**

1. **Section 1: Cluster Hardware Summary (rows 5-15)** — linked from Hardware Inputs. Notable cells add a "(WAC shows: X TiB)" companion display using `TB_TO_TIB`.

2. **Section 2: Capacity Allocation (rows 17-27)** — linked from Workload Planner C124-C129 plus a `C25` status formula:
   ```
   C25: =IF('Workload Planner'!C128<0,"FAIL — OVER CAPACITY",
              IF('Workload Planner'!C129>0.7,"WARNING — Above 70% utilization",
                "PASS — Healthy headroom"))
   ```

3. **Section 3: Scenario Breakdown (rows 41-51)** — a table with one row per scenario showing Status, Resiliency, Logical TB, Efficiency, Footprint TB. Every cell is an `IF` that either shows a linked value or "—" for disabled scenarios. The row pattern:

   ```
   C43: =IF('Workload Planner'!C14>0,"Enabled","— Disabled")
   D43: ='Workload Planner'!C13
   E43: =IF(C43="— Disabled","—",'Workload Planner'!C14)
   F43: ='Workload Planner'!D13
   G43: =IF(C43="— Disabled","—",'Workload Planner'!C15)
   ```

   In the rewrite, render as a single table mapped from an array of scenario metadata. The "Enabled" check uses whether the logical value > 0 (not the enable flag directly) — this is important because AVD can be enabled but have zero logical (if `sessionHostVms === 0`).

4. **Scenario Input Details (rows 52-63):** Linked inputs for the enabled scenarios, each with a `(Disabled)` fallback string. Render as collapsible cards, one per scenario, hidden when disabled.

5. **Section 4: Volume Creation Table (rows 65-78):** A clone of Volume Detail's main table, with the addition of PowerShell command generation below.

6. **PowerShell Volume Creation Commands (rows 81-92):** See §8.

7. **Section 5: Drive Layout Insight (rows 97-110):** Pulls from Drive Layout Comparison tab. Shows "Your Current" vs "Best Alternative" (more drives = less reserve).

8. **Section 6: Best Practice Notes (rows 112-122):** 5 auto-generated notes based on the current config:

   ```
   C114: Volume count advisory
     Excel: ="Your current volume count: "&'Workload Planner'!C126&" volumes across "&HW!C8&" nodes. "&
            IF(MOD('Workload Planner'!C126,HW!C8)=0,"✓ Multiple of node count.","Consider adjusting for balance.")

   C115-C116: Rebuild headroom
     C115: ="Keep pool utilization below 70% to ensure... Current: "&TEXT(utilization,"0.0%")&"."
     C116: =IF(utilization>0.7,"⚠ Above 70% — limited rebuild headroom","✓ Healthy headroom")

   C117-C118: Provisioning advice
     C117: ="Default provisioning: "&provisioning&". Fixed (thick) is STRONGLY recommended..."
     C118: =IF(provisioning="Fixed (Thick)","✓ Using recommended Fixed","⚠ Thin detected — monitor pool usage closely")

   C119-C120: N+1 compute reminder
     C119: ="Size VM workloads to fit on "&(nodes-1)&" of "&nodes&" nodes..."
     C120: ="Plan for "&(nodes-1)&"-node compute capacity..."

   C121-C122: 64 TB volume size limit check
     C121: ="Maximum single volume size: 64 TB. Current largest volume: "&TEXT(MAX(...),"0.00")&" TB."
     C122: =IF(MAX(...)>64,"⚠ WARNING: A volume exceeds 64 TB!","✓ All volumes within 64 TB limit.")
   ```

   In the rewrite, extract a `bestPracticeNotes(state): Note[]` selector that returns an array of `{level: "info"|"warn", message: string}`.

9. **Section 7: Compute Capacity Analysis (rows 124-159):** A compressed version of Compute Report. Same linked data, same sensitivity table. Render as reusable component.

**UI intent:** Long scrollable report with section anchors at the top. Printing is the primary use case. Include a "Copy all PowerShell commands" button at the top of section 4.

**Notes:**
- The volume count status (`C114`) has a subtle bug in the source formula: it uses `MOD` which returns 0 when volumes === 0, so an empty plan always says "✓ Multiple of node count." Consider adding `IF(count=0,"No volumes planned",...)` in the rewrite.

---

### 7.9 Drive Layout Comparison

**Purpose:** "What-if" tool — same total raw capacity, different drive counts per node. Shows that smaller drives mean smaller reserve and more available capacity.

**Inputs:** None editable on this tab. Reads Hardware Inputs for nodes and raw capacity, then builds a fixed table of alternatives.

**Calculations:**

```
Row 14 (CURRENT):
  B14: =C7 (drives per node)
  C14: =C8 (drive size)
  D14: =B14*C6 (total drives = drives/node * nodes)
  E14: =C14*C10 (usable per drive)
  F14: =MIN(C6,4)*E14 (reserve)
  G14: =(D14*E14)-F14-'Advanced Settings'!C14 (available)
  H14: "← Current" (label)

Rows 15-21 (ALTERNATIVES): drives/node = 4, 5, 6, 7, 8, 9, 10
  For each N:
    B: N (drives per node, hardcoded)
    C: =ROUND($C$9/(B*$C$6),2) (calculated drive size = raw / (N * nodes))
    D: =B*$C$6 (total drives)
    E: =C*$C$10 (usable per drive)
    F: =MIN($C$6,4)*E (reserve)
    G: =(D*E)-F-'Advanced Settings'!$C$14 (available)
    H: =G - $G$14 (delta vs current)
```

This table is entirely derivable — in the rewrite, use `driveLayoutAlternative()` from `formulas.ts`:

```ts
const alternatives = [4, 5, 6, 7, 8, 9, 10].map(drivesPerNode =>
  driveLayoutAlternative(
    drivesPerNode,
    hardware.totalRawCapacityTb,
    hardware.nodes,
    advanced.capacityEfficiencyFactor,
    advanced.infraVolumeFootprintTb
  )
);
```

**UI intent:** One table. Highlight the current row. Let the user see at a glance "if I bought 6 drives/node instead of 4, I'd gain 7 TB of available capacity." Add a note that calculated drive sizes are theoretical — actual drives come in standard sizes (1.6, 3.2, 3.84, 7.68 TB).

---

### 7.10 Thin Provisioning

**Purpose:** Static educational content explaining when thin provisioning is acceptable, its risks, monitoring commands, and a checklist.

**Inputs:** None.
**Calculations:** None — this tab has zero formulas.

**UI intent:** A pure content page. Render as markdown or structured React with sections: "Default: Use Fixed", "When Thin Is Acceptable", "Risks", "Monitoring", "Checklist". Include a callout at the bottom linking to Volume Health Check: *"Already created volumes? Use the Volume Health Check tab to compare what you built vs. what's recommended."*

Verbatim content is in `workbook-dump.json`. Alternatively, move to a standalone `.mdx` file in the React project for easier editing.

---

### 7.11 Volume Health Check

**Purpose:** Post-deployment audit. User enters the volumes they actually created (count, size, resiliency, provisioning, actual data used) and the calculator tells them whether they preserved enough reserve for drive-failure rebuild.

**Inputs (state → `healthCheck`):**

| Cell | Field | Type | Default | Dropdown |
|---|---|---|---|---|
| C11 | `actualVolumeCount` | number | 3 | |
| C12 | `actualVolumeSizeTib` | number (TiB) | 8 | |
| C13 | `actualResiliency` | enum | Three-Way Mirror | Three-Way Mirror, Two-Way Mirror, Dual Parity |
| C14 | `actualProvisioning` | enum | Fixed | Thin, Fixed |
| C15 | `actualDataPerVolumeTib` | number (TiB) | 2 | |

**Calculations:**

```
Hardware (rows 5-8, linked from Hardware Inputs)

C12 helper string:
  Excel: ="WAC/PS shows TiB. Your "&TEXT(C12,"0.00")&" TiB = "&TEXT(C12*(1024/1000)^3,"0.00")&" TB (decimal)..."
  TS:    `WAC/PS shows TiB. Your ${sizeTib.toFixed(2)} TiB = ${TIB_TO_TB(sizeTib).toFixed(2)} TB (decimal)...`

Recommended (rows 18-22):
  C18: =C5 (recommended volume count = node count)
  C19: ='Volume Detail'!F35 (recommended TiB per volume from Quick-Start)
  C20: ='Volume Detail'!G35 (recommended pool footprint)
  C21: ='Volume Detail'!H35 (recommended usable total)
  C22: "✅ YES" (hardcoded — Quick-Start preserves full reserve by design)

Actual calculations (rows 25-30):
  C25: Mirror multiplier
    Excel: =IF(C13="Three-Way Mirror",3,IF(C13="Two-Way Mirror",2,IF(C13="Dual Parity","varies","?")))
    TS:    actualResiliency === "Three-Way Mirror" ? 3
           : actualResiliency === "Two-Way Mirror" ? 2
           : "varies"  // Dual Parity

  C27: Total usable data (TiB)
    Excel: =C11*C12
    TS:    volumeCount * volumeSizeTib

  C28: Pool footprint — volumes (TiB)
    Excel: =IF(C13="Dual Parity","N/A — see docs",C11*C12*C25)
    TS:    actualResiliency === "Dual Parity" ? "N/A" : volumeCount * volumeSizeTib * multiplier

  C29: Infra volume footprint (TiB)
    Excel: =ROUND(E7*(1000/1024)^3,2)
    TS:    round(TB_TO_TIB(infraFootprintTb), 2)

  C30: Total pool consumed (TiB)
    Excel: =IF(ISNUMBER(C28),C28+C29,"N/A")
    TS:    typeof volumesFootprintTib === "number" ? volumesFootprintTib + infraTib : "N/A"

Reserve impact matrix (rows 33-39): 3 columns
  Column C: FIXED provisioning (what you have now)
  Column D: THIN provisioning right now (before volumes fill)
  Column E: THIN when volumes fill up

  C34: Total pool TiB = TB_TO_TIB(totalUsablePool)
  D34: =C34 (same)
  E34: =C34 (same)

  C35: Pool consumed
    Excel: =C30
    TS:    totalPoolConsumed

  D35: Pool consumed (thin, right now)
    Excel: =IF(ISNUMBER(C25),C11*C15*C25+C29,"N/A")
    TS:    volumeCount * actualDataPerVolumeTib * multiplier + infraTib
    Note:  Uses ACTUAL data, not provisioned size. This is the key difference —
           thin volumes only consume what they actually have data in.

  E35: Pool consumed (thin, full) = C35

  C36: Designed reserve TiB = TB_TO_TIB(reserveTb)
  D36/E36: =C36 (same)

  C37: Actual remaining reserve
    Excel: =ROUND(C34-C35-C29,2)
    TS:    round(totalPool - consumed - infra, 2)
  D37: =ROUND(D34-D35-C29,2)
  E37: =ROUND(E34-E35-C29,2)

  C38: Reserve lost
    Excel: =ROUND(C36-C37,2)
    TS:    round(designedReserve - actualRemaining, 2)

  C39: Reserve lost %
    Excel: =IF(C36=0,0,C38/C36)
    TS:    designedReserve > 0 ? reserveLost / designedReserve : 0

Resiliency status (rows 41-46):
  C42: Space to rebuild 1 drive (TiB needed) = usablePerDriveTib
  C43: Can survive 1 drive failure?
    Excel: =IF(C37>=C42,"✅ YES","🚨 NO — NOT ENOUGH RESERVE")
    TS:    actualRemaining >= spaceForRebuild ? "yes" : "no"

  C44: Can survive 2 drive failures?
    Excel: =IF(C37>=C42*2,"✅ YES","🚨 NO")

  C46: Overall risk level
    Excel: Complex nested IF. The logic:
      IF provisioning=Fixed:
        IF can_survive_1: IF can_survive_2: HEALTHY, else: WARNING (Reduced redundancy)
        ELSE: CRITICAL (Cannot survive drive failure)
      ELSE (Thin):
        IF thin_full_can_survive_1: IF thin_full_can_survive_2: HEALTHY (but at risk when full)
          ELSE: WARNING (Same risk as fixed when full)
        ELSE: CRITICAL (Thin will fail on drive failure when full)

    TS: Rewrite as a small state machine (see helper function below).

Recommended Fix (rows 49-50):
  B49: Recommendation text
    Excel: =IF(C12<=C19,"✅ Your volumes are correctly sized. No action needed.",
                "Shrink all "&C11&" volumes from "&TEXT(C12,"0.00")&" TiB down to "
                &TEXT(C19,"0.00")&" TiB each. This restores your full "
                &TEXT(C36,"0.00")&" TiB rebuild reserve.")
    TS:    actualSize <= recommendedSize
             ? "✅ Your volumes are correctly sized. No action needed."
             : `Shrink all ${count} volumes from ${actualSize.toFixed(2)} TiB down to ${recommendedSize.toFixed(2)} TiB each. This restores your full ${reserveTib.toFixed(2)} TiB rebuild reserve.`;

  B50: Live-shrink note (conditional)
    Excel: =IF(C12<=C19,"","If each volume has less than "&TEXT(C19,"0.00")&" TiB of actual data, you can shrink live...")
```

**Risk level helper:**

```ts
type RiskLevel = "healthy" | "warning-reduced" | "warning-thin" | "critical";

function overallRiskLevel(args: {
  provisioning: "Fixed" | "Thin";
  fixedSurvive1: boolean;
  fixedSurvive2: boolean;
  thinFullSurvive1: boolean;
  thinFullSurvive2: boolean;
}): { level: RiskLevel; message: string } {
  if (args.provisioning === "Fixed") {
    if (!args.fixedSurvive1) return { level: "critical", message: "🚨 CRITICAL — Cannot survive drive failure" };
    if (!args.fixedSurvive2) return { level: "warning-reduced", message: "⚠️ WARNING — Reduced redundancy" };
    return { level: "healthy", message: "✅ HEALTHY" };
  }
  // Thin: evaluate the "when full" scenario (worst case)
  if (!args.thinFullSurvive1) return { level: "critical", message: "🚨 CRITICAL — Thin will fail on drive failure when full" };
  if (!args.thinFullSurvive2) return { level: "warning-thin", message: "⚠️ WARNING — Same risk as fixed when full" };
  return { level: "healthy", message: "✅ HEALTHY (but at risk when full)" };
}
```

**PowerShell Diagnostic Commands (rows 52-64):** Static strings except B63 which interpolates the recommended TiB size into a `Resize-VirtualDisk` one-liner. Render as a code block with copy button.

**UI intent:** Split into two clear panels. Left: "What you actually have" (the input form). Right: "What Microsoft recommends" (a read-only card). Below: a prominent risk-level banner (red/yellow/green). Below that: the recommended fix + PowerShell commands.

**Notes:**
- This tab is self-contained and can be a standalone route in the app (`/health-check`) — users may land here without going through the rest of the calculator.
- The defaults (8 TiB × 3 volumes, Three-Way Mirror, Fixed) are intentionally "bad" — they demonstrate the warning state out of the box.

---

### 7.12 Advanced Settings

**Purpose:** Power-user tuning + an override registry for every computed field on every tab.

**Inputs (state → `advanced`):**

| Cell | Field | Type | Default |
|---|---|---|---|
| C8 | `capacityEfficiencyFactor` | number | 0.92 |
| C13 | `infraVolumeLogicalTb` | number | 0.25 |
| C28 | `lockState` | "LOCKED" / "UNLOCKED" | LOCKED |
| D31:D73 | Overrides (per computed field) | number or blank | blank |

**Calculations:**

```
C7: Example display (drive-size × efficiency factor)
  Excel: =7.68*C8
  TS:    7.68 * capacityEfficiencyFactor (static demo, could just be a tooltip)

C14: Infra volume footprint
  See infraVolumeFootprintTb helper.

C18-C23: TB to TiB conversion table
  Excel: =ROUND(1*(1000/1024)^3,2), =ROUND(5*(1000/1024)^3,2), etc.
  TS:    [1, 5, 10, 25, 50, 100].map(tb => round(TB_TO_TIB(tb), 2))
  Note:  These are hardcoded reference rows. Render as a small table in the UI.

Override table (rows 30-73):
  For each row R:
    C_R: ='<source sheet>'!<source cell>  (current computed value)
    E_R: =IF(D_R<>"",D_R,C_R)             (active value = override if set)
  In the rewrite, replace with:
    active = state.advanced.overrides[fieldKey] ?? selectors.computed[fieldKey]
```

The override table has 35+ rows covering every major computed field from Hardware Inputs, AVD Planning, Workload Planner, and SOFS Planner. See `types.ts` → `OverrideKey` for the full list of keyed fields.

**UI intent:** A settings page gated by the LOCKED/UNLOCKED toggle. Default LOCKED. When the user clicks "Unlock", show a warning modal: "You accept all risk when unlocking." Only when unlocked can they enter override values. Render as a 3-column table: Field | Computed | Override. Active Value column is implicit (equals override if set, computed otherwise).

**Notes:**
- The override system is effectively a way to manually escape the formulas when the user knows the sheet is wrong for their environment (e.g., a vendor quotes formatted capacity different from 92%).
- Don't skip this tab even though it's power-user. Kris built it specifically to unstick customer conversations where the default assumptions don't hold.

---

### 7.13 References

**Purpose:** Static list of 17 Microsoft Learn documentation links.

**Inputs/Calculations:** None.

**UI intent:** Simple list of cards: Topic + URL. Group by category (S2D/Storage, Azure Local, Compute, AVD/FSLogix, AKS, SOFS).

Content is in `workbook-dump.json` under `sheets."References"`.

---

### 7.14 How to Use

**Purpose:** Landing page / onboarding content. Explains the calculator workflow, color coding, tab-by-tab guide, common questions (FAQ), and 8 tips.

**Inputs/Calculations:** None.

**UI intent:** This becomes the home page of the web app. Render as structured markdown. The three-step quickstart (Hardware Inputs → Workload Planner → Capacity Report) should be visually prominent. Include the "TB vs TiB" warning at the bottom.

Content is in `workbook-dump.json` under `sheets."How to Use"`.

---

### 7.15 To Do

**Purpose:** Project tracker used during workbook development. Has a task list and Q&A log.

**Skip in rewrite.** This tab is internal project management — don't port it. Tracks author TODO items for the workbook itself.


---

## 8. PowerShell template strings

The workbook generates three kinds of PowerShell output. All are formula-built strings that are fragile in Excel. In the rewrite, implement as typed template functions that read state directly.

### 8.1 Volume Detail Quick-Start one-liner (`Volume Detail!B43`)

**Excel (abbreviated):**
```excel
="1.."&C35&" | ForEach { New-Volume -FriendlyName 'Vol$_' -Size "&TEXT(F35,"0.00")
  &"TB -StoragePoolFriendlyName S2D* -FileSystem CSVFS_ReFS -ResiliencySettingName Mirror"
  &IF(D35="Three-Way Mirror"," -PhysicalDiskRedundancy 2",
    IF(D35="Two-Way Mirror"," -PhysicalDiskRedundancy 1",""))
  &" }"
```

**TS:**
```ts
function quickStartPowerShell(count: number, sizeTib: number, resiliency: ResiliencyType): string {
  const redundancyFlag =
    resiliency === "Three-Way Mirror" ? " -PhysicalDiskRedundancy 2"
    : resiliency === "Two-Way Mirror" ? " -PhysicalDiskRedundancy 1"
    : "";
  return `1..${count} | ForEach { New-Volume -FriendlyName 'Vol$_' -Size ${sizeTib.toFixed(2)}TB `
       + `-StoragePoolFriendlyName S2D* -FileSystem CSVFS_ReFS -ResiliencySettingName Mirror`
       + `${redundancyFlag} }`;
}
```

**⚠ Units note:** PowerShell's `-Size <number>TB` parameter is actually TiB (binary) despite saying "TB". The workbook passes the TiB value here on purpose. Preserve this in the rewrite; add a code comment so whoever reads it doesn't "fix" it.

### 8.2 Per-volume `New-Volume` commands (`Final Report!B82:B92`)

One command per volume, each ~350 characters of nested string concat. The pattern:

```
=IF(<scenario enabled>="No","# <name> — Disabled (skip)",
    "New-Volume -FriendlyName """<name>""" -Size "
    &TEXT('Volume Detail'!<E cell>,"0.00")&"TB "
    &"-StoragePoolFriendlyName S2D* -ResiliencySettingName "
    &IF(OR(...parity checks...),"Parity","Mirror")
    &" -PhysicalDiskRedundancy "
    &IF(<3-way or dual parity>,"2","1")
    &" -FileSystem CSVFS_ReFS "
    &IF('Hardware Inputs'!C13="Thin","-ProvisioningType Thin","-ProvisioningType Fixed"))
```

**TS helper:**
```ts
function volumeCreatePowerShell(args: {
  name: string;
  enabled: boolean;
  sizeTib: number;
  resiliency: ResiliencyType;
  provisioning: ProvisioningType;
}): string {
  if (!args.enabled) return `# ${args.name} — Disabled (skip)`;

  const settingName = args.resiliency === "Dual Parity" ? "Parity" : "Mirror";
  const redundancy =
    args.resiliency === "Three-Way Mirror" || args.resiliency === "Dual Parity" ? 2 : 1;
  const provFlag = args.provisioning === "Thin" ? "Thin" : "Fixed";

  return `New-Volume -FriendlyName "${args.name}" `
       + `-Size ${args.sizeTib.toFixed(2)}TB `
       + `-StoragePoolFriendlyName S2D* `
       + `-ResiliencySettingName ${settingName} `
       + `-PhysicalDiskRedundancy ${redundancy} `
       + `-FileSystem CSVFS_ReFS `
       + `-ProvisioningType ${provFlag}`;
}
```

Then loop over `volumeRows(state)` to build the full command list. Render as a single code block with a "Copy all" button.

### 8.3 Volume Health Check resize command (`Volume Health Check!B63`)

**Excel:**
```excel
="Get-VirtualDisk | ForEach { Resize-VirtualDisk -FriendlyName $_.FriendlyName -Size "
  &TEXT(C19,"0.00")&"TB }  # Resizes all volumes to "&TEXT(C19,"0.00")&" TiB"
```

**TS:**
```ts
function resizeAllVolumesPowerShell(recommendedSizeTib: number): string {
  return `Get-VirtualDisk | ForEach { Resize-VirtualDisk -FriendlyName $_.FriendlyName `
       + `-Size ${recommendedSizeTib.toFixed(2)}TB }  # Resizes all volumes to ${recommendedSizeTib.toFixed(2)} TiB`;
}
```

### 8.4 Diagnostic commands (`Volume Health Check!B54, B57, B60`)

These are literal (non-formula) strings. Render as static code blocks:

```powershell
# Check storage pool total and allocated size
Get-StoragePool S2D* | Select FriendlyName, Size, AllocatedSize, OperationalStatus, HealthStatus

# Check each volume — size, footprint, and provisioning type
Get-VirtualDisk | Select FriendlyName, Size, FootprintOnPool, ProvisioningType, ResiliencySettingName, OperationalStatus

# Check physical disk health
Get-PhysicalDisk | Select FriendlyName, MediaType, Size, HealthStatus, OperationalStatus
```

---

## 9. Validation rules (dropdown options)

Every Excel data validation, consolidated. These map 1:1 to the TS string unions in `formulas.ts`.

| Tab | Cell(s) | Options |
|---|---|---|
| Hardware Inputs | C8 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 |
| Hardware Inputs | C9 | All-NVMe (No Cache), NVMe + SSD (NVMe is Cache) |
| Hardware Inputs | C13 | Fixed (Thick), Thin |
| Hardware Inputs | C40 | Yes, No |
| Workload Planner | C44, C66, C83, C99, C106 | Yes, No |
| Workload Planner | C53, C69, C86, C101, C108 | Two-Way Mirror, Three-Way Mirror, Dual Parity, Nested Two-Way Mirror |
| Workload Planner | C61, C75, C92 | 1:1, 2:1, 3:1, 4:1 |
| AVD Planning | C6 | Yes, No |
| AVD Planning | C12, C22 | Two-Way Mirror, Three-Way Mirror, Dual Parity, Nested Two-Way Mirror |
| AVD Planning | C17 | S2D Volume (local), SOFS (separate cluster), External/Azure Files/ANF |
| AVD Planning | C30 | 1:1, 2:1, 3:1, 4:1 |
| SOFS Planner | C6 | Yes, No |
| SOFS Planner | C9 | 2, 3 |
| SOFS Planner | C10 | 4, 5, 6, 7, 8 |
| SOFS Planner | C15 | Single, Split |
| SOFS Planner | C16 | Two-Way Mirror, Three-Way Mirror |
| Advanced Settings | C28 | LOCKED, UNLOCKED |
| Volume Health Check | C13 | Three-Way Mirror, Two-Way Mirror, Dual Parity |
| Volume Health Check | C14 | Thin, Fixed |

**Note:** `SOFS Planner!C16` and `Volume Health Check!C13` deliberately restrict options. SOFS VM volume resiliency is limited to mirrors (no parity) because SOFS is SMB and wants low latency. Volume Health Check doesn't include Nested Two-Way because it's uncommon in the wild and complicates the "mirror copies" math.

---

## 10. Conditional formatting summary

The source workbook has conditional formatting on these sheets (from openpyxl scan, details omitted because openpyxl can't read extension-based CF rules cleanly):

- Workload Planner: 13 CF ranges — colors for PASS/FAIL/WARNING status strings + red for over-capacity numbers
- SOFS Planner: 1 CF range — readiness check coloring
- Compute Report: 2 CF ranges
- Final Report: 5 CF ranges
- Volume Health Check: 3 CF ranges — color the risk level banner by severity

**Approach for React:** Don't try to port CF rules as data. Instead, return status objects from selectors and drive Tailwind classes from them. Example:

```tsx
const poolStatus = usePoolStatus(state);  // returns "healthy" | "warn" | "critical"

<div className={cn(
  "rounded px-2 py-1",
  poolStatus === "healthy" && "bg-green-100 text-green-800",
  poolStatus === "warn"    && "bg-yellow-100 text-yellow-800",
  poolStatus === "critical" && "bg-red-100 text-red-800"
)}>
  {message}
</div>
```

This is cleaner than trying to map Excel rule ranges into components.

---

## 11. Suggested React component tree

```
<App>
  <TabBar />                              // left sidebar with 13 tabs (skip "To Do")
  <Route path="/how-to-use">
    <HowToUse />                          // static landing content
  </Route>
  <Route path="/hardware-inputs">
    <HardwareInputs>
      <ClusterHardwareForm />
      <AvailableStorageCard />            // C16-C24
      <RosettaStoneTable />               // C28-C36
      <ComputeHardwareForm />
      <ComputeCapacityCard />             // C44-C50
      <ResiliencyReferenceTable />        // static
    </HardwareInputs>
  </Route>
  <Route path="/avd-planning">
    <AvdPlanning>
      <AvdEnableToggle />
      <AvdStorageSection />               // Session hosts + profiles
      <AvdComputeSection />               // vCPU/RAM sizing
      <AvdFitChecks />
      <DensityMatrix />                   // Section 2
      <HostPoolScaleOut />                // Section 3
      <FsLogixEstimator />                // Section 4
      <NetworkBandwidth />                // Section 5
      <GoldImageReference />              // Section 6 (static)
      <AvdReadinessChecklist />           // Section 7
    </AvdPlanning>
  </Route>
  <Route path="/workload-planner">
    <WorkloadPlanner>
      <AvdSummaryCard />                  // read-only, linked from AVD Planning
      <ScenarioAccordion name="AKS">
        <AksInputs />
      </ScenarioAccordion>
      <ScenarioAccordion name="Infrastructure VMs">
        <InfraInputs />
      </ScenarioAccordion>
      <ScenarioAccordion name="Dev/Test">
        <DevTestInputs />
      </ScenarioAccordion>
      <ScenarioAccordion name="Backup / Archive">
        <BackupInputs />
      </ScenarioAccordion>
      <ScenarioAccordion name="Custom">
        <CustomInputs />
      </ScenarioAccordion>
      <CapacitySummaryCard />             // pool utilization, remaining, volume count
      <ComputeSummaryCard />              // vCPU/RAM fit
      <NPlusOneFailoverCheck />
      <OvercommitSensitivityTable />
    </WorkloadPlanner>
  </Route>
  <Route path="/sofs-planner">
    <SofsPlanner>
      <SofsEnableToggle />
      <SofsHardwareInputs />
      <SofsPoolCard />                    // auto-calculated drive size
      <FsLogixDemandCard />               // linked
      <IopsEstimator />
      <SofsVmCompute />
      <SofsReadinessChecklist />
      <SofsCalloutBoxes />                // the "important notes" section
    </SofsPlanner>
  </Route>
  <Route path="/volume-detail">
    <VolumeDetail>
      <VolumeTable rows={volumeRows} />   // per-scenario
      <FitCheckBanner />
      <QuickStartCard />                  // 1 volume per node
      <QuickStartPowerShell />
    </VolumeDetail>
  </Route>
  <Route path="/capacity-report">
    <CapacityReport />                    // read-only, print-friendly
  </Route>
  <Route path="/compute-report">
    <ComputeReport />                     // read-only, print-friendly
  </Route>
  <Route path="/final-report">
    <FinalReport />                       // long scrollable report
  </Route>
  <Route path="/drive-layout-comparison">
    <DriveLayoutComparison />
  </Route>
  <Route path="/thin-provisioning">
    <ThinProvisioning />                  // static educational content
  </Route>
  <Route path="/volume-health-check">
    <VolumeHealthCheck>
      <HealthCheckInputForm />
      <RecommendedPanel />
      <RiskLevelBanner />
      <ReserveImpactTable />
      <RecommendedFixCard />
      <DiagnosticCommands />
    </VolumeHealthCheck>
  </Route>
  <Route path="/references">
    <References />                        // static link list
  </Route>
  <Route path="/advanced-settings">
    <AdvancedSettings>
      <LockToggleWithWarning />
      <TuningInputs />
      <TbTibReferenceTable />
      <OverrideTable />                   // gated by unlock
    </AdvancedSettings>
  </Route>
</App>
```

Shared components used throughout:

- `<StatusBadge variant={"pass"|"fail"|"warn"|"disabled"} message={string} />`
- `<TbTibCell tb={number} />` — shows TB and TiB side-by-side with the yellow background on the TiB value
- `<PowerShellBlock code={string} />` — syntax-highlighted with copy button
- `<NumericInput min max step value onChange />` — for all numeric inputs
- `<DropdownInput options value onChange />` — for all enum inputs
- `<Callout variant={"info"|"warn"|"tip"} />` — for the various static advisory boxes
- `<ProgressBar value={0..1} thresholds={[0.7, 1.0]} />` — for pool/compute utilization

---

## 12. Test plan — parity checks

Before shipping, verify the rewrite matches the workbook for a set of fixed input scenarios. Here are 3 starting scenarios — run them through both the workbook and the TS implementation and check that outputs match to ≤0.01 TB / ≤1 vCPU precision.

### Scenario A: Default state (no workloads enabled)

```ts
// Start from DEFAULT_STATE in types.ts
// Expected outputs:
hardware.totalCapacityDrives     === 12
hardware.totalRawCapacityTb      === 92.16
hardware.totalUsablePoolTb       === 84.7872
hardware.reserveTb               === 21.1968
hardware.availableCapacityForVolumesTb === 62.8404
hardware.totalClusterVCpu        === 192
hardware.totalClusterRamGb       === 672
hardware.nPlusOneVCpu            === 128
hardware.nPlusOneRamGb           === 448
workload.totalPhysicalFootprintTb === 0
workload.remainingPoolCapacityTb  === 62.8404
```

### Scenario B: AVD enabled with FSLogix on local

```ts
{
  ...DEFAULT_STATE,
  avd: {
    ...DEFAULT_STATE.avd,
    enabled: "Yes",
    sessionHostVms: 32,
    osDiskGb: 127,
    dataDiskGb: 50,
    hostResiliency: "Two-Way Mirror",
    // profiles: 1300 users × 5 GB × 1.3 growth = 8.45 GB × 1300 = 10.985 GB → 10.73 TB
    totalUsers: 1300,
    profileSizeGb: 5,
    growthBuffer: 0.3,
    profileResiliency: "Three-Way Mirror",
  }
}

// Expected:
avd.sessionHostVolumeLogicalTb  === 5.53   // 32 × (127+50) / 1024
avd.sessionHostFootprintTb      === 11.06  // 5.53 / 0.5
avd.profileVolumeLogicalTb      === 8.25   // 1300 × 5 × 1.3 / 1024
avd.profileFootprintTb          === 24.75  // 8.25 / (1/3)
avd.totalStorageFootprintTb     === 35.81
avd.totalVCpuDemand             === 256    // 32 × 8
avd.totalRamDemandGb            === 1024   // 32 × 32 — but only 672 GB available! should FAIL
avd.effectiveVCpu               === 64     // 256 / 4
workload.totalPhysicalFootprintTb === 35.81
workload.poolUtilization        === 0.570  // 35.81 / 62.84
```

This scenario should fail the RAM fit check (1024 > 672) and surface a red alert.

### Scenario C: Bad Volume Health Check

```ts
// Default hardware (3 nodes, 7.68 TB drives)
// + user created 3 volumes of 8 TiB each, Three-Way Mirror, Fixed
// + 2 TiB actual data per volume

healthCheck: {
  actualVolumeCount: 3,
  actualVolumeSizeTib: 8,
  actualResiliency: "Three-Way Mirror",
  actualProvisioning: "Fixed",
  actualDataPerVolumeTib: 2,
}

// Expected (from the source workbook):
totalPoolTib                === 78.96    // TB_TO_TIB(84.7872)
volumesFootprintTib         === 72       // 3 × 8 × 3 (three copies)
infraTib                    === 0.70     // TB_TO_TIB(0.75)
totalPoolConsumedTib        === 72.70
designedReserveTib          === 19.74    // TB_TO_TIB(21.20)
actualRemainingReserveTib   === 5.56     // 78.96 - 72.70 - 0.70
reserveLostTib              === 14.18
reserveLostPct              === 0.718
canSurvive1DriveFailure     === false    // 5.56 < 7.0656
canSurvive2DriveFailures    === false
overallRisk                 === "critical"
recommendedSizeTib          === 6.50     // from Volume Detail!F35
recommendation              === "Shrink all 3 volumes from 8.00 TiB down to 6.50 TiB..."
```

These three scenarios exercise: (A) the all-zero baseline, (B) a fully-loaded AVD scenario with overflow detection, and (C) the standalone health check logic. If they pass, the core math is right.

### Automated approach

Write parity tests as Vitest cases:

```ts
// test/parity.test.ts
import { describe, expect, it } from "vitest";
import { DEFAULT_STATE } from "@/state/types";
import { hardwareDerived, workloadDerived, avdDerived, healthCheckDerived } from "@/formulas";

describe("Parity with S2D_Capacity_Calculator.xlsx", () => {
  it("Scenario A: default state hardware derivation", () => {
    const h = hardwareDerived(DEFAULT_STATE);
    expect(h.totalCapacityDrives).toBe(12);
    expect(h.totalRawCapacityTb).toBeCloseTo(92.16, 2);
    expect(h.totalUsablePoolTb).toBeCloseTo(84.7872, 4);
    expect(h.reserveTb).toBeCloseTo(21.1968, 4);
    expect(h.availableCapacityForVolumesTb).toBeCloseTo(62.8404, 4);
    // ... etc
  });

  it("Scenario B: AVD enabled", () => {
    // ...
  });

  it("Scenario C: bad health check", () => {
    // ...
  });
});
```

Run `pnpm test --watch` while building each selector and lock numbers to the workbook's precision.

---

## Appendix: how to use this spec with Claude Code / Cursor

**Option 1 — feed the whole thing:**

```
$ cd s2d-calculator-web
$ cat SPEC.md types.ts formulas.ts > _context.md
# then in Claude Code:
> I want to scaffold a React + TypeScript rewrite of an Excel workbook.
> Read _context.md for the full specification. Start by setting up Vite + React + Tailwind + Zustand.
> Then create the state store, shared formula helpers, and the Hardware Inputs tab.
> Use the DEFAULT_STATE and verify against the test cases in §12.
```

**Option 2 — feed one tab at a time:**

```
> Build the AVD Planning tab. The spec is in SPEC.md §7.2.
> Read types.ts for the AvdInputs shape and formulas.ts for shared helpers.
> Generate a tab component under src/tabs/AvdPlanning.tsx plus any selectors it needs in src/formulas/avd.ts.
> Use Vitest to verify Scenario B from §12.
```

**Option 3 — use the JSON dump as ground truth:**

The companion `workbook-dump.json` contains every cell's formula and computed value. When an agent is uncertain about a formula, point it at this file: "Verify the formula at Workload Planner!C125 by reading workbook-dump.json." The file is ~240 KB and fits comfortably in context.

### Parity between computed values and your TS

The `workbook-dump.json` file records the *computed* value of every formula cell as it existed when the workbook was last saved. Default-state scenario A numbers in §12 were all lifted straight from this dump. If you change inputs in your rewrite and want to verify against the workbook, you can:

1. Open the source .xlsx
2. Set the same inputs
3. Re-export with openpyxl + the `scripts/recalc.py` helper from Anthropic's xlsx skill
4. Compare the new dump to your TS selector output

This is tedious for ad-hoc checks but invaluable when something's off by exactly 0.5% and you need to figure out whether it's a rounding difference or a translation bug.

---

**End of spec.** Total source formulas covered: ~880 across 15 sheets. Every non-trivial formula has an Excel ↔ TS translation above. Shared patterns are factored into `formulas.ts`. State shape is in `types.ts`. The raw cell dump is in `workbook-dump.json`.
