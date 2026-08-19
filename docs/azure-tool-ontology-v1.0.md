# Azure Tool Ontology v1.0

## 1. Meta

| Field | Value |
| --- | --- |
| Version | **v1.0.0** |
| Surface | Azure CLI + Bicep/ARM deploy plane for this repo (parts bin) and Novatrix course work |
| Live backend | Azure Resource Manager via `az` / `az deployment group` |
| Pattern peer | `workspaces/mcp-servers/dcp-mcp-tool-ontology-v1.0.md` + `github-mcp-server-tool-ontology-v1.0.md` |
| Shim peer | `workspaces/mcp-servers/dcp-mcp-shim/src/ontology/v1.0.0/` (types + manifest + validator) |
| V3 projection bridge | `system/Meta/reports/2026-07-31-eido-mcp-v3-ontology-projection-mapping.md` |
| Security model | **Token-trust**: tools are availability UX; Azure RBAC + subscription quota are the auth boundary. Ontology rejects illegal *graphs*; it does not grant Azure permissions. |
| Parameter authority | This ontology + live ARM resource types; TypeScript mirrors (when added) live under `src/ontology/v1.0.0/` |
| Typed output contract | Every structured hit SHOULD carry V3 projection kernel fields (section 2) |

> **Authority split:** ARM JSON is the **teacher/hand-in projection**. Bicep is the **authoring source**. This ontology is the **control plane** — kinds, relations, dispositions — same job the MCP tool ontologies did for GitHub/DCP. Do not ship TTL/KG as the assignment artifact.

> **Repo role:** `azure25` is last year's enterprise baseline (parts bin). Novatrix weekly G/VG work should *steal* modules, not grow this tree into a second course repo. The ontology applies to the **Azure tool surface**, not only to files in `infra/`.

## 2. V3 projection kernel (required on structured hits)

Same kernel as DCP/GitHub shims:

| Field | V3 basis | Azure notes |
| --- | --- | --- |
| `v3_type` | Type / has_type | One of section 3 specialised types |
| `v3_id` | IdentityHandle | Prefixed when promoted; else null |
| `external_id` | external identity link | ARM resource id, or `{rg}/{name}` |
| `origin` | Provenance | always `azure` for this surface |
| `state_kind` | StateKind | `source` = live ARM readback; `projected` = what-if / template; never silent `canonical` |
| `temporal` | TemporalMark | created_at / updated_at when known |
| `provenance` | Provenance | `{ tool, server: "azure-tool", actor?, source_ref? }` |
| `score` | non-primitive | unused |
| `relations[]` | RelationOccurrence | e.g. vm→nic→pip, nic→nsg, identity→role |
| `next[]` | handoff edge | `{ tool, args, why, relation }` |
| `disposition` | envelope | success vs typed error code |

**Forbidden as ontology kinds:** raw SKU strings as subjects; credit balances; “the subscription” without an id; SAS tokens; passwords.

## 3. Specialised projection types (`v3_type`)

| `v3_type` | Region | Maps from | Identity posture | Week |
| --- | --- | --- | --- | --- |
| `ResourceGroup` | scope | `Microsoft.Resources/resourceGroups` | rg name | v34 |
| `PublicIP` | network | `Microsoft.Network/publicIPAddresses` | pip name | v34 |
| `NetworkInterface` | network | `Microsoft.Network/networkInterfaces` | nic name | v34 |
| `VirtualMachine` | compute | `Microsoft.Compute/virtualMachines` | vm name | v34 |
| `CloudInitConfig` | compute | customData / cloud-init | vm-scoped | v34 |
| `User` | identity | Entra user | UPN / object id | v35 |
| `Group` | identity | Entra group | object id | v35 |
| `ManagedIdentity` | identity | `Microsoft.ManagedIdentity/userAssignedIdentities` or system-assigned | identity id | v35 |
| `RoleAssignment` | identity | `Microsoft.Authorization/roleAssignments` | assignment id | v35 |
| `VirtualNetwork` | network | `Microsoft.Network/virtualNetworks` | vnet name | v36 |
| `Subnet` | network | vnet/subnets | subnet name | v36 |
| `NetworkSecurityGroup` | network | `Microsoft.Network/networkSecurityGroups` | nsg name | v36 |
| `BastionHost` | network | `Microsoft.Network/bastionHosts` | bastion name | v36 VG |
| `StorageAccount` | storage | `Microsoft.Storage/storageAccounts` | account name | v37 |
| `BlobContainer` | storage | blobServices/containers | container name | v37 |
| `ArmTemplate` | deploy | compiled `main.json` | file path + hash | v38 |
| `ParameterFile` | deploy | `*.parameters.json` | file path | v38 |
| `AutomationFlow` | integration | Power Automate definition | flow id | v39 |
| `ComputeWorkload` | compute | VM / container / Function comparison subject | workload id | v40 |

Reuse existing `azure25` modules as **implementations** of these types (e.g. `infra/compute/vm-*.bicep` → `VirtualMachine` + `CloudInitConfig`). Do not invent a second type for “the Bicep file”.

## 4. Toolsets

| Toolset id | Default | Purpose | R/W |
| --- | --- | --- | --- |
| `azure_visibility` | yes | show / list / what-if / smoke | read |
| `azure_lifecycle` | yes | bootstrap / deploy / teardown | write |
| `azure_identity` | no | users, groups, RBAC, managed identity | write |
| `azure_network` | no | vnet, nsg, bastion | write |
| `azure_storage` | no | account, container, lock-down | write |
| `azure_arm` | no | bicep build, parameterized ARM | read/write |
| `azure_automate` | no | ticket → SharePoint/Teams/Outlook | write |
| `novatrix_v34` … `novatrix_v40` | no | week-scoped slices; **additive only** | mixed |

Always-available special IDs: `default` → visibility + lifecycle; `all` → every toolset.

Week toolsets may only **add** types and tools. They must not rename or remove earlier kinds.

## 5. Tool inventory (control plane)

These are the Azure-tool ops, not every `az` subcommand. Live backend is ARM unless noted.

| Tool Name | Toolset | Live backend | R/W | Primary `v3_type` out |
| --- | --- | --- | --- | --- |
| `azure_what_if` | `azure_visibility` | `az deployment group what-if` | read | `ArmTemplate` + projected resources |
| `azure_show` | `azure_visibility` | `az resource show` / `az vm show` | read | matching resource type |
| `azure_smoke` | `azure_visibility` | `scripts/smoke.sh` | read | `VirtualMachine` + `PublicIP` |
| `azure_bootstrap` | `azure_lifecycle` | `scripts/bootstrap.sh` | write | `ResourceGroup` |
| `azure_deploy` | `azure_lifecycle` | `scripts/deploy.sh` / `az deployment group create` | write | deployed graph |
| `azure_teardown` | `azure_lifecycle` | `scripts/teardown.sh` | write | `ResourceGroup` (gone) |
| `azure_bicep_build` | `azure_arm` | `az bicep build` | read | `ArmTemplate` (`state_kind: projected`) |

Course weeks bind extra tools (`azure_rbac_assign`, `azure_nsg_apply`, `azure_storage_lock`, …) as those toolsets open. Do not add a tool without a `v3_type` out and a disposition set.

## 6. Relations (illegal graphs fail here)

| Relation | From | To | Rule |
| --- | --- | --- | --- |
| `hostedIn` | any resource | `ResourceGroup` | required |
| `attachedTo` | `PublicIP` / `NetworkInterface` | `VirtualMachine` | v34 |
| `allowedBy` | `NetworkInterface` / `Subnet` | `NetworkSecurityGroup` | v36 |
| `containedIn` | `Subnet` | `VirtualNetwork` | v36 |
| `identityOf` | `ManagedIdentity` | `VirtualMachine` | v35/v37 |
| `grantedTo` | `RoleAssignment` | `User` / `Group` / `ManagedIdentity` | v35; least-privilege |
| `writesTo` | form / `VirtualMachine` | `BlobContainer` | v37 |
| `compiledFrom` | `ArmTemplate` | Bicep source path | v38 |

**Reject before deploy:**

- `PublicIP` on a subnet marked private
- `BlobContainer` public + “lock access”
- `RoleAssignment` whose `grantedTo` type is not identity
- `azure_deploy` without a prior `azure_bicep_build` when the week claims ARM (v38+)

## 7. Dispositions

| Code | Meaning |
| --- | --- |
| `ok` | live or projected graph accepted |
| `what_if_drift` | template ≠ live |
| `quota` | Free-tier / vCPU / public-IP cap |
| `nsg_deny` | traffic blocked by typed NSG |
| `identity_missing` | managed identity not on the writer |
| `illegal_graph` | relation rule failed (section 6) |
| `teardown_incomplete` | leftover billed resources |
| `auth_denied` | Azure RBAC, not ontology |

## 8. Why this is useful (same as MCP)

Without the ontology, `az vm create` is a string. With it, every op has a kind, a toolset, allowed relations, and a disposition — the same reason GitHub/DCP shims are agent-usable.

Pays off on the VG bar:

- Recreate-from-repo → typed `azure_deploy` / `azure_teardown` / `azure_smoke`
- Least privilege → `RoleAssignment` cannot attach to the wrong `v3_type`
- Network/storage as code → illegal graphs fail in the validator
- Week growth → `novatrix_v34` is tiny; later weeks only add types
- Teacher path stays ARM + README; ontology stays our control plane

## 9. Shim shape (not implemented in this commit)

Mirror DCP, do not invent a second pattern:

```
docs/azure-tool-ontology-v1.0.md          # this file (authority)
src/ontology/v1.0.0/types.ts              # ToolName, V3Type, ProjectionHit
src/ontology/v1.0.0/manifest.json         # version, toolsets, v3_types
scripts/validate-ontology.ts              # types ↔ manifest lockstep
```

`ProjectionHit` is the DCP envelope (`v3_type`, `origin: "azure"`, `state_kind`, `relations`, `next`, `disposition`). Validator fails CI if a tool or type exists on only one side.

## 10. Naming (course + this repo)

Course convention wins for Novatrix hand-in: `typ-företag-syfte` (`rg-novatrix`, `vm-novatrix-web`, `stnovatrix<user>01`). This repo’s `prefix-${appName}-${environment}` names stay valid **inside azure25 modules** when reused as parts.
