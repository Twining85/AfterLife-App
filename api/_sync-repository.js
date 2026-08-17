import { mutationHash } from "./_sync-contract.js";

export async function applySectionMutation(client, userID, mutation) {
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
    `SELECT schema_version, revision, payload, deleted_at, updated_at
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
      current: current ? sectionResponse(mutation.dossierID, mutation.sectionType, current) : null
    });
  }

  const revision = currentRevision + 1;
  const deleted = mutation.operation === "delete";
  const saved = await client.query(
    `INSERT INTO dossier_sections
       (dossier_id, owner_user_id, section_type, schema_version, revision, payload, deleted_at)
     VALUES ($1, $2, $3, $4, $5, $6::jsonb, CASE WHEN $7 THEN now() ELSE NULL END)
     ON CONFLICT (dossier_id, section_type) DO UPDATE
       SET schema_version = EXCLUDED.schema_version,
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
      JSON.stringify(deleted ? {} : mutation.payload),
      deleted
    ]
  );
  const savedSection = saved.rows[0];
  const change = await client.query(
    `INSERT INTO sync_changes
       (owner_user_id, dossier_id, section_type, schema_version, revision, operation, payload)
     VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb)
     RETURNING change_id, changed_at`,
    [
      userID,
      mutation.dossierID,
      mutation.sectionType,
      mutation.schemaVersion,
      revision,
      mutation.operation,
      deleted ? null : JSON.stringify(mutation.payload)
    ]
  );
  const body = {
    ...sectionResponse(mutation.dossierID, mutation.sectionType, savedSection),
    operation: mutation.operation,
    cursor: String(change.rows[0].change_id),
    changedAt: isoDate(change.rows[0].changed_at)
  };
  return storeResult(client, userID, mutation, requestHash, 200, body);
}

export async function changesSince(client, userID, cursor, limit = 100) {
  const rows = await client.query(
    `SELECT change_id, dossier_id, section_type, schema_version, revision,
            operation, payload, changed_at
       FROM sync_changes
      WHERE owner_user_id = $1 AND change_id > $2::bigint
      ORDER BY change_id
      LIMIT $3`,
    [userID, cursor, limit + 1]
  );
  const hasMore = rows.rows.length > limit;
  const selected = rows.rows.slice(0, limit);
  return {
    changes: selected.map((row) => ({
      cursor: String(row.change_id),
      dossierID: row.dossier_id,
      sectionType: row.section_type,
      schemaVersion: Number(row.schema_version),
      revision: Number(row.revision),
      operation: row.operation,
      payload: row.operation === "delete" ? null : row.payload,
      changedAt: isoDate(row.changed_at)
    })),
    nextCursor: selected.length ? String(selected.at(-1).change_id) : cursor,
    hasMore
  };
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

function isoDate(value) {
  return value instanceof Date ? value.toISOString() : String(value);
}
