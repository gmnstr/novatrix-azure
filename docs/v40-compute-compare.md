# v40 — Compute-jämförelse: VM vs Container Apps/ACI vs Azure Functions

**Workload:** Novatrix AB supportticket-formulär — en liten HTTP-tjänst
(nginx + Python) som tar emot POST /ticket, skriver JSON till disk och
laddar upp till blob (`tickets`). Låg trafik, enkelt API, ingen tung
beräkning.

> **Ärlighet:** den nuvarande deploymenten är en **VM** eftersom **v34 kräver
> det**. Den här jämförelsen är v40-leveransen — ett analysdokument, inte en
> migrering.

## Jämförelse

| Aspekt | VM (nuvarande) | Container Apps | ACI | Azure Functions |
|--------|----------------|----------------|-----|-----------------|
| **Kostnad** | Betalar 24/7 för VM-storleken, oavsett trafik | Betalar per aktiv replik; kan skala till noll | Betalar per sekund medan containern kör; ingen auto-scale | Betalar per exekvering (Consumption); gratis vid ingen trafik |
| **Drift** | Du patchar OS, uppdaterar nginx/Python, övervakar själv | Plattformen hanterar patching av runtime; du äger bara containern | Plattformen hanterar containern; ingen OS-patch | Plattformen hanterar runtime; ingen OS-patch |
| **Skalning** | Manuell (ändra VM-storlek eller lägg till VM:ar) | Automatisk skalning (repliker, KEDA) | Ingen inbyggd auto-scale/load balancing | Automatisk skalning per exekvering; **cold start** vid inaktivitet |
| **Passform för formulär** | Utmärkt — full kontroll, enkel nginx+Python | Bra — samma containerbild, hanterad ingress | Okej — men ingen inbyggd HTTP-routing/load balancing | Sämst — Functions är byggda för API-endpoints/event, inte för att servera HTML-formulär + statiska assets |
| **Identitet** | Managed identity + RBAC (kräver konfiguration) | Managed identity inbyggt | Managed identity inbyggt | Managed identity inbyggt |
| **Nätverk** | Full kontroll (VNet, NSG, Bastion) | VNet-integration möjlig | VNet-integration möjlig | VNet-integration möjlig |

## Rekommendation för produktionslik Novatrix: **Azure Container Apps**

Motivering:

1. **Kostnad** — skala till noll gör att ett internt supportformulär med låg
   trafik kostar nära noll när ingen använder det, medan en VM betalar dygnet
   runt.
2. **Drift** — ingen OS-patchning, ingen nginx/Python-uppdatering på servern;
   samma containerbild som idag (nginx + Python) kan återanvändas.
3. **Skalning** — automatisk replikering vid trafiktoppar utan manuella
   VM-ändringar.
4. **Identitet** — managed identity + RBAC är förstklassigt inbyggt, vilket
   matchar kursens VG-krav (least-privilege).

**Varför inte ACI:** ACI är utmärkt för batch-jobb och korta containrar, men
saknar inbyggd auto-scale och HTTP-routing — en persistent webbtjänst får man
bygga själv.

**Varför inte Functions:** Functions är event-drivna och har cold starts; att
servera ett HTML-formulär och hantera en enkel POST är inte dess styrka. Det
skulle fungera som API-endpoint. Container Apps passar hela formulärflödet
bättre (ingress + container), men **scale-to-zero ger också cold start**
(nästa request efter noll repliker startar om containern). Sätt min replicas
≥ 1 om cold start inte är acceptabelt.

**Varför inte VM i produktion:** full kontroll är bra för kursen (v34), men i
produktion betalar man för tomgång och tar på sig OS-patchning — onödig drift
för en så liten tjänst.

## Referens

- `infra/function.bicep` — Consumption Functions-stub (inte i default
  deployment) som visar alternativet.
- `web/cloud-init.yaml` — VM-vägen (v34-kravet).