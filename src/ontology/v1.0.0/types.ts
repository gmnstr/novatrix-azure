/** Azure tool ontology v1.0.0 — mirror of docs/azure-tool-ontology-v1.0.md + design spec. */
export const ONTOLOGY_VERSION = "1.0.0" as const;
export const ONTOLOGY_SURFACE = "azure-tool-surface" as const;
export const TOOL_COUNT = 20 as const;

export type ToolName =
  | "azure_what_if"
  | "azure_show"
  | "azure_smoke"
  | "azure_bootstrap"
  | "azure_deploy"
  | "azure_teardown"
  | "azure_bicep_build"
  | "azure_entra_user_create"
  | "azure_entra_group_create"
  | "azure_mi_create"
  | "azure_rbac_assign"
  | "azure_vnet_apply"
  | "azure_nsg_apply"
  | "azure_bastion_apply"
  | "azure_storage_account_create"
  | "azure_container_create"
  | "azure_storage_lock"
  | "azure_arm_render"
  | "azure_flow_register"
  | "azure_workload_compare";

export type ToolsetId =
  | "azure_visibility"
  | "azure_lifecycle"
  | "azure_identity"
  | "azure_network"
  | "azure_storage"
  | "azure_arm"
  | "azure_automate"
  | "novatrix_v34"
  | "novatrix_v35"
  | "novatrix_v36"
  | "novatrix_v37"
  | "novatrix_v38"
  | "novatrix_v39"
  | "novatrix_v40";

export type V3Type =
  | "ResourceGroup"
  | "PublicIP"
  | "NetworkInterface"
  | "VirtualMachine"
  | "CloudInitConfig"
  | "User"
  | "Group"
  | "ManagedIdentity"
  | "RoleAssignment"
  | "VirtualNetwork"
  | "Subnet"
  | "NetworkSecurityGroup"
  | "BastionHost"
  | "StorageAccount"
  | "BlobContainer"
  | "ArmTemplate"
  | "ParameterFile"
  | "AutomationFlow"
  | "ComputeWorkload"
  | "TicketForm"
  | "WeekRequirement"
  | "TeardownPlan";

export type RelationName =
  | "hostedIn"
  | "attachedTo"
  | "allowedBy"
  | "containedIn"
  | "identityOf"
  | "grantedTo"
  | "writesTo"
  | "compiledFrom"
  | "parameterizedBy"
  | "triggeredBy"
  | "tornDownBy";

export type DispositionCode =
  | "ok"
  | "what_if_drift"
  | "quota"
  | "nsg_deny"
  | "identity_missing"
  | "illegal_graph"
  | "teardown_incomplete"
  | "auth_denied";

export type StateKind = "source" | "projected" | "canonical";
export type Origin = "azure";

export const ARM_TYPE: Record<V3Type, string | null> = {
  ResourceGroup: "Microsoft.Resources/resourceGroups",
  PublicIP: "Microsoft.Network/publicIPAddresses",
  NetworkInterface: "Microsoft.Network/networkInterfaces",
  VirtualMachine: "Microsoft.Compute/virtualMachines",
  CloudInitConfig: null,
  User: null,
  Group: null,
  ManagedIdentity: "Microsoft.ManagedIdentity/userAssignedIdentities",
  RoleAssignment: "Microsoft.Authorization/roleAssignments",
  VirtualNetwork: "Microsoft.Network/virtualNetworks",
  Subnet: "Microsoft.Network/virtualNetworks/subnets",
  NetworkSecurityGroup: "Microsoft.Network/networkSecurityGroups",
  BastionHost: "Microsoft.Network/bastionHosts",
  StorageAccount: "Microsoft.Storage/storageAccounts",
  BlobContainer: "Microsoft.Storage/storageAccounts/blobServices/containers",
  ArmTemplate: null,
  ParameterFile: null,
  AutomationFlow: null,
  ComputeWorkload: null,
  TicketForm: null,
  WeekRequirement: null,
  TeardownPlan: null,
};

export const TOOL_TOOLSET: Record<ToolName, ToolsetId> = {
  azure_what_if: "azure_visibility",
  azure_show: "azure_visibility",
  azure_smoke: "azure_visibility",
  azure_bootstrap: "azure_lifecycle",
  azure_deploy: "azure_lifecycle",
  azure_teardown: "azure_lifecycle",
  azure_bicep_build: "azure_arm",
  azure_entra_user_create: "azure_identity",
  azure_entra_group_create: "azure_identity",
  azure_mi_create: "azure_identity",
  azure_rbac_assign: "azure_identity",
  azure_vnet_apply: "azure_network",
  azure_nsg_apply: "azure_network",
  azure_bastion_apply: "azure_network",
  azure_storage_account_create: "azure_storage",
  azure_container_create: "azure_storage",
  azure_storage_lock: "azure_storage",
  azure_arm_render: "azure_arm",
  azure_flow_register: "azure_automate",
  azure_workload_compare: "novatrix_v40",
};

export const TOOL_RW: Record<ToolName, "read" | "write"> = {
  azure_what_if: "read",
  azure_show: "read",
  azure_smoke: "read",
  azure_bootstrap: "write",
  azure_deploy: "write",
  azure_teardown: "write",
  azure_bicep_build: "read",
  azure_entra_user_create: "write",
  azure_entra_group_create: "write",
  azure_mi_create: "write",
  azure_rbac_assign: "write",
  azure_vnet_apply: "write",
  azure_nsg_apply: "write",
  azure_bastion_apply: "write",
  azure_storage_account_create: "write",
  azure_container_create: "write",
  azure_storage_lock: "write",
  azure_arm_render: "read",
  azure_flow_register: "write",
  azure_workload_compare: "read",
};

export const TOOL_OUTPUT_TYPE: Record<ToolName, V3Type> = {
  azure_what_if: "ArmTemplate",
  azure_show: "ResourceGroup",
  azure_smoke: "VirtualMachine",
  azure_bootstrap: "ResourceGroup",
  azure_deploy: "ResourceGroup",
  azure_teardown: "ResourceGroup",
  azure_bicep_build: "ArmTemplate",
  azure_entra_user_create: "User",
  azure_entra_group_create: "Group",
  azure_mi_create: "ManagedIdentity",
  azure_rbac_assign: "RoleAssignment",
  azure_vnet_apply: "VirtualNetwork",
  azure_nsg_apply: "NetworkSecurityGroup",
  azure_bastion_apply: "BastionHost",
  azure_storage_account_create: "StorageAccount",
  azure_container_create: "BlobContainer",
  azure_storage_lock: "BlobContainer",
  azure_arm_render: "ArmTemplate",
  azure_flow_register: "AutomationFlow",
  azure_workload_compare: "ComputeWorkload",
};

export const DEFAULT_TOOLSETS: ToolsetId[] = ["azure_visibility", "azure_lifecycle"];

export const RELATION_ENDPOINTS: Record<RelationName, { from: V3Type[]; to: V3Type[] }> = {
  hostedIn: {
    from: [
      "PublicIP",
      "NetworkInterface",
      "VirtualMachine",
      "ManagedIdentity",
      "RoleAssignment",
      "VirtualNetwork",
      "Subnet",
      "NetworkSecurityGroup",
      "BastionHost",
      "StorageAccount",
      "BlobContainer",
    ],
    to: ["ResourceGroup"],
  },
  attachedTo: { from: ["PublicIP", "NetworkInterface"], to: ["VirtualMachine"] },
  allowedBy: { from: ["NetworkInterface", "Subnet"], to: ["NetworkSecurityGroup"] },
  containedIn: { from: ["Subnet"], to: ["VirtualNetwork"] },
  identityOf: { from: ["ManagedIdentity"], to: ["VirtualMachine"] },
  grantedTo: { from: ["RoleAssignment"], to: ["User", "Group", "ManagedIdentity"] },
  writesTo: { from: ["TicketForm", "VirtualMachine"], to: ["BlobContainer"] },
  compiledFrom: { from: ["ArmTemplate"], to: ["ArmTemplate"] },
  parameterizedBy: { from: ["ArmTemplate"], to: ["ParameterFile"] },
  triggeredBy: { from: ["AutomationFlow"], to: ["TicketForm"] },
  tornDownBy: {
    from: [
      "PublicIP",
      "NetworkInterface",
      "VirtualMachine",
      "BastionHost",
      "StorageAccount",
    ],
    to: ["TeardownPlan"],
  },
};

export const IDENTITY_TYPES: V3Type[] = ["User", "Group", "ManagedIdentity"];

export interface NextEdge {
  tool: ToolName;
  args?: Record<string, unknown>;
  why: string;
  relation?: RelationName;
}

export interface Provenance {
  tool: ToolName;
  server: "azure-tool";
  actor?: string;
  source_ref?: string;
}

export interface ProjectionHit {
  v3_type: V3Type;
  v3_id: string | null;
  external_id: string;
  origin: Origin;
  state_kind: StateKind;
  temporal?: { ts?: string; created_at?: string; updated_at?: string };
  provenance: Provenance;
  score?: number;
  relations?: Array<{
    type: RelationName;
    target_external_id: string;
    target_v3_type?: V3Type;
  }>;
  next?: NextEdge[];
  disposition?: DispositionCode;
  properties?: Record<string, unknown>;
}
