/**
 * S2D Capacity Calculator — central state types
 *
 * This file defines the SHAPE of the calculator's state. All 15 workbook
 * tabs read from this state via derived selectors (see SPEC.md §"Architecture").
 *
 * Convention: every field here corresponds to a user-editable cell in the
 * workbook. Computed values are NOT stored — they are derived on demand from
 * these inputs using functions in formulas.ts.
 */

import type {
  DriveMedia,
  ResiliencyType,
  ProvisioningType,
  YesNo,
  OvercommitRatio,
  ProfileLocation,
  ProfileContainerType,
} from "./formulas";

// =============================================================================
// Hardware Inputs tab
// =============================================================================

export interface HardwareInputs {
  /** C8: cluster node count, 1-16 */
  nodes: number;
  /** C9 */
  driveMedia: DriveMedia;
  /** C10: capacity drives per node (min 2, recommend 4+) */
  capacityDrivesPerNode: number;
  /** C11: drive size in decimal TB (e.g. 7.68) */
  driveSizeTb: number;
  /** C12: cache drives per node — only used if driveMedia is NVMe+SSD */
  cacheDrivesPerNode: number;
  /** C13 */
  defaultProvisioning: ProvisioningType;
  /** C39: physical CPU cores per node */
  physicalCoresPerNode: number;
  /** C40: SMT / hyperthreading */
  hyperthreading: YesNo;
  /** C41: total RAM per node in GB */
  ramPerNodeGb: number;
  /** C42: host OS / S2D reservation in GB (typical 16-32) */
  hostOsReservedRamGb: number;
}

// =============================================================================
// AVD Planning tab — single source of truth for ALL AVD config
// Workload Planner §1 and SOFS Planner pull from this
// =============================================================================

export interface AvdInputs {
  /** C6: master enable flag for the whole AVD scenario */
  enabled: YesNo;
  // ---- Session hosts ----
  /** C9 */
  sessionHostVms: number;
  /** C10: OS disk per host in GB (default 127) */
  osDiskGb: number;
  /** C11: data/temp disk per host in GB */
  dataDiskGb: number;
  /** C12 */
  hostResiliency: ResiliencyType;
  // ---- FSLogix profiles ----
  /** C17 */
  profileStorageLocation: ProfileLocation;
  /** C18 */
  totalUsers: number;
  /** C19: concurrent / peak connected users */
  concurrentUsers: number;
  /** C20: profile container size per user (GB) — start at 5 */
  profileSizeGb: number;
  /** C21: growth buffer as decimal (0.3 = 30%) */
  growthBuffer: number;
  /** C22 */
  profileResiliency: ResiliencyType;
  // ---- Compute ----
  /** C28 */
  vcpuPerHost: number;
  /** C29 */
  ramPerHostGb: number;
  /** C30 */
  overcommitRatio: OvercommitRatio;
  /** C31: vCPU per user (light=1, medium=2, power=4) */
  vcpuPerUser: number;
  /** C32: RAM per user GB (light=2, medium=4, power=8) */
  ramPerUserGb: number;
  // ---- FSLogix estimator (Section 4) ----
  /** C76/D76 */
  taskWorkerSizeGb: number;
  taskWorkerPct: number; // 0.3 = 30%
  /** C77/D77 */
  knowledgeWorkerSizeGb: number;
  knowledgeWorkerPct: number;
  /** C78/D78 */
  powerUserSizeGb: number;
  powerUserPct: number;
  // ---- Network estimator (Section 5) ----
  /** C89: Mbps per session (1.5 single-monitor, 3+ multi) */
  bandwidthPerSessionMbps: number;
}

// =============================================================================
// Workload Planner tab — per-scenario configuration
// AVD scenario pulls from AvdInputs; the rest are edited here.
// =============================================================================

export interface WorkloadPlannerInputs {
  // ---- S2: AKS (C44-C61) ----
  aksEnabled: YesNo;
  aksClusters: number; // C46
  aksControlPlaneNodes: number; // C47
  aksWorkerNodes: number; // C48
  aksOsDiskPerNodeGb: number; // C49
  aksPersistentVolumeTb: number; // C51
  aksDataServicesTb: number; // C52
  aksResiliency: ResiliencyType; // C53
  aksVcpuPerControlPlane: number; // C57
  aksRamPerControlPlaneGb: number; // C58
  aksVcpuPerWorker: number; // C59
  aksRamPerWorkerGb: number; // C60
  aksOvercommit: OvercommitRatio; // C61

  // ---- S3: Infrastructure VMs (C66-C77) ----
  infraEnabled: YesNo;
  infraVmCount: number; // C67
  infraAvgDiskPerVmGb: number; // C68
  infraResiliency: ResiliencyType; // C69
  infraAvgVcpuPerVm: number; // C73
  infraAvgRamPerVmGb: number; // C74
  infraOvercommit: OvercommitRatio; // C75

  // ---- S4: Dev/Test (C83-C94) ----
  devTestEnabled: YesNo;
  devTestVmCount: number; // C84
  devTestAvgDiskPerVmGb: number; // C85
  devTestResiliency: ResiliencyType; // C86
  devTestAvgVcpuPerVm: number; // C90
  devTestAvgRamPerVmGb: number; // C91
  devTestOvercommit: OvercommitRatio; // C92

  // ---- S5: Backup/Archive (C99-C101) ----
  backupEnabled: YesNo;
  backupVolumeTb: number; // C100
  backupResiliency: ResiliencyType; // C101

  // ---- S6: Custom (C106-C108) ----
  customEnabled: YesNo;
  customVolumeTb: number; // C107
  customResiliency: ResiliencyType; // C108
}

// =============================================================================
// SOFS Planner tab — separate file server cluster for FSLogix
// =============================================================================

export interface SofsInputs {
  /** C6: master enable flag */
  enabled: YesNo;
  /** C9: SOFS node count (2 or 3) */
  sofsNodes: number;
  /** C10: drives per SOFS node (4-8) */
  drivesPerNode: number;
  /** C14: capacity efficiency factor (0.92 default) */
  capacityEfficiencyFactor: number;
  /** C15: Single = 1 VHD/user, Split = 3 VHDs/user (triples IOPS) */
  containerType: ProfileContainerType;
  /** C16: resiliency for the SOFS VM storage volumes on MAIN cluster */
  sofsVmVolumeResiliency: ResiliencyType;
  // Note: C11 (drive capacity), C13 (internal resiliency), C25-C28 (FSLogix
  // demand) are all LINKED from AVD Planning / Workload Planner. SOFS internal
  // resiliency = AVD profile resiliency by design.
  /** C35 */
  steadyIopsPerUser: number;
  /** C36 */
  loginStormIopsPerUser: number;
  /** C38: 10-30% typical */
  loginStormPercent: number;
  /** C43 */
  vcpuPerSofsVm: number;
  /** C44 */
  ramPerSofsVmGb: number;
}

// =============================================================================
// Advanced Settings tab — tuning knobs + override registry
// =============================================================================

export interface AdvancedSettings {
  /** C8: default 0.92 (~8% formatting overhead) */
  capacityEfficiencyFactor: number;
  /** C13: infrastructure volume logical size in TB (default 0.25) */
  infraVolumeLogicalTb: number;
  /**
   * Cell-protection override registry. The workbook has an LOCKED/UNLOCKED
   * toggle at C28 plus a table of override values in column D (rows 31-73).
   * Keyed by a semantic field name from the other interfaces.
   *
   * If a key is present and non-empty, the override replaces the computed
   * value everywhere it's referenced. This models the "IF(D31<>\"\", D31, C31)"
   * pattern used throughout Advanced Settings.
   */
  overrides: Partial<Record<OverrideKey, number>>;
  /** C28: LOCKED disables all overrides */
  lockState: "LOCKED" | "UNLOCKED";
}

/** Every field in Advanced Settings!B30:B73 that has an override column. */
export type OverrideKey =
  | "totalCapacityDrives"
  | "totalRawCapacityTb"
  | "totalUsablePoolBeforeReserveTb"
  | "reserveTb"
  | "availableCapacityForVolumesTb"
  | "totalClusterVCpu"
  | "totalClusterRamGb"
  | "nPlusOneVCpu"
  | "nPlusOneRamGb"
  | "avdSessionHostVolumeLogicalTb"
  | "avdSessionHostFootprintTb"
  | "avdProfileVolumeLogicalTb"
  | "avdProfileFootprintTb"
  | "avdTotalStorageFootprintTb"
  | "avdUsersPerSessionHost"
  | "avdSessionHostsNeeded"
  | "avdTotalVCpuDemand"
  | "avdTotalRamDemandGb"
  | "avdEffectiveVCpu"
  | "workloadAvdTotalFootprintTb"
  | "workloadAksTotalFootprintTb"
  | "workloadInfraTotalFootprintTb"
  | "workloadDevTestTotalFootprintTb"
  | "workloadBackupTotalFootprintTb"
  | "workloadCustomTotalFootprintTb"
  | "workloadSofsVmVolumesFootprintTb"
  | "workloadTotalPhysicalFootprintTb"
  | "workloadRemainingPoolTb"
  | "workloadPoolUtilizationPct"
  | "sofsDriveCapacityTb"
  | "sofsTotalRawCapacityTb"
  | "sofsUsableCapacityTb"
  | "sofsAvailableForVolumesTb"
  | "sofsProfileLogicalDemandTb"
  | "sofsProfileFootprintTb"
  | "sofsSteadyIops"
  | "sofsPeakStormIops";

// =============================================================================
// Volume Health Check tab — post-deployment audit (standalone)
// =============================================================================

export interface VolumeHealthCheckInputs {
  /** C11 */
  actualVolumeCount: number;
  /** C12: size per volume in TiB (WAC display value) */
  actualVolumeSizeTib: number;
  /** C13 */
  actualResiliency: Extract<
    ResiliencyType,
    "Two-Way Mirror" | "Three-Way Mirror" | "Dual Parity"
  >;
  /** C14 */
  actualProvisioning: "Thin" | "Fixed";
  /** C15: actual data written per volume in TiB (Get-VirtualDisk FootprintOnPool) */
  actualDataPerVolumeTib: number;
}

// =============================================================================
// Root calculator state — what a Zustand / Context store would hold
// =============================================================================

export interface CalculatorState {
  hardware: HardwareInputs;
  avd: AvdInputs;
  workload: WorkloadPlannerInputs;
  sofs: SofsInputs;
  advanced: AdvancedSettings;
  healthCheck: VolumeHealthCheckInputs;
}

// =============================================================================
// Default values — copied from the shipped workbook (the initial state)
// =============================================================================

export const DEFAULT_STATE: CalculatorState = {
  hardware: {
    nodes: 3,
    driveMedia: "All-NVMe (No Cache)",
    capacityDrivesPerNode: 4,
    driveSizeTb: 7.68,
    cacheDrivesPerNode: 0,
    defaultProvisioning: "Fixed (Thick)",
    physicalCoresPerNode: 32,
    hyperthreading: "Yes",
    ramPerNodeGb: 256,
    hostOsReservedRamGb: 32,
  },
  avd: {
    enabled: "No",
    sessionHostVms: 32,
    osDiskGb: 127,
    dataDiskGb: 50,
    hostResiliency: "Two-Way Mirror",
    profileStorageLocation: "S2D Volume (local)",
    totalUsers: 1300,
    concurrentUsers: 300,
    profileSizeGb: 5,
    growthBuffer: 0.3,
    profileResiliency: "Three-Way Mirror",
    vcpuPerHost: 8,
    ramPerHostGb: 32,
    overcommitRatio: "4:1",
    vcpuPerUser: 2,
    ramPerUserGb: 4,
    taskWorkerSizeGb: 2,
    taskWorkerPct: 0.3,
    knowledgeWorkerSizeGb: 5,
    knowledgeWorkerPct: 0.5,
    powerUserSizeGb: 15,
    powerUserPct: 0.2,
    bandwidthPerSessionMbps: 3,
  },
  workload: {
    aksEnabled: "No",
    aksClusters: 1,
    aksControlPlaneNodes: 1,
    aksWorkerNodes: 3,
    aksOsDiskPerNodeGb: 200,
    aksPersistentVolumeTb: 0,
    aksDataServicesTb: 0,
    aksResiliency: "Three-Way Mirror",
    aksVcpuPerControlPlane: 4,
    aksRamPerControlPlaneGb: 16,
    aksVcpuPerWorker: 8,
    aksRamPerWorkerGb: 32,
    aksOvercommit: "4:1",
    infraEnabled: "No",
    infraVmCount: 0,
    infraAvgDiskPerVmGb: 200,
    infraResiliency: "Three-Way Mirror",
    infraAvgVcpuPerVm: 4,
    infraAvgRamPerVmGb: 16,
    infraOvercommit: "4:1",
    devTestEnabled: "No",
    devTestVmCount: 0,
    devTestAvgDiskPerVmGb: 120,
    devTestResiliency: "Two-Way Mirror",
    devTestAvgVcpuPerVm: 2,
    devTestAvgRamPerVmGb: 8,
    devTestOvercommit: "4:1",
    backupEnabled: "No",
    backupVolumeTb: 3,
    backupResiliency: "Dual Parity",
    customEnabled: "No",
    customVolumeTb: 0,
    customResiliency: "Three-Way Mirror",
  },
  sofs: {
    enabled: "No",
    sofsNodes: 3,
    drivesPerNode: 4,
    capacityEfficiencyFactor: 0.92,
    containerType: "Single",
    sofsVmVolumeResiliency: "Two-Way Mirror",
    steadyIopsPerUser: 10,
    loginStormIopsPerUser: 50,
    loginStormPercent: 0.2,
    vcpuPerSofsVm: 8,
    ramPerSofsVmGb: 16,
  },
  advanced: {
    capacityEfficiencyFactor: 0.92,
    infraVolumeLogicalTb: 0.25,
    overrides: {},
    lockState: "LOCKED",
  },
  healthCheck: {
    actualVolumeCount: 3,
    actualVolumeSizeTib: 8,
    actualResiliency: "Three-Way Mirror",
    actualProvisioning: "Fixed",
    actualDataPerVolumeTib: 2,
  },
};
