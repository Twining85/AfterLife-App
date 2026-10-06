import { mutationHash } from "./_sync-contract.js";
import { storageService } from "./_storage.js";
import { syncAutomaticReleasePolicies } from "./_trust-policy.js";
import { saveAccessMetadata } from "./_access-metadata.js";
import { validateE2EMutation } from "./_e2e-contract.js";

export async function applySectionMutation(client, userID, mutation) {
  mutation = validateE2EMutation(mutation);
  if (client.engine === "mysql") return applyMySQLSectionMutation(client, userID, mutation);
  const requestHash = mutationHash(mutation);
  await client.query("SELECT pg_advisory_xact_lock(hashtext($1))", [
    `idempotency:${userID}:${mutation.idempotencyKey}`
  ]);
  await client.query(
    `DELETE FROM sync_idempotency
      WHERE owner_user_id = $1 AND idempotency_key = $2 AND expires_at <= now()`,
    [userID, mutation.idempotencyKey]
  );

  const replay = await client.query(
    `SELECT request_hash, response_status, response_body
       FROM sync_idempotency
      WHERE owner_user_id = $1 AND idempotency_key = $2`,
    [userID, mutation.idempotencyKey]
  );
  if (replay.rows[0]) {
    if (replay.rows[0].request_hash !== requestHash) {
      return result(409, { error: "Idempotency-Key wurde für andere Daten verwendet", code: "idempotency_mismatch" });
    }
    return result(Number(replay.rows[0].response_status), replay.rows[0].response_body, true);
  }

  await client.query("SELECT pg_advisory_xact_lock(hashtext($1))", [
    `section:${mutation.dossierID}:${mutation.sectionType}`
  ]);
  const dossier = await client.query(
    "SELECT id FROM dossiers WHERE id = $1 AND owner_user_id = $2",
    [mutation.dossierID, userID]
  );
  if (!dossier.rows[0]) {
    return storeResult(client, userID, mutation, requestHash, 404, {
      error: "Dossier nicht gefunden",
      code: "dossier_not_found"
    });
  }

  const currentResult = await client.query(
    `SELECT schema_version, revision, encryption_version, payload, deleted_at, updated_at
       FROM dossier_sections
      WHERE dossier_id = $1 AND section_type = $2`,
    [mutation.dossierID, mutation.sectionType]
  );
  const current = currentResult.rows[0];
  const currentRevision = current ? Number(current.revision) : 0;
  if (currentRevision !== mutation.expectedRevision) {
    return storeResult(client, userID, mutation, requestHash, 409, {
      error: "Daten wurden zwischenzeitlich geändert",
      code: "revision_conflict",
      current: current ? await hydratedSectionResponse(mutation.dossierID, mutation.sectionType, current) : null
    });
  }

  if (Number(current?.encryption_version) === 2 && mutation.operation === "upsert" && mutation.payload?.formatVersion !== 2) {
    return storeResult(client, userID, mutation, requestHash, 422, {
      error: "Ein verschlüsselter Bereich darf nicht auf Klartext zurückgesetzt werden", code: "encryption_downgrade"
    });
  }
  const encryptionVersion = Number(current?.encryption_version) === 2 || mutation.payload?.formatVersion === 2 ? 2 : 1;
  const revision = currentRevision + 1;
  const deleted = mutation.operation === "delete";
  const storedPayload = deleted ? {} : await storageService().storeSectionPayload({
    dossierID: mutation.dossierID,
    sectionType: mutation.sectionType,
    revision,
    payload: mutation.payload
  });
  const saved = await client.query(
    `INSERT INTO dossier_sections
       (dossier_id, owner_user_id, section_type, schema_version, revision, payload, deleted_at, encryption_version)
     VALUES ($1, $2, $3, $4, $5, $6::jsonb, CASE WHEN $7 THEN now() ELSE NULL END, $8)
     ON CONFLICT (dossier_id, section_type) DO UPDATE
       SET encryption_version = EXCLUDED.encryption_version,
           schema_version = EXCLUDED.schema_version,
           revision = EXCLUDED.revision,
           payload = EXCLUDED.payload,
           deleted_at = EXCLUDED.deleted_at,
           updated_at = now()
     RETURNING schema_version, revision, payload, deleted_at, updated_at`,
    [
      mutation.dossierID,
      userID,
      mutation.sectionType,
      mutation.schemaVersion,
      revision,
      JSON.stringify(storedPayload),
      deleted,
      encryptionVersion
    ]
  );
  const savedSection = saved.rows[0];
  if (encryptionVersion === 2 && ["kontakte", "dossier_einstellungen"].includes(mutation.sectionType)) {
    await saveAccessMetadata(client, userID, mutation, revision);
  } else if (mutation.sectionType === "kontakte") {
    await syncAutomaticReleasePolicies(client, userID, mutation.dossierID, deleted ? null : mutation.payload);
  }
  const change = await client.query(
    `INSERT INTO sync_changes
       (owner_user_id, dossier_id, section_type, schema_version, revision, operation, payload, access_metadata)
     VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, $8::jsonb)
     RETURNING change_id, changed_at`,
    [
      userID,
      mutation.dossierID,
      mutation.sectionType,
      mutation.schemaVersion,
      revision,
      mutation.operation,
      deleted ? null : JSON.stringify(storedPayload),
      mutation.accessMetadata ? JSON.stringify(mutation.accessMetadata) : null
    ]
  );
  const body = {
    ...mutationResponse(mutation.dossierID, mutation.sectionType, savedSection),
    operation: mutation.operation,
    cursor: String(change.rows[0].change_id),
    changedAt: isoDate(change.rows[0].changed_at)
  };
  return storeResult(client, userID, mutation, requestHash, 200, body);
}

export async function changesSince(client, userID, cursor, limit = 100) {
  if (client.engine === "mysql") return mysqlChangesSince(client, userID, cursor, limit);
  const rows = await client.query(
    `SELECT change_id, dossier_id, section_type, schema_version, revision,
            operation, payload, access_metadata, changed_at
       FROM sync_changes
      WHERE owner_user_id = $1 AND change_id > $2::bigint
      ORDER BY change_id
      LIMIT $3`,
    [userID, cursor, limit + 1]
  );
  const hasMore = rows.rows.length > limit;
  const selected = rows.rows.slice(0, limit);
  return {
    changes: await Promise.all(selected.map(async (row) => ({
      cursor: String(row.change_id),
      dossierID: row.dossier_id,
      sectionType: row.section_type,
      schemaVersion: Number(row.schema_version),
      revision: Number(row.revision),
      operation: row.operation,
      payload: row.operation === "delete" ? null : await storageService().loadSectionPayload(
        row.payload,
        { dossierID: row.dossier_id, sectionType: row.section_type }
      ),
      ...(row.access_metadata ? { accessMetadata: parseJSON(row.access_metadata) } : {}),
      changedAt: isoDate(row.changed_at)
    }))),
    nextCursor: selected.length ? String(selected.at(-1).change_id) : cursor,
    hasMore
  };
}

export async function currentSnapshot(client, userID, dossierID) {
  // Cursor zuerst lesen: Eine danach parallel gespeicherte Änderung darf im
  // Snapshot bereits enthalten sein, wird wegen des älteren Cursors später
  // aber nochmals regulär synchronisiert und kann so niemals verloren gehen.
  const cursorResult = await client.query(
    // `CURSOR` ist in MySQL ein reserviertes Wort. Ein unquotierter Alias
    // gleichen Namens lässt den gesamten Recovery-Snapshot dort mit einem
    // Syntaxfehler abbrechen.
    "SELECT COALESCE(MAX(change_id), 0) AS sync_cursor FROM sync_changes WHERE owner_user_id = $1",
    [userID]
  );
  const sectionsResult = await client.query(
    `SELECT s.dossier_id, s.section_type, s.schema_version, s.revision, s.payload, s.updated_at,
            m.metadata AS access_metadata
       FROM dossier_sections s
       LEFT JOIN dossier_access_metadata m ON m.dossier_id = s.dossier_id AND m.section_type = s.section_type
        AND m.revision = s.revision AND s.encryption_version = 2
      WHERE s.dossier_id = $1 AND s.owner_user_id = $2 AND s.deleted_at IS NULL
      ORDER BY s.section_type`,
    [dossierID, userID]
  );
  const cursor = String(cursorResult.rows[0]?.sync_cursor ?? "0");
  const changes = await Promise.all(sectionsResult.rows.map(async (row) => ({
    cursor,
    dossierID: row.dossier_id,
    sectionType: row.section_type,
    schemaVersion: Number(row.schema_version),
    revision: Number(row.revision),
    operation: "upsert",
    payload: await storageService().loadSectionPayload(
      row.payload,
      { dossierID: row.dossier_id, sectionType: row.section_type }
    ),
    ...(row.access_metadata ? { accessMetadata: parseJSON(row.access_metadata) } : {}),
    changedAt: isoDate(row.updated_at)
  })));
  return { changes, nextCursor: cursor, hasMore: false };
}

async function storeResult(client, userID, mutation, requestHash, statusCode, body) {
  await client.query(
    `INSERT INTO sync_idempotency
       (owner_user_id, idempotency_key, request_hash, response_status, response_body)
     VALUES ($1, $2, $3, $4, $5::jsonb)`,
    [userID, mutation.idempotencyKey, requestHash, statusCode, JSON.stringify(body)]
  );
  return result(statusCode, body);
}

function result(statusCode, body, replayed = false) {
  return { statusCode, body, replayed };
}

function sectionResponse(dossierID, sectionType, row) {
  const deleted = Boolean(row.deleted_at);
  return {
    dossierID,
    sectionType,
    schemaVersion: Number(row.schema_version),
    revision: Number(row.revision),
    payload: deleted ? null : row.payload,
    deleted,
    updatedAt: isoDate(row.updated_at)
  };
}

async function hydratedSectionResponse(dossierID, sectionType, row) {
  const response = sectionResponse(dossierID, sectionType, row);
  if (!response.deleted) {
    response.payload = await storageService().loadSectionPayload(response.payload, {
      dossierID,
      sectionType
    });
  }
  return response;
}

function mutationResponse(dossierID, sectionType, row) {
  const { payload: _payload, ...response } = sectionResponse(dossierID, sectionType, row);
  return response;
}

function isoDate(value) {
  return value instanceof Date ? value.toISOString() : String(value);
}

async function applyMySQLSectionMutation(client, userID, mutation) {
  const requestHash = mutationHash(mutation);
  await client.acquireLock(`idempotency:${userID}:${mutation.idempotencyKey}`);
  await client.acquireLock(`section:${mutation.dossierID}:${mutation.sectionType}`);
  await client.query(
    `DELETE FROM sync_idempotency
      WHERE owner_user_id = $1 AND idempotency_key = $2 AND expires_at <= CURRENT_TIMESTAMP(6)`,
    [userID, mutation.idempotencyKey]
  );
  const replay = await client.query(
    `SELECT request_hash, response_status, response_body FROM sync_idempotency
      WHERE owner_user_id = $1 AND idempotency_key = $2 FOR UPDATE`,
    [userID, mutation.idempotencyKey]
  );
  if (replay.rows[0]) {
    const responseBody = parseJSON(replay.rows[0].response_body);
    if (replay.rows[0].request_hash !== requestHash) {
      return result(409, { error: "Idempotency-Key wurde für andere Daten verwendet", code: "idempotency_mismatch" });
    }
    return result(Number(replay.rows[0].response_status), responseBody, true);
  }
  const dossier = await client.query(
    "SELECT id FROM dossiers WHERE id = $1 AND owner_user_id = $2 FOR UPDATE",
    [mutation.dossierID, userID]
  );
  if (!dossier.rows[0]) {
    return storeMySQLResult(client, userID, mutation, requestHash, 404, {
      error: "Dossier nicht gefunden", code: "dossier_not_found"
    });
  }
  const currentResult = await client.query(
    `SELECT schema_version, revision, encryption_version, payload, deleted_at, updated_at
       FROM dossier_sections WHERE dossier_id = $1 AND section_type = $2 FOR UPDATE`,
    [mutation.dossierID, mutation.sectionType]
  );
  const current = normalizeJSONRow(currentResult.rows[0]);
  const currentRevision = current ? Number(current.revision) : 0;
  if (currentRevision !== mutation.expectedRevision) {
    return storeMySQLResult(client, userID, mutation, requestHash, 409, {
      error: "Daten wurden zwischenzeitlich geändert",
      code: "revision_conflict",
      current: current ? await hydratedSectionResponse(mutation.dossierID, mutation.sectionType, current) : null
    });
  }
  if (Number(current?.encryption_version) === 2 && mutation.operation === "upsert" && mutation.payload?.formatVersion !== 2) {
    return storeMySQLResult(client, userID, mutation, requestHash, 422, {
      error: "Ein verschlüsselter Bereich darf nicht auf Klartext zurückgesetzt werden", code: "encryption_downgrade"
    });
  }
  const encryptionVersion = Number(current?.encryption_version) === 2 || mutation.payload?.formatVersion === 2 ? 2 : 1;
  const revision = currentRevision + 1;
  const deleted = mutation.operation === "delete";
  const storedPayload = deleted ? {} : await storageService().storeSectionPayload({
    dossierID: mutation.dossierID,
    sectionType: mutation.sectionType,
    revision,
    payload: mutation.payload
  });
  await client.query(
    `INSERT INTO dossier_sections
       (dossier_id, owner_user_id, section_type, schema_version, revision, payload, deleted_at, encryption_version)
     VALUES ($1, $2, $3, $4, $5, $6, CASE WHEN $7 THEN CURRENT_TIMESTAMP(6) ELSE NULL END, $8)
     ON DUPLICATE KEY UPDATE encryption_version = GREATEST(encryption_version, VALUES(encryption_version)),
       schema_version = VALUES(schema_version), revision = VALUES(revision),
       payload = VALUES(payload), deleted_at = VALUES(deleted_at), updated_at = CURRENT_TIMESTAMP(6)`,
    [mutation.dossierID, userID, mutation.sectionType, mutation.schemaVersion, revision,
      deleted ? null : JSON.stringify(storedPayload), deleted, encryptionVersion]
  );
  const saved = await client.query(
    `SELECT schema_version, revision, encryption_version, payload, deleted_at, updated_at FROM dossier_sections
      WHERE dossier_id = $1 AND section_type = $2`,
    [mutation.dossierID, mutation.sectionType]
  );
  if (encryptionVersion === 2 && ["kontakte", "dossier_einstellungen"].includes(mutation.sectionType)) {
    await saveAccessMetadata(client, userID, mutation, revision);
  } else if (mutation.sectionType === "kontakte") {
    await syncAutomaticReleasePolicies(client, userID, mutation.dossierID, deleted ? null : mutation.payload);
  }
  const change = await client.query(
    `INSERT INTO sync_changes
       (owner_user_id, dossier_id, section_type, schema_version, revision, operation, payload, access_metadata)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
    [userID, mutation.dossierID, mutation.sectionType, mutation.schemaVersion, revision,
      mutation.operation, deleted ? null : JSON.stringify(storedPayload),
      mutation.accessMetadata ? JSON.stringify(mutation.accessMetadata) : null]
  );
  const changed = await client.query(
    "SELECT change_id, changed_at FROM sync_changes WHERE change_id = $1",
    [String(change.insertId)]
  );
  const body = {
    ...mutationResponse(mutation.dossierID, mutation.sectionType, normalizeJSONRow(saved.rows[0])),
    operation: mutation.operation,
    cursor: String(changed.rows[0].change_id),
    changedAt: isoDate(changed.rows[0].changed_at)
  };
  return storeMySQLResult(client, userID, mutation, requestHash, 200, body);
}

async function mysqlChangesSince(client, userID, cursor, limit) {
  const resultRows = await client.query(
    `SELECT change_id, dossier_id, section_type, schema_version, revision,
            operation, payload, access_metadata, changed_at FROM sync_changes
      WHERE owner_user_id = $1 AND change_id > $2 ORDER BY change_id LIMIT ${Number(limit) + 1}`,
    [userID, cursor]
  );
  const normalized = resultRows.rows.map(normalizeJSONRow);
  const hasMore = normalized.length > limit;
  const selected = normalized.slice(0, limit);
  return {
    changes: await Promise.all(selected.map(async (row) => ({
      cursor: String(row.change_id), dossierID: row.dossier_id, sectionType: row.section_type,
      schemaVersion: Number(row.schema_version), revision: Number(row.revision), operation: row.operation,
      payload: row.operation === "delete" ? null : await storageService().loadSectionPayload(
        row.payload,
        { dossierID: row.dossier_id, sectionType: row.section_type }
      ),
      ...(row.access_metadata ? { accessMetadata: parseJSON(row.access_metadata) } : {}),
      changedAt: isoDate(row.changed_at)
    }))),
    nextCursor: selected.length ? String(selected.at(-1).change_id) : cursor,
    hasMore
  };
}

async function storeMySQLResult(client, userID, mutation, requestHash, statusCode, body) {
  await client.query(
    `INSERT INTO sync_idempotency
       (owner_user_id, idempotency_key, request_hash, response_status, response_body, expires_at)
     VALUES ($1, $2, $3, $4, $5, DATE_ADD(CURRENT_TIMESTAMP(6), INTERVAL 30 DAY))`,
    [userID, mutation.idempotencyKey, requestHash, statusCode, JSON.stringify(body)]
  );
  return result(statusCode, body);
}

function normalizeJSONRow(row) {
  if (!row) return row;
  return { ...row, payload: parseJSON(row.payload), response_body: parseJSON(row.response_body) };
}
function parseJSON(value) {
  if (typeof value !== "string") return value;
  try { return JSON.parse(value); } catch { return value; }
}
