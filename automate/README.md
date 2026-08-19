# automate/ — Power Automate (v39)

`ticket-to-sharepoint.json` is a **Logic Apps-style workflow definition** for
manual recreation in the student tenant. It is **not** a portal import package.

Power Automate portal import accepts only a **.zip package** (`manifest.json` +
`Microsoft.Flow/`). This repo does not ship that zip (tenant connections cannot
be pre-wired). Recreate the flow in the designer, or paste this JSON into a
Logic App / the designer's code view and fix the placeholders.

## Chain (VG)

1. **HTTP trigger** (Request) — ticket JSON (same shape as `ticket_app.py`).
2. **SharePoint PostItem** — write to a `Tickets` list.
   - `dataset` must be the **site URL** (`https://<tenant>.sharepoint.com/sites/novatrix`), not a site name.
3. **Condition** on `category == critical` (form option **Kritiskt**):
   - **true** → Teams `PostMessageToConversation` with
     `body/recipient: { groupId: TEAM_ID, channelId: CHANNEL_ID }`
   - **else** → Outlook `SendEmailV2` (`emailMessage/To|Subject|Body`)

The VM app POSTs to this HTTP trigger only when `NOVATRIX_FLOW_URL` is set
on the unit (empty by default — chain is standalone until you paste the
trigger URL).

## Manual steps (external)

1. Open <https://make.powerautomate.com> in the student tenant.
2. Create a new **Automated cloud flow** (or Instant + HTTP request).
3. Add the three actions above. Create connections:
   - SharePoint (`shared_sharepointonline`)
   - Teams (`shared_teams`)
   - Office 365 Outlook (`shared_office365`)
4. Replace placeholders:
   - SharePoint site URL and list name
   - Teams team/channel IDs (`REPLACE_WITH_TEAM_ID`, `REPLACE_WITH_CHANNEL_ID`)
5. Copy the HTTP trigger URL and POST a sample ticket to test the chain.

No secrets are stored in this repo.
