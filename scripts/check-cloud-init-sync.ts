#!/usr/bin/env bun
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = join(import.meta.dir, "..");
const cloudInit = readFileSync(join(root, "web/cloud-init.yaml"), "utf8");
const html = readFileSync(join(root, "web/index.html"), "utf8").replace(/\n$/, "");
const app = readFileSync(join(root, "web/ticket_app.py"), "utf8").replace(/\n$/, "");

function extractWriteFile(yaml: string, path: string): string | null {
  const marker = `  - path: ${path}`;
  const start = yaml.indexOf(marker);
  if (start < 0) return null;
  const contentIdx = yaml.indexOf("content: |", start);
  if (contentIdx < 0) return null;
  const bodyStart = yaml.indexOf("\n", contentIdx) + 1;
  const rest = yaml.slice(bodyStart);
  const lines = rest.split("\n");
  const extracted: string[] = [];
  for (const line of lines) {
    if (line.startsWith("  - path:") || line === "runcmd:") break;
    if (line.startsWith("      ")) extracted.push(line.slice(6));
    else if (line.trim() === "") extracted.push("");
    else break;
  }
  while (extracted.length && extracted[extracted.length - 1] === "") extracted.pop();
  return extracted.join("\n");
}

const errors: string[] = [];
const embeddedHtml = extractWriteFile(cloudInit, "/var/www/novatrix/index.html");
const embeddedApp = extractWriteFile(cloudInit, "/opt/novatrix/ticket_app.py");
if (embeddedHtml !== html) {
  errors.push("web/index.html != cloud-init embed at /var/www/novatrix/index.html");
}
if (embeddedApp !== app) {
  errors.push("web/ticket_app.py != cloud-init embed at /opt/novatrix/ticket_app.py");
}
if (!cloudInit.includes("Environment=NOVATRIX_STORAGE_ACCOUNT=__NOVATRIX_STORAGE_ACCOUNT__")) {
  errors.push("cloud-init missing storage-account placeholder");
}
if (!cloudInit.includes("Environment=AZURE_CLIENT_ID=__NOVATRIX_MI_CLIENT_ID__")) {
  errors.push("cloud-init missing MI client-id placeholder");
}
if (cloudInit.includes("--break-system-packages")) {
  errors.push("cloud-init still uses pip --break-system-packages (fails on Ubuntu 22.04 pip 22.0.2)");
}

if (errors.length) {
  for (const e of errors) console.error(`FAILED: ${e}`);
  process.exit(1);
}
console.log("[novatrix-azure] check-cloud-init-sync OK");
