/**
 * S2D Capacity Calculator — shared formula primitives
 * Translated from S2D_Capacity_Calculator.xlsx
 *
 * Every non-trivial Excel formula in the workbook ultimately resolves to
 * one of these helpers or a small combination of them. Keep this file as the
 * single source of truth for math; wire derived state through useMemo selectors
 * that call these functions.
 */

// =============================================================================
// Enum-like string unions that mirror the Excel dropdowns (data validations)
// =============================================================================

export type DriveMedia = "All-NVMe (No Cache)" | "NVMe + SSD (NVMe is Cache)";

export type ResiliencyType =
  | "Two-Way Mirror"
  | "Three-Way Mirror"
  | "Dual Parity"
  | "Nested Two-Way Mirror";

export type ProvisioningType = "Fixed (Thick)" | "Thin";

export type YesNo = "Yes" | "No";

export type OvercommitRatio = "1:1" | "2:1" | "3:1" | "4:1";

export type ProfileLocation =
  | "S2D Volume (local)"
  | "SOFS (separate cluster)"
  | "External/Azure Files/ANF";

export type ProfileContainerType = "Single" | "Split";

// =============================================================================
// Unit conversions — the workbook is TB (decimal); Windows/WAC/PS use TiB (binary)
// 1 TB = 1,000,000,000,000 bytes ; 1 TiB = 1,099,511,627,776 bytes
// Factor: (1000/1024)^3 ≈ 0.9313 TiB per TB  (the workbook uses ^3, not ^4 — see
// notes in SPEC.md §"Excel-isms" about the one cell that uses ^4)
// =============================================================================

export const TB_TO_TIB = (tb: number): number => tb * (1000 / 1024) ** 3;
export const TIB_TO_TB = (tib: number): number => tib * (1024 / 1000) ** 3;

/** Round like Excel's ROUND(x, n) — banker-free, half-away-from-zero. */
export const round = (x: number, digits = 2): number => {
  const p = 10 ** digits;
  return Math.sign(x) * Math.round(Math.abs(x) * p) / p;
};

export const roundUp = (x: number, digits = 0): number => {
  const p = 10 ** digits;
  return Math.ceil(x * p) / p;
};

export const roundDown = (x: number, digits = 0): number => {
  const p = 10 ** digits;
  return Math.floor(x * p) / p;
};

// =============================================================================
// Resiliency efficiency — THE most repeated formula in the workbook.
// Appears ~20+ times as a nested IF. This is the canonical version.
//
// Excel source (canonical form, verbatim from AVD Planning!C14):
//   IF(C12="Three-Way Mirror", 1/3,
//   IF(C12="Two-Way Mirror", 0.5,
//   IF(C12="Dual Parity",
//      IF('Hardware Inputs'!C8>=16, 0.8,
//      IF('Hardware Inputs'!C8>=9, 0.75,
//      IF('Hardware Inputs'!C8>=7, 2/3, 0.5))),
//   IF(C12="Nested Two-Way Mirror", 0.25, 1/3))))
// =============================================================================

export function resiliencyEfficiency(
  type: ResiliencyType,
  nodeCount: number
): number {
  switch (type) {
    case "Three-Way Mirror":
      return 1 / 3;
    case "Two-Way Mirror":
      return 0.5;
    case "Nested Two-Way Mirror":
      return 0.25;
    case "Dual Parity":
      if (nodeCount >= 16) return 0.8;
      if (nodeCount >= 9) return 0.75;
      if (nodeCount >= 7) return 2 / 3;
      return 0.5;
  }
}

/** Short human label used in the UI (e.g. "33% eff."). Mirrors CONCATENATE + TEXT. */
export function resiliencyEfficiencyLabel(
  type: ResiliencyType,
  nodeCount: number
): string {
  return `${Math.round(resiliencyEfficiency(type, nodeCount) * 100)}% eff.`;
}

/** Copies label ("2x"/"3x"/"parity") — Volume Detail column G. */
export function resiliencyCopies(type: ResiliencyType): "2x" | "3x" | "parity" {
  if (type === "Two-Way Mirror") return "2x";
  if (type === "Three-Way Mirror") return "3x";
  return "parity"; // Dual Parity + Nested all bucketed as "parity" in the sheet
}

/** Minimum node count required for each resiliency type (SOFS readiness check). */
export function resiliencyMinNodes(type: ResiliencyType): number {
  switch (type) {
    case "Two-Way Mirror":
      return 2;
    case "Three-Way Mirror":
      return 3;
    case "Dual Parity":
      return 4;
    case "Nested Two-Way Mirror":
      return 4;
  }
}

// =============================================================================
// Overcommit ratio parsing — "4:1" → 4
// =============================================================================

export function overcommitDivisor(ratio: OvercommitRatio): number {
  return parseInt(ratio.split(":")[0], 10);
}

// =============================================================================
// Capacity math — mirrors Hardware Inputs tab
// =============================================================================

/** Hardware Inputs!C16: totalCapacityDrives = nodes × drivesPerNode */
export const totalCapacityDrives = (nodes: number, drivesPerNode: number) =>
  nodes * drivesPerNode;

/** Hardware Inputs!C18: rawCapacityTb = totalDrives × driveSizeTb */
export const totalRawCapacityTb = (totalDrives: number, driveSizeTb: number) =>
  totalDrives * driveSizeTb;

/** Hardware Inputs!C19: usableCapacityPerDriveTb = driveSizeTb × capacityEfficiencyFactor
 *  Advanced Settings!C8 default = 0.92 (~8% NVMe/filesystem overhead) */
export const usableCapacityPerDriveTb = (
  driveSizeTb: number,
  capacityEfficiencyFactor: number
) => driveSizeTb * capacityEfficiencyFactor;

/** Hardware Inputs!C20: totalUsablePoolTb = totalDrives × usablePerDriveTb */
export const totalUsablePoolTb = (
  totalDrives: number,
  usablePerDriveTb: number
) => totalDrives * usablePerDriveTb;

/** Hardware Inputs!C21: reserveTb = MIN(nodes, 4) × usablePerDriveTb
 *  S2D reserves 1 drive per node up to a max of 4 for auto-repair. */
export const reserveTb = (nodes: number, usablePerDriveTb: number) =>
  Math.min(nodes, 4) * usablePerDriveTb;

/** Advanced Settings!C14: infraVolumeFootprintTb
 *  Depends on auto-selected resiliency by node count:
 *    3+ nodes → three-way mirror (÷ 1/3 = × 3)
 *    2 nodes  → two-way mirror (÷ 0.5 = × 2)
 *    1 node   → no mirror (× 1) */
export function infraVolumeFootprintTb(
  infraLogicalTb: number,
  nodes: number
): number {
  const eff = nodes >= 3 ? 1 / 3 : nodes === 2 ? 0.5 : 1;
  return round(infraLogicalTb / eff, 2);
}

/** Hardware Inputs!C24: availableCapacityForVolumesTb
 *  = totalUsablePoolTb − reserveTb − infraVolumeFootprintTb */
export const availableCapacityForVolumesTb = (
  pool: number,
  reserve: number,
  infra: number
) => pool - reserve - infra;

// =============================================================================
// Compute math — mirrors Hardware Inputs tab
// =============================================================================

/** C45: logicalVCpuPerNode = physicalCores × (SMT ? 2 : 1) */
export const logicalVCpuPerNode = (physCores: number, smtEnabled: boolean) =>
  physCores * (smtEnabled ? 2 : 1);

/** C46: usableRamPerNodeGb = totalRamGb - hostOsReservedGb */
export const usableRamPerNodeGb = (totalRamGb: number, hostReservedGb: number) =>
  totalRamGb - hostReservedGb;

export const totalClusterVCpu = (logicalVCpuPerNode: number, nodes: number) =>
  logicalVCpuPerNode * nodes;

export const totalClusterRamGb = (usableRamPerNodeGb: number, nodes: number) =>
  usableRamPerNodeGb * nodes;

/** N+1: available when 1 node is offline */
export const nPlusOneVCpu = (logicalVCpuPerNode: number, nodes: number) =>
  logicalVCpuPerNode * (nodes - 1);

export const nPlusOneRamGb = (usableRamPerNodeGb: number, nodes: number) =>
  usableRamPerNodeGb * (nodes - 1);

// =============================================================================
// Volume footprint — every scenario on Workload Planner uses this pattern:
//   footprint = logicalSize / resiliencyEfficiency
// =============================================================================

export function volumeFootprintTb(
  logicalTb: number,
  resiliency: ResiliencyType,
  nodes: number
): number {
  if (logicalTb === 0) return 0;
  return round(logicalTb / resiliencyEfficiency(resiliency, nodes), 2);
}

// =============================================================================
// AVD helpers — AVD Planning tab
// =============================================================================

/** C13: session host volume logical (TB)  = VMs × (osGb + dataGb) / 1024 */
export const avdSessionHostVolumeLogicalTb = (
  vms: number,
  osDiskGb: number,
  dataDiskGb: number
): number => {
  if (vms === 0) return 0;
  return round((vms * (osDiskGb + dataDiskGb)) / 1024, 2);
};

/** C23: profile volume logical (TB) = users × profileGb × (1 + growthBuffer) / 1024 */
export const avdProfileVolumeLogicalTb = (
  totalUsers: number,
  profileSizeGb: number,
  growthBuffer: number
): number => {
  if (totalUsers === 0) return 0;
  return round((totalUsers * profileSizeGb * (1 + growthBuffer)) / 1024, 2);
};

/** C33: users per session host (max) = MIN(INT(hostVCpu / userVCpu), INT(hostRamGb / userRamGb)) */
export const avdUsersPerSessionHost = (
  hostVCpu: number,
  hostRamGb: number,
  userVCpu: number,
  userRamGb: number
): number => Math.min(Math.floor(hostVCpu / userVCpu), Math.floor(hostRamGb / userRamGb));

/** C34: session hosts needed = ROUNDUP(concurrentUsers / usersPerHost) */
export const avdSessionHostsNeeded = (
  concurrentUsers: number,
  usersPerHost: number
): number => (usersPerHost === 0 ? 0 : Math.ceil(concurrentUsers / usersPerHost));

/** C38: effective AVD vCPU (with overcommit) = ROUND(totalDemand / overcommitDivisor) */
export const avdEffectiveVCpu = (
  totalVCpuDemand: number,
  ratio: OvercommitRatio
): number => round(totalVCpuDemand / overcommitDivisor(ratio), 0);

// =============================================================================
// FSLogix / SOFS helpers — SOFS Planner tab
// =============================================================================

/** SOFS!C29: profile logical demand (TB) */
export const sofsProfileLogicalDemandTb = (
  users: number,
  profileSizeGb: number,
  growthBuffer: number
): number => round((users * profileSizeGb * (1 + growthBuffer)) / 1024, 2);

/** SOFS!C30: profile footprint on SOFS = logical / resiliencyEff  */
export const sofsProfileFootprintTb = (
  logicalTb: number,
  resiliency: ResiliencyType,
  sofsNodes: number
): number => {
  const eff = resiliencyEfficiency(resiliency, sofsNodes);
  if (eff === 0) return 0;
  return round(logicalTb / eff, 2);
};

/** SOFS!C39: steady IOPS = concurrentUsers × steadyIopsPerUser × (split ? 3 : 1) */
export const sofsSteadyIops = (
  concurrent: number,
  steadyPerUser: number,
  containerType: ProfileContainerType
): number => concurrent * steadyPerUser * (containerType === "Split" ? 3 : 1);

/** SOFS!C40: peak storm IOPS.
 *   = ((users × (1 - stormPct) × steadyIops) + (users × stormPct × loginStormIops))
 *     × (split ? 3 : 1) */
export const sofsPeakStormIops = (
  concurrent: number,
  stormPct: number,
  steadyPerUser: number,
  stormPerUser: number,
  containerType: ProfileContainerType
): number => {
  const mult = containerType === "Split" ? 3 : 1;
  const steady = concurrent * (1 - stormPct) * steadyPerUser;
  const storm = concurrent * stormPct * stormPerUser;
  return round((steady + storm) * mult, 0);
};

// =============================================================================
// Drive Layout Comparison helpers
// =============================================================================

/** For the "what-if" grid: same raw capacity, different drive counts per node. */
export function driveLayoutAlternative(
  drivesPerNode: number,
  rawCapacityTb: number,
  nodes: number,
  capacityEfficiencyFactor: number,
  infraFootprintTb: number
) {
  const totalDrives = drivesPerNode * nodes;
  const driveSizeTb = round(rawCapacityTb / (drivesPerNode * nodes), 2);
  const usablePerDrive = driveSizeTb * capacityEfficiencyFactor;
  const reserve = Math.min(nodes, 4) * usablePerDrive;
  const available = totalDrives * usablePerDrive - reserve - infraFootprintTb;
  return { drivesPerNode, driveSizeTb, totalDrives, usablePerDrive, reserve, available };
}
