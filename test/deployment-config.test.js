import assert from "node:assert/strict";
import fs from "node:fs/promises";
import test from "node:test";

test("Compose bindet die API nur an Loopback und enthaelt keine Umgebungswerte", async () => {
  const compose = await fs.readFile(new URL("../compose.yml", import.meta.url), "utf8");
  assert.match(compose, /127\.0\.0\.1:\$\{TSCHLUESSLI_HOST_PORT/);
  assert.doesNotMatch(compose, /(?:^|\s)-\s*["']?3000:3000/m);
  assert.match(compose, /mysql-ca\.cert:ro/);
  assert.match(compose, /no-new-privileges:true/);
  assert.match(compose, /cap_drop:\s*\n\s*- ALL/);
  assert.doesNotMatch(compose, /tschluessli_(?:dev|prod)|APP_ENV:\s*(?:development|production)/);
  assert.equal((compose.match(/image: \$\{TSCHLUESSLI_IMAGE_REF/g) || []).length, 3);
});

test("Docker-Kontext schliesst App, Git, Builds und Secretdateien aus", async () => {
  const ignored = await fs.readFile(new URL("../.dockerignore", import.meta.url), "utf8");
  for (const entry of [".git", ".env", "node_modules", ".build", ".vercel", "Tschluessli", "Tschluessli.xcodeproj", "*.pem", "*.key"]) {
    assert.match(ignored, new RegExp(`^${escape(entry)}$`, "m"));
  }
});

test("Docker-Image laeuft ohne Root und enthaelt nur Backend-Verzeichnisse", async () => {
  const dockerfile = await fs.readFile(new URL("../Dockerfile", import.meta.url), "utf8");
  assert.match(dockerfile, /USER node/);
  assert.match(dockerfile, /COPY --chown=node:node api \.\/api/);
  assert.match(dockerfile, /COPY --chown=node:node database \.\/database/);
  assert.doesNotMatch(dockerfile, /COPY\s+\.\s+\./);
});

function escape(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
