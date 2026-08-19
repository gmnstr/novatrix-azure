#!/usr/bin/env bun
/**
 * novatrix-azure instance-graph validator.
 * Reads src/ontology/v1.0.0/instance-graph.json and applies the illegal-graph
 * rejection rules from design spec §10 (only rules that prevent a real VG fail):
 *
 *   1. PublicIP on a subnet marked private                        -> illegal_graph
 *   2. BlobContainer public + lock-access claim                   -> illegal_graph
 *   3. RoleAssignment.grantedTo target not identity type          -> illegal_graph
 *   4. writer of BlobContainer without identityOf ManagedIdentity -> identity_missing
 *   5. v38+ ArmTemplate missing compiledFrom+parameterizedBy      -> illegal_graph
 *   6. Novatrix hand-in name violates typ-företag-syfte           -> illegal_graph
 *   7. billed resource lacking tornDownBy -> TeardownPlan         -> teardown_incomplete
 *
 * Encoding notes (property conventions used by the projected graph):
 *   - Subnet.access: "public" | "private" (also accepts is_private: true)
 *   - PublicIP.subnet_external_id: external_id of the subnet the PIP is placed on
 *   - BlobContainer.access: "public" | "private"; BlobContainer.lock_access: boolean
 *   - ArmTemplate.week: numeric week; rule 5 applies when week >= 38
 *   - Node names are the last segment of external_id (ARM id or {rg}/{name})
 */
import { readFileSync } from "node:fs";
import { join } from "node:path";
import type { DispositionCode, ProjectionHit, V3Type } from "../src/ontology/v1.0.0/types.ts";

const root = join(import.meta.dir, "..");
const graphPath = join(root, "src/ontology/v1.0.0/instance-graph.json");
const raw = JSON.parse(readFileSync(graphPath, "utf8")) as
  | ProjectionHit[]
  | { nodes?: ProjectionHit[] };

const nodes: ProjectionHit[] = Array.isArray(raw) ? raw : (raw.nodes ?? []);
const byExternalId = new Map<string, ProjectionHit>();
const byType = new Map<V3Type, ProjectionHit[]>();

for (const n of nodes) {
  if (!n || typeof n !== "object" || typeof n.v3_type !== "string" || typeof n.external_id !== "string") {
    fail("malformed", `graph node missing v3_type or external_id: ${JSON.stringify(n)}`);
    continue;
  }
  byExternalId.set(n.external_id, n);
  const list = byType.get(n.v3_type) ?? [];
  list.push(n);
  byType.set(n.v3_type, list);
}

const errors: { disposition: DispositionCode; message: string }[] = [];
function fail(disposition: DispositionCode, message: string) {
  errors.push({ disposition, message });
}

// --- General integrity: every relation target must resolve -------------------
for (const n of nodes) {
  for (const rel of n.relations ?? []) {
    if (!byExternalId.has(rel.target_external_id)) {
      fail("illegal_graph", `${n.v3_type} ${n.external_id} relation ${rel.type} -> unknown target ${rel.target_external_id}`);
    }
  }
}

// --- Rule 1: PublicIP on subnet marked private --------------------------------
for (const pip of byType.get("PublicIP") ?? []) {
  const subnetId = pip.properties?.subnet_external_id as string | undefined;
  if (!subnetId) continue;
  const subnet = byExternalId.get(subnetId);
  if (!subnet) {
    fail("illegal_graph", `PublicIP ${pip.external_id} references unknown subnet ${subnetId}`);
    continue;
  }
  const p = subnet.properties ?? {};
  const privateMarked = p.access === "private" || p.is_private === true;
  if (privateMarked) {
    fail("illegal_graph", `PublicIP ${pip.external_id} is placed on subnet ${subnetId} marked private`);
  }
}

// --- Rule 2: BlobContainer public + lock-access claim -------------------------
for (const bc of byType.get("BlobContainer") ?? []) {
  const p = bc.properties ?? {};
  const isPublic = p.access === "public" || p.public_access === true;
  const lockClaimed = p.lock_access === true || p.lock === true;
  if (isPublic && lockClaimed) {
    fail("illegal_graph", `BlobContainer ${bc.external_id} is public but claims lock-access`);
  }
  if (lockClaimed) {
    fail("illegal_graph", `BlobContainer ${bc.external_id} claims lock_access but no Authorization/locks resource exists`);
  }
}

// --- Cross-check: VM size in graph must match compute.bicep default -----------
const computeBicep = readFileSync(join(root, "infra/compute.bicep"), "utf8");
const bicepSize = computeBicep.match(/param vmSize string = '([^']+)'/)?.[1];
if (bicepSize) {
  for (const vm of byType.get("VirtualMachine") ?? []) {
    const graphSize = vm.properties?.size as string | undefined;
    if (graphSize && graphSize !== bicepSize) {
      fail("illegal_graph", `VirtualMachine ${vm.external_id} size ${graphSize} != compute.bicep ${bicepSize}`);
    }
  }
}
const buildPath = join(root, "build/main.json");
try {
  const build = readFileSync(buildPath, "utf8");
  if (bicepSize && !build.includes(bicepSize)) {
    fail("illegal_graph", `build/main.json missing vmSize ${bicepSize} (stale ARM projection)`);
  }
} catch {
  fail("illegal_graph", "build/main.json missing (v38 hand-in projection)");
}

// --- Rule 3: RoleAssignment.grantedTo target must be an identity type ---------
const IDENTITY_TYPES = new Set<V3Type>(["User", "Group", "ManagedIdentity"]);
for (const ra of byType.get("RoleAssignment") ?? []) {
  for (const rel of ra.relations ?? []) {
    if (rel.type !== "grantedTo") continue;
    const target = byExternalId.get(rel.target_external_id);
    if (!target) {
      fail("illegal_graph", `RoleAssignment ${ra.external_id} grantedTo unknown target ${rel.target_external_id}`);
    } else if (!IDENTITY_TYPES.has(target.v3_type)) {
      fail("illegal_graph", `RoleAssignment ${ra.external_id} grantedTo ${target.v3_type} ${target.external_id} (not User/Group/ManagedIdentity)`);
    }
  }
}

// --- Rule 4: writer of BlobContainer needs identityOf ManagedIdentity ---------
for (const bc of byType.get("BlobContainer") ?? []) {
  const writers = nodes.filter((n) =>
    (n.relations ?? []).some((r) => r.type === "writesTo" && r.target_external_id === bc.external_id),
  );
  for (const writer of writers) {
    if (writer.v3_type !== "VirtualMachine") continue; // only VM writers run under the MI
    const hasMI = (byType.get("ManagedIdentity") ?? []).some((mi) =>
      (mi.relations ?? []).some(
        (r) => r.type === "identityOf" && r.target_external_id === writer.external_id,
      ),
    );
    if (!hasMI) {
      fail("identity_missing", `writer of BlobContainer ${bc.external_id}: ${writer.v3_type} ${writer.external_id} has no ManagedIdentity (identityOf)`);
    }
  }
}

// --- Rule 5: v38+ ArmTemplate needs compiledFrom + parameterizedBy ------------
for (const at of byType.get("ArmTemplate") ?? []) {
  const week = at.properties?.week as number | undefined;
  if (typeof week !== "number" || week < 38) continue;
  const rels = at.relations ?? [];
  const hasCompiled = rels.some((r) => r.type === "compiledFrom");
  const hasParam = rels.some((r) => r.type === "parameterizedBy");
  if (!hasCompiled || !hasParam) {
    fail("illegal_graph", `ArmTemplate ${at.external_id} (week ${week}) missing compiledFrom and/or parameterizedBy`);
  }
}

// --- Rule 6: Novatrix hand-in naming (typ-företag-syfte) ----------------------
const NAME_RULES: Record<string, { names?: string[]; regex?: RegExp }> = {
  ResourceGroup: { names: ["rg-novatrix"] },
  VirtualMachine: { names: ["vm-novatrix-web"] },
  PublicIP: { names: ["pip-novatrix-web"] },
  NetworkInterface: { names: ["nic-novatrix-web"] },
  VirtualNetwork: { names: ["vnet-novatrix-core"] },
  NetworkSecurityGroup: { names: ["nsg-novatrix-web", "nsg-novatrix-data"] },
  ManagedIdentity: { names: ["id-novatrix-web"] },
  StorageAccount: { regex: /^stnovatrix[a-z0-9]+01$/ },
};
for (const [v3Type, rule] of Object.entries(NAME_RULES)) {
  for (const n of byType.get(v3Type as V3Type) ?? []) {
    const name = n.external_id.split("/").filter(Boolean).pop() ?? n.external_id;
    const ok = rule.names ? rule.names.includes(name) : rule.regex!.test(name);
    if (!ok) {
      fail("illegal_graph", `${v3Type} ${n.external_id} violates typ-företag-syfte (name "${name}")`);
    }
  }
}

// --- Rule 7: billed resources need tornDownBy -> TeardownPlan -----------------
const BILLED: V3Type[] = ["PublicIP", "NetworkInterface", "VirtualMachine", "BastionHost", "StorageAccount"];
for (const t of BILLED) {
  for (const n of byType.get(t) ?? []) {
    const hasTeardown = (n.relations ?? []).some(
      (r) => r.type === "tornDownBy" && byExternalId.get(r.target_external_id)?.v3_type === "TeardownPlan",
    );
    if (!hasTeardown) {
      fail("teardown_incomplete", `billed resource ${t} ${n.external_id} lacks tornDownBy -> TeardownPlan`);
    }
  }
}

if (errors.length) {
  console.error("[novatrix-azure] validate-graph FAILED:");
  for (const e of errors) console.error(" -", e.disposition, e.message);
  process.exit(1);
}

console.log(`[novatrix-azure] validate-graph OK nodes=${nodes.length} types=${byType.size}`);
