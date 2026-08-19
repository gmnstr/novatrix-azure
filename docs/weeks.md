# Veckoplan v34–v40 — Novatrix AB Azure-kurs

Deadlines följer kursplanen (söndag i respektive vecka). G = godkänt, VG = väl godkänt.

| Vecka | Deadline | G | VG | Filer som implementerar |
|-------|----------|----|----|--------------------------|
| v34 | 2026-08-23 | Ubuntu-VM + Nginx + formulär på publik IP | CLI/cloud-init, återskapa från repo | `web/index.html`, `web/ticket_app.py`, `web/cloud-init.yaml`, `infra/compute.bicep`, `scripts/bootstrap.sh`, `scripts/deploy.sh` |
| v35 | 2026-08-30 | Entra-användare/grupp, managed identity, RBAC (inga extra rättigheter) | Least-privilege via CLI/IaC | `infra/identity.bicep`, `scripts/identity.sh` |
| v36 | 2026-09-06 | VNet publik webb + privat storage, NSG | Bastion-hopp + nätverk som kod | `infra/network.bicep` |
| v37 | 2026-09-13 | Blob för ärenden/filer, formulär skriver, låst åtkomst | Managed identity + storage som kod | `infra/storage.bicep`, `web/ticket_app.py` |
| v38 | 2026-09-20 | ARM-mallar för kärnbitarna | Hela miljön parameteriserad ARM | `scripts/bicep-build.sh`, `build/main.json`, `infra/*.bicep` |
| v39 | 2026-09-27 | Power Automate ticket→SharePoint | Flerstegskedja (+ Teams/Outlook) | `automate/ticket-to-sharepoint.json`, `automate/README.md` |
| v40 | 2026-10-04 | Container eller Function + jämför VM/container/serverless | Motivera + IaC | `docs/v40-compute-compare.md`, `infra/function.bicep` |

## Noter

- **v34 kräver VM** — den nuvarande deploymenten är en VM; v40-jämförelsen är
  ett analysdokument, inte en migrering.
- **ARM JSON är inlämningsprojektionen**: `build/main.json` (efter
  `./scripts/bicep-build.sh`) är det som lämnas in; Bicep-filerna är
  författningskällan.
- **Ontologin** (`docs/` + `src/ontology/`) är kontrollplanet för verktygen —
  inte lärarbedömningsartefakten.
- Inga live Azure-deployer har körts från detta repo; skripten finns för att
  eleven/läraren ska kunna köra dem.
- **v37 "låst åtkomst"** betyder nätverksregler (`networkAcls` default Deny +
  service endpoints) och RBAC/MI — inte `CanNotDelete`-resurslås (det skulle
  blockera daglig rivning).
