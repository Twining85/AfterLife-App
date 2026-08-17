ALTER TABLE dossier_sections
    ADD COLUMN deleted_at timestamptz;

CREATE TABLE sync_changes (
    change_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    dossier_id uuid NOT NULL REFERENCES dossiers(id) ON DELETE CASCADE,
    section_type text NOT NULL CHECK (section_type ~ '^[a-z][a-z0-9_-]{0,63}$'),
    schema_version integer NOT NULL CHECK (schema_version > 0),
    revision bigint NOT NULL CHECK (revision > 0),
    operation text NOT NULL CHECK (operation IN ('upsert', 'delete')),
    payload jsonb,
    changed_at timestamptz NOT NULL DEFAULT now(),
    CHECK (
        (operation = 'upsert' AND jsonb_typeof(payload) = 'object') OR
        (operation = 'delete' AND payload IS NULL)
    )
);
CREATE INDEX sync_changes_owner_cursor_idx
    ON sync_changes(owner_user_id, change_id);

INSERT INTO sync_changes
    (owner_user_id, dossier_id, section_type, schema_version, revision, operation, payload, changed_at)
SELECT owner_user_id, dossier_id, section_type, schema_version, revision,
       'upsert', payload, updated_at
  FROM dossier_sections;

CREATE TABLE sync_idempotency (
    owner_user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    idempotency_key text NOT NULL CHECK (char_length(idempotency_key) BETWEEN 1 AND 128),
    request_hash text NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$'),
    response_status integer NOT NULL CHECK (response_status BETWEEN 200 AND 499),
    response_body jsonb NOT NULL CHECK (jsonb_typeof(response_body) = 'object'),
    created_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 days'),
    PRIMARY KEY (owner_user_id, idempotency_key)
);
CREATE INDEX sync_idempotency_expiry_idx ON sync_idempotency(expires_at);

ALTER TABLE sync_changes ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_changes FORCE ROW LEVEL SECURITY;
ALTER TABLE sync_idempotency ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_idempotency FORCE ROW LEVEL SECURITY;

CREATE POLICY sync_changes_owner_policy ON sync_changes
    USING (owner_user_id = nullif(current_setting('app.user_id', true), '')::uuid)
    WITH CHECK (owner_user_id = nullif(current_setting('app.user_id', true), '')::uuid);

CREATE POLICY sync_idempotency_owner_policy ON sync_idempotency
    USING (owner_user_id = nullif(current_setting('app.user_id', true), '')::uuid)
    WITH CHECK (owner_user_id = nullif(current_setting('app.user_id', true), '')::uuid);
