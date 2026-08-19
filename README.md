# Novatrix AB — Azure-kurs v34–v40 (lärarhandledning / teacher guide)

Detta repo är elevens Azure-kursarbete för Novatrix AB: en supportticket-tjänst
på Azure, byggd vecka för vecka (v34–v40). Dokumentet vänder sig till läraren
och beskriver vad som finns, hur man återskapar miljön, och vad som bedöms.

> **Ärlighetsnotis:** en live-deploy har körts i elevens prenumeration
> (Sweden Central, `Standard_B2ats_v2` — `Standard_B1s` fanns inte på
> den free-subben). Committade parametrar är placeholders (ingen SSH-nyckel
> eller hem-IP i GitHub). Återskapa med egen `ssh-rsa`-nyckel och `/32`-CIDR.
> v39 Power Automate kräver manuell import i M365-tenant. Riv dagligen.

## Innehåll

- [Supportticket-formuläret](#supportticket-formuläret-ubuntu--nginx)
- [Återskapa från repot](#återskapa-från-repot)
- [Daglig rivning](#daglig-rivning)
- [Namngivning typ-företag-syfte](#namngivning-typ-företag-syfte)
- [Veckoplan v34–v40](#veckoplan-v34v40)
- [Inlämning: ARM JSON är projektionen](#inlämning-arm-json-är-projektionen)
- [VG-punkter](#vg-punkter)
- [Ontologin är kontrollplanet](#ontologin-är-kontrollplanet)

## Supportticket-formuläret (Ubuntu + Nginx)

En Ubuntu-VM (v34) kör en liten Python-HTTP-tjänst bakom nginx:

```
Browser ──80──▶ nginx (reverse proxy) ──8080──▶ ticket_app.py
                                                  │
                                                  ├─▶ /var/lib/novatrix/tickets/<id>.json  (alltid)
                                                  └─▶ blob container `tickets`               (best-effort, fail closed)
```

- `web/index.html` — formuläret (namn, e-post, kategori, beskrivning, valfri
  filanteckning). POST:ar till `/ticket`.
- `web/ticket_app.py` — stdlib-only Python 3 HTTP-helper som körs **på VM:n**
  (inte repo-automation; vault-regeln om Python gäller repo-verktyg, inte
  kursappen). Skriver alltid JSON lokalt; laddar upp till blob endast om
  `azure-identity`/`azure-storage-blob` finns installerade och managed
  identity fungerar. **Fail closed:** blob-fel påverkar aldrig det lokala
  ärendet.
- `web/cloud-init.yaml` — cloud-config som installerar nginx + python3,
  skriver form + app, startar appen via systemd på 8080 och sätter upp
  reverse proxy 80 → 8080. (Källan för de inbäddade filerna är `web/`.)

## Återskapa från repot

1. Skapa en RSA-nyckel (Azure Linux-VM:er tar **inte** ed25519):

   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/novatrix -N ''
   ```

2. Klistra in `~/.ssh/novatrix.pub` i `envs/novatrix.parameters.json`
   (`adminSshPublicKey`). Sätt `allowedSshCidr` till din publika IP `/32`
   (default `203.0.113.0/32` är TEST-NET, inte world-open). `deploy.sh`
   vägrar placeholder-nyckel och `0.0.0.0/0` (override: `--allow-world-ssh`).

3. Kör:

   ```bash
   ./scripts/bootstrap.sh && ./scripts/bicep-build.sh && ./scripts/deploy.sh
   ```

   - `scripts/bootstrap.sh` — resursgrupp + providers.
   - `scripts/bicep-build.sh` — Bicep → `build/main.json`.
   - `scripts/deploy.sh` — ARM-mallen (VM, identitet, nätverk, storage).

## Daglig rivning

```bash
./scripts/teardown.sh
```

Rivning av resursgruppen för att undvika kostnader när kursen inte används.
Körs dagligen av eleven/läraren efter övningstillfället.

## Namngivning typ-företag-syfte

Alla Azure-resurser följer mönstret **`<typ>-<företag>-<syfte>`** (storage
accounts tillåter inte `-` och använder prefixet `st` + studentprefix):

| Typ | Exempel i repot |
|-----|-----------------|
| Resursgrupp | `rg-novatrix` |
| Virtuell maskin | `vm-novatrix-web` |
| Public IP / NIC | `pip-novatrix-web` / `nic-novatrix-web` |
| Managed identity | `id-novatrix-web` |
| Storage account | `stnovatrix<prefix>01` (t.ex. `stnovatrixdanlin01`) |
| VNet / subnät | `vnet-novatrix-core` / `snet-novatrix-web`, `snet-novatrix-data` |
| NSG | `nsg-novatrix-web`, `nsg-novatrix-data` |
| Bastion | `bas-novatrix` |
| Function app (v40-stub) | `func-novatrix-tickets` |

## Veckoplan v34–v40

Se [`docs/weeks.md`](docs/weeks.md) — en tabell med vecka, deadline, G/VG och
vilka filer som implementerar varje vecka.

## Inlämning: ARM JSON är projektionen

- **Bicep är författningskällan** (`infra/*.bicep`).
- **ARM JSON är inlämningsprojektionen**: `build/main.json` (efter
  `./scripts/bicep-build.sh`) är det som lämnas in som bevis på
  infrastruktur-som-kod.
- `infra/function.bicep` är en **opt-in v40-stub** — inte del av default
  deployment och inte inkluderad i `deploy.sh`.

## VG-punkter

| Område | Var det syns |
|--------|--------------|
| Cloud-init som kod | `web/cloud-init.yaml` + `infra/compute.bicep` (customData) |
| Least-privilege MI + RBAC | `infra/identity.bicep`, roller med minsta scope |
| Network as code | `infra/network.bicep` (VNet/subnet/NSG/Bastion) |
| Privat storage | `infra/storage.bicep` (`networkAcls` default Deny + service endpoints; ingen CanNotDelete-lås) |
| Parameteriserad ARM | `infra/*.bicep` → `build/main.json` (parametrar för namn, plats, SKU) |
| Automate-kedja | `automate/` — manuell återskapning i tenant (inte portal-zip) |
| Compute-jämförelse | `docs/v40-compute-compare.md` (VM vs Container Apps/ACI vs Functions) |

## Ontologin är kontrollplanet

`docs/` + `src/ontology/` beskriver verktygsytan och veckokraven (v34–v40) som
**kontrollplan** för kursens verktyg — det är **inte** lärarbedömningsartefakten.
Bedömningen utgår från de faktiska artefakterna ovan (Bicep/ARM, cloud-init,
app, Automate-skiss, jämförelsedokument).

## Filstruktur

```
README.md                  ← detta dokument
docs/weeks.md              ← veckoplan v34–v40
docs/v40-compute-compare.md← VM vs Container Apps/ACI vs Functions
web/index.html             ← ticketformuläret
web/ticket_app.py          ← app på VM:n (stdlib-only, fail closed till disk)
web/cloud-init.yaml        ← cloud-config (nginx + python3 + systemd + proxy)
automate/ticket-to-sharepoint.json ← Power Automate-skiss (manuell import)
automate/README.md         ← hur importen görs i studenttenanten
infra/function.bicep       ← OPTIONAL v40-stub (inte i default deploy)
infra/*.bicep              ← Bicep-källan (main, compute, identity, network, storage)
scripts/*.sh               ← bootstrap / bicep-build / deploy / teardown
src/ontology/              ← kontrollplan (verktygsontologi)
```