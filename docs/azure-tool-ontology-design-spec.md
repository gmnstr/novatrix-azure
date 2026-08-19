# Azure Tool Ontology — Design Spec (shim v1.0.0)

Design spec for the typed Azure tool surface for MOV25 Novatrix. Authority remains `docs/azure-tool-ontology-v1.0.md`; this spec pins the exact names a shim implementer codes from. It adds three course-only types and three additive relations — it does not rename or remove anything from v1.0.

## 1. File layout (future shim — do not create from this spec alone)

```
docs/azure-tool-ontology-v1.0.md          # authority (unchanged)
src/ontology/v1.0.0/types.ts              # all exports in §6
src/ontology/v1.0.0/manifest.json         # shape in §7
scripts/validate-ontology.ts              # bun; checks in §10
```

Pattern copied from `workspaces/mcp-servers/dcp-mcp-shim/` (same file names, same validator style). Runtime is Bun/TypeScript — no Python per repo scripting rule.

## 2. Constants

| Export | Value |
| --- | --- |
| `ONTOLOGY_VERSION` | `"1.0.0"` |
| `ONTOLOGY_SURFACE` | `"azure-tool-surface"` |
| `TOOL_COUNT` | `20` (7 baseline + 13 week tools, §5) |
| `Origin` | `"azure"` (single literal) |
| `StateKind` | `"source" \| "projected" \| "canonical"` — `canonical` never emitted silently (v1.0 §2) |

## 3. Types (`V3Type` — 22 total, frozen)

ARM-mapped types MUST carry `arm_type`; course-only types carry `arm_type: null`.

| `V3Type` | `arm_type` (reference ID, cite-only) | Week | VG relevance |
| --- | --- | --- | --- |
| `ResourceGroup` | `Microsoft.Resources/resourceGroups` | v34 | scope of every graph |
| `PublicIP` | `Microsoft.Network/publicIPAddresses` | v34 | |
| `NetworkInterface` | `Microsoft.Network/networkInterfaces` | v34 | |
| `VirtualMachine` | `Microsoft.Compute/virtualMachines` | v34 | justify compute (v40) |
| `CloudInitConfig` | `null` (customData property, not an ARM type) | v34 | |
| `User` | `null` (Entra, not ARM) | v35 | |
| `Group` | `null` (Entra, not ARM) | v35 | |
| `ManagedIdentity` | `Microsoft.ManagedIdentity/userAssignedIdentities` (or system-assigned flag on the VM node) | v35 | MI requirement |
| `RoleAssignment` | `Microsoft.Authorization/roleAssignments` | v35 | least-privilege |
| `VirtualNetwork` | `Microsoft.Network/virtualNetworks` | v36 | network-as-code |
| `Subnet` | `Microsoft.Network/virtualNetworks/subnets` | v36 | |
| `NetworkSecurityGroup` | `Microsoft.Network/networkSecurityGroups` | v36 | |
| `BastionHost` | `Microsoft.Network/bastionHosts` | v36 (VG) | |
| `StorageAccount` | `Microsoft.Storage/storageAccounts` | v37 | |
| `BlobContainer` | `Microsoft.Storage/storageAccounts/blobServices/containers` | v37 | |
| `ArmTemplate` | `null` (compiled file artifact; live linkage via `Microsoft.Resources/deployments` readback) | v38 | teacher projection |
| `ParameterFile` | `null` (file artifact) | v38 | full parameterized ARM |
| `AutomationFlow` | `null` (Power Automate definition) | v39 | Automate chain |
| `ComputeWorkload` | `null` (comparison subject: VM / container / Function) | v40 | justified compute |
| `TicketForm` | `null` (course-only) | v39 | ticket source for the flow |
| `WeekRequirement` | `null` (course-only) | all | grading bar node |
| `TeardownPlan` | `null` (course-only) | all | daily teardown |

`arm_type` values are opaque reference strings pointing at the [ARM resource type catalog](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-providers-and-types). Property shapes, when needed, are checked against [Azure/bicep-types-az](https://github.com/Azure/bicep-types-az) at authoring time. Neither is vendored.

## 4. Envelope (`ProjectionHit`)

One envelope for every structured hit (v1.0 §2 kernel, unchanged):

| Field | Type | Notes |
| --- | --- | --- |
| `v3_type` | `V3Type` | |
| `v3_id` | `string \| null` | prefixed when promoted; else null |
| `external_id` | `string` | ARM resource id, or `{rg}/{name}` |
| `origin` | `"azure"` | |
| `state_kind` | `StateKind` | `source` = live ARM readback; `projected` = what-if / compiled template |
| `temporal` | `{ ts?, created_at?, updated_at? }` optional | |
| `provenance` | `{ tool: ToolName; server: "azure-tool"; actor?; source_ref? }` | |
| `score` | `number` optional | unused |
| `relations` | `Array<{ type: RelationName; target_external_id: string; target_v3_type?: V3Type }>` optional | |
| `next` | `NextEdge[]` optional | `{ tool, args?, why, relation? }` |
| `disposition` | `DispositionCode` optional | |

Forbidden as ontology kinds (v1.0 §2): raw SKU strings, credit balances, the subscription without an id, SAS tokens, passwords.

## 5. Tools (`ToolName` — 20)

| `ToolName` | `ToolsetId` | R/W | Primary `v3_type` out | Week |
| --- | --- | --- | --- | --- |
| `azure_what_if` | `azure_visibility` | read | `ArmTemplate` + projected resources | base |
| `azure_show` | `azure_visibility` | read | matching resource type | base |
| `azure_smoke` | `azure_visibility` | read | `VirtualMachine` + `PublicIP` | base |
| `azure_bootstrap` | `azure_lifecycle` | write | `ResourceGroup` | base |
| `azure_deploy` | `azure_lifecycle` | write | deployed graph | base |
| `azure_teardown` | `azure_lifecycle` | write | `ResourceGroup` (gone) | base |
| `azure_bicep_build` | `azure_arm` | read | `ArmTemplate` (`projected`) | base |
| `azure_entra_user_create` | `azure_identity` | write | `User` | v35 |
| `azure_entra_group_create` | `azure_identity` | write | `Group` | v35 |
| `azure_mi_create` | `azure_identity` | write | `ManagedIdentity` | v35 |
| `azure_rbac_assign` | `azure_identity` | write | `RoleAssignment` | v35 |
| `azure_vnet_apply` | `azure_network` | write | `VirtualNetwork` + `Subnet` | v36 |
| `azure_nsg_apply` | `azure_network` | write | `NetworkSecurityGroup` | v36 |
| `azure_bastion_apply` | `azure_network` | write | `BastionHost` | v36 |
| `azure_storage_account_create` | `azure_storage` | write | `StorageAccount` | v37 |
| `azure_container_create` | `azure_storage` | write | `BlobContainer` | v37 |
| `azure_storage_lock` | `azure_storage` | write | `BlobContainer` / `StorageAccount` | v37 |
| `azure_arm_render` | `azure_arm` | read | `ArmTemplate` + `ParameterFile` | v38 |
| `azure_flow_register` | `azure_automate` | write | `AutomationFlow` | v39 |
| `azure_workload_compare` | `novatrix_v40` | read | `ComputeWorkload` | v40 |

## 6. `types.ts` exports (exact)

```
ONTOLOGY_VERSION, ONTOLOGY_SURFACE, TOOL_COUNT        // consts
ToolName                                            // 20-member union (§5)
ToolsetId                                           // "azure_visibility" | "azure_lifecycle" | "azure_identity"
                                                    // | "azure_network" | "azure_storage" | "azure_arm"
                                                    // | "azure_automate" | "novatrix_v34" | ... | "novatrix_v40"
V3Type                                              // 22-member union (§3)
RelationName                                        // 11-member union (§8)
DispositionCode                                     // 8-member union (§9)
StateKind, Origin                                   // §2
ARM_TYPE: Record<V3Type, string | null>             // §3
TOOL_TOOLSET: Record<ToolName, ToolsetId>
TOOL_RW: Record<ToolName, "read" | "write">
TOOL_OUTPUT_TYPE: Record<ToolName, V3Type>          // primary out type per tool
DEFAULT_TOOLSETS: ToolsetId[]                       // ["azure_visibility", "azure_lifecycle"]
NextEdge, Provenance, ProjectionHit                 // interfaces per §4
```

## 7. `manifest.json` shape

```json
{
  "ontology_version": "1.0.0",
  "surface": "azure-tool-surface",
  "tool_count": 20,
  "default_toolsets": ["azure_visibility", "azure_lifecycle"],
  "v3_types": ["ResourceGroup", "..."],
  "arm_types": { "ResourceGroup": "Microsoft.Resources/resourceGroups", "TicketForm": null },
  "authority_doc": "workspaces/azure25/docs/azure-tool-ontology-v1.0.md",
  "pattern_peer": "workspaces/mcp-servers/dcp-mcp-tool-ontology-v1.0.md"
}
```

Always-available special toolset IDs (not `ToolsetId` members, resolved at dispatch): `default` → visibility + lifecycle; `all` → every toolset.

## 8. Relations (`RelationName` — 11)

First 8 are v1.0 §6 (unchanged); last 3 are additive.

| `RelationName` | From | To | Rule | Week |
| --- | --- | --- | --- | --- |
| `hostedIn` | any resource | `ResourceGroup` | required on every ARM-mapped node | all |
| `attachedTo` | `PublicIP` / `NetworkInterface` | `VirtualMachine` | | v34 |
| `allowedBy` | `NetworkInterface` / `Subnet` | `NetworkSecurityGroup` | | v36 |
| `containedIn` | `Subnet` | `VirtualNetwork` | | v36 |
| `identityOf` | `ManagedIdentity` | `VirtualMachine` | | v35/v37 |
| `grantedTo` | `RoleAssignment` | `User` / `Group` / `ManagedIdentity` | least-privilege | v35 |
| `writesTo` | `TicketForm` / `VirtualMachine` | `BlobContainer` | | v37 |
| `compiledFrom` | `ArmTemplate` | Bicep source path | | v38 |
| `parameterizedBy` | `ArmTemplate` | `ParameterFile` | required from v38 | v38 |
| `triggeredBy` | `AutomationFlow` | `TicketForm` | | v39 |
| `tornDownBy` | any billed resource | `TeardownPlan` | required daily | all |

## 9. Dispositions (`DispositionCode` — 8, unchanged from v1.0 §7)

`ok` · `what_if_drift` · `quota` · `nsg_deny` · `identity_missing` · `illegal_graph` · `teardown_incomplete` · `auth_denied`

## 10. Validation

`scripts/validate-ontology.ts` (bun) — lockstep checks only; v1.0 doc stays the authority:

| # | Check | Fail when |
| --- | --- | --- |
| 1 | version parity | `manifest.ontology_version !== ONTOLOGY_VERSION` |
| 2 | tool count | `manifest.tool_count !== TOOL_COUNT` |
| 3 | key parity | `TOOL_TOOLSET`, `TOOL_RW`, `TOOL_OUTPUT_TYPE` key sets differ |
| 4 | toolset membership | every `TOOL_TOOLSET` value is a declared `ToolsetId` |
| 5 | default toolsets | manifest ↔ `DEFAULT_TOOLSETS` mismatch |
| 6 | type parity | `manifest.v3_types` ↔ `V3Type` union ↔ `ARM_TYPE` keys mismatch |
| 7 | `arm_type` completeness | every `V3Type` has an explicit `ARM_TYPE` entry (null allowed, missing key not) |
| 8 | relation endpoints | every relation `From`/`To` references declared `V3Type`s |

Illegal-graph rejection (instance-graph level, run in week slices and Phase 2 probes) — only rules that prevent a real VG fail:

| Rule | Disposition |
| --- | --- |
| `PublicIP` on a subnet marked private | `illegal_graph` |
| `BlobContainer` public + lock-access claim | `illegal_graph` |
| `RoleAssignment.grantedTo` target is not an identity type | `illegal_graph` |
| writer of `BlobContainer` has no `ManagedIdentity` (`identityOf` missing) | `identity_missing` |
| `azure_deploy` for v38+ week without prior `azure_bicep_build` / missing `compiledFrom`+`parameterizedBy` | `illegal_graph` |
| name violates `typ-företag-syfte` on Novatrix hand-in nodes | `illegal_graph` |
| billed resource lacking `tornDownBy → TeardownPlan` at end of day | `teardown_incomplete` |

## 11. Weekly growth

Additive only (v1.0 §4): week toolsets add types/tools; nothing is renamed or removed. Sequence and per-week additions are in the plan doc §2 Phase 3. `novatrix_v34` starts tiny (baseline 7 tools + 8 v34 types incl. `TeardownPlan`/`WeekRequirement`); each later week opens its toolset and its frozen types.

## 12. Non-goals

- No MCP server, no stdio transport, no tool dispatch runtime.
- No `kg.*`, no KG/TTL/OWL output, no vault KG mutation.
- No vendored MS schemas/types (`bicep-types-az`, ARM schemas cited only as `arm_type` strings).
- No DTDL, Fabric IQ, or Azure Verified Modules as dependencies.
- No Key Vault / AppGW / MySQL / Policy / Recovery Vault / App Insights types.
- No configurability or abstraction layers beyond the DCP-shim pattern.
- Azure RBAC stays the permission boundary; the ontology only rejects illegal graphs.
