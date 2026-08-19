#!/usr/bin/env bun
/**
 * novatrix-azure ontology validator (design spec §10 checks 1–8).
 * Lockstep checks between manifest.json and types.ts; v1.0 doc stays the authority.
 */
import { readFileSync } from "node:fs";
import { join } from "node:path";
import {
  ARM_TYPE,
  DEFAULT_TOOLSETS,
  ONTOLOGY_SURFACE,
  ONTOLOGY_VERSION,
  RELATION_ENDPOINTS,
  TOOL_COUNT,
  TOOL_OUTPUT_TYPE,
  TOOL_RW,
  TOOL_TOOLSET,
  type RelationName,
  type ToolName,
  type ToolsetId,
  type V3Type,
} from "../src/ontology/v1.0.0/types.ts";

const root = join(import.meta.dir, "..");
const manifestPath = join(root, "src/ontology/v1.0.0/manifest.json");
const manifest = JSON.parse(readFileSync(manifestPath, "utf8")) as {
  ontology_version: string;
  surface: string;
  tool_count: number;
  default_toolsets: string[];
  v3_types: string[];
  arm_types: Record<string, string | null>;
  authority_doc: string;
  pattern_peer: string;
};

/**
 * Runtime mirrors of the type-only unions from types.ts. Typed with `satisfies`
 * so a rename/drift in types.ts fails typechecking (authoring-time guard) and
 * these arrays stay the single source for union membership here.
 */
const TOOLSET_IDS = [
  "azure_visibility",
  "azure_lifecycle",
  "azure_identity",
  "azure_network",
  "azure_storage",
  "azure_arm",
  "azure_automate",
  "novatrix_v34",
  "novatrix_v35",
  "novatrix_v36",
  "novatrix_v37",
  "novatrix_v38",
  "novatrix_v39",
  "novatrix_v40",
] as const satisfies readonly ToolsetId[];

const V3_TYPE_NAMES = [
  "ResourceGroup",
  "PublicIP",
  "NetworkInterface",
  "VirtualMachine",
  "CloudInitConfig",
  "User",
  "Group",
  "ManagedIdentity",
  "RoleAssignment",
  "VirtualNetwork",
  "Subnet",
  "NetworkSecurityGroup",
  "BastionHost",
  "StorageAccount",
  "BlobContainer",
  "ArmTemplate",
  "ParameterFile",
  "AutomationFlow",
  "ComputeWorkload",
  "TicketForm",
  "WeekRequirement",
  "TeardownPlan",
] as const satisfies readonly V3Type[];

const errors: string[] = [];

// --- Check 1: version parity -------------------------------------------------
if (manifest.ontology_version !== ONTOLOGY_VERSION) {
  errors.push(
    `check 1 version parity: manifest=${manifest.ontology_version} types=${ONTOLOGY_VERSION}`,
  );
}

// --- Check 2: tool count -----------------------------------------------------
if (manifest.tool_count !== TOOL_COUNT) {
  errors.push(`check 2 tool count: manifest=${manifest.tool_count} types=${TOOL_COUNT}`);
}

// --- Check 3: key parity across TOOL_TOOLSET / TOOL_RW / TOOL_OUTPUT_TYPE ----
const toolKeys = Object.keys(TOOL_TOOLSET) as ToolName[];
const rwKeys = Object.keys(TOOL_RW) as ToolName[];
const outKeys = Object.keys(TOOL_OUTPUT_TYPE) as ToolName[];

for (const [label, keys] of [
  ["TOOL_TOOLSET", toolKeys],
  ["TOOL_RW", rwKeys],
  ["TOOL_OUTPUT_TYPE", outKeys],
] as const) {
  if (keys.length !== TOOL_COUNT) {
    errors.push(`check 3 key parity: ${label} size ${keys.length} != TOOL_COUNT ${TOOL_COUNT}`);
  }
}
const sortedKeys = (keys: string[]) => [...keys].sort();
const expectedToolKeys = sortedKeys(toolKeys);
for (const [label, keys] of [
  ["TOOL_RW", rwKeys],
  ["TOOL_OUTPUT_TYPE", outKeys],
] as const) {
  const actual = sortedKeys(keys);
  if (JSON.stringify(actual) !== JSON.stringify(expectedToolKeys)) {
    const missing = expectedToolKeys.filter((k) => !actual.includes(k));
    const extra = actual.filter((k) => !expectedToolKeys.includes(k));
    errors.push(
      `check 3 key parity: ${label} keys differ (missing=${missing.join(",") || "none"} extra=${extra.join(",") || "none"})`,
    );
  }
}

// --- Check 4: toolset membership ---------------------------------------------
const toolsetIdSet = new Set<string>(TOOLSET_IDS);
for (const [tool, toolset] of Object.entries(TOOL_TOOLSET)) {
  if (!toolsetIdSet.has(toolset)) {
    errors.push(`check 4 toolset membership: ${tool} -> ${toolset} is not a declared ToolsetId`);
  }
}

// --- Check 5: default toolsets ------------------------------------------------
const manifestDefaults = new Set(manifest.default_toolsets);
for (const t of DEFAULT_TOOLSETS) {
  if (!manifestDefaults.has(t)) {
    errors.push(`check 5 default toolsets: DEFAULT_TOOLSETS entry missing from manifest: ${t}`);
  }
}
for (const t of manifest.default_toolsets) {
  if (!DEFAULT_TOOLSETS.includes(t as ToolsetId)) {
    errors.push(`check 5 default toolsets: manifest entry not in DEFAULT_TOOLSETS: ${t}`);
  }
}
for (const t of manifest.default_toolsets) {
  if (!toolsetIdSet.has(t)) {
    errors.push(`check 5 default toolsets: manifest entry is not a declared ToolsetId: ${t}`);
  }
}

// --- Check 6: type parity (manifest.v3_types ↔ V3Type union ↔ ARM_TYPE keys) -
const v3TypeNameSet = new Set<string>(V3_TYPE_NAMES);
const armKeys = Object.keys(ARM_TYPE);
const armKeySet = new Set(armKeys);
const manifestTypeSet = new Set(manifest.v3_types);

for (const t of V3_TYPE_NAMES) {
  if (!manifestTypeSet.has(t)) {
    errors.push(`check 6 type parity: V3Type missing from manifest.v3_types: ${t}`);
  }
}
for (const t of manifest.v3_types) {
  if (!v3TypeNameSet.has(t)) {
    errors.push(`check 6 type parity: manifest.v3_types has undeclared V3Type: ${t}`);
  }
}
for (const t of V3_TYPE_NAMES) {
  if (!armKeySet.has(t)) {
    errors.push(`check 6 type parity: V3Type missing from ARM_TYPE keys: ${t}`);
  }
}
for (const t of armKeys) {
  if (!v3TypeNameSet.has(t)) {
    errors.push(`check 6 type parity: ARM_TYPE key is not a V3Type: ${t}`);
  }
}

// --- Check 7: arm_type completeness (null ok, missing key not) ---------------
for (const t of V3_TYPE_NAMES) {
  if (!Object.prototype.hasOwnProperty.call(ARM_TYPE, t)) {
    errors.push(`check 7 arm_type completeness: ARM_TYPE missing entry for V3Type: ${t}`);
  }
}
for (const t of manifest.v3_types) {
  if (!Object.prototype.hasOwnProperty.call(manifest.arm_types, t)) {
    errors.push(`check 7 arm_type completeness: manifest.arm_types missing entry for ${t}`);
  }
}

// --- Check 8: relation endpoints reference declared V3Types -------------------
for (const [rel, endpoints] of Object.entries(RELATION_ENDPOINTS) as [
  RelationName,
  { from: V3Type[]; to: V3Type[] },
][]) {
  for (const side of ["from", "to"] as const) {
    for (const t of endpoints[side]) {
      if (!v3TypeNameSet.has(t)) {
        errors.push(`check 8 relation endpoints: ${rel}.${side} references undeclared V3Type: ${t}`);
      }
    }
  }
}

// --- Bonus: surface parity (manifest shape §7) --------------------------------
if (manifest.surface !== ONTOLOGY_SURFACE) {
  errors.push(`surface mismatch: manifest=${manifest.surface} types=${ONTOLOGY_SURFACE}`);
}

if (errors.length) {
  console.error("[novatrix-azure] validate-ontology FAILED:");
  for (const e of errors) console.error(" -", e);
  process.exit(1);
}

console.log(
  `[novatrix-azure] validate-ontology OK version=${ONTOLOGY_VERSION} tools=${TOOL_COUNT} surface=${manifest.surface} types=${V3_TYPE_NAMES.length}`,
);
