-- V2 remains disabled until the client invitation/migration flow is ready.
ALTER TABLE dossier_sections ADD COLUMN encryption_version integer NOT NULL DEFAULT 1
    CHECK (encryption_version IN (1, 2));
CREATE TABLE dossier_access_metadata (
    dossier_id uuid NOT NULL,
    owner_user_id uuid NOT NULL,
    section_type text NOT NULL CHECK (section_type IN ('kontakte', 'dossier_einstellungen')),
    revision bigint NOT NULL CHECK (revision > 0),
    metadata jsonb NOT NULL CHECK (jsonb_typeof(metadata) = 'object'),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (dossier_id, section_type),
    FOREIGN KEY (dossier_id, section_type) REFERENCES dossier_sections(dossier_id, section_type) ON DELETE CASCADE,
    FOREIGN KEY (owner_user_id, dossier_id) REFERENCES dossiers(owner_user_id, id) ON DELETE CASCADE
);
ALTER TABLE dossier_access_metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE dossier_access_metadata FORCE ROW LEVEL SECURITY;
CREATE POLICY dossier_access_metadata_owner_policy ON dossier_access_metadata
    USING (owner_user_id = nullif(current_setting('app.user_id', true), '')::uuid)
    WITH CHECK (owner_user_id = nullif(current_setting('app.user_id', true), '')::uuid);

-- Enforce the floor even if an old backend image is accidentally started.
ALTER TABLE dossier_sections ADD CONSTRAINT dossier_sections_v2_ciphertext CHECK (
    encryption_version = 1 OR deleted_at IS NOT NULL OR
    COALESCE(payload->>'formatVersion' = '2', false) OR
    COALESCE(payload->'_tschluessliStorage'->>'encryptionVersion' = '2', false)
);
CREATE FUNCTION enforce_section_encryption_floor() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.encryption_version = 2 AND NEW.encryption_version <> 2 THEN
        RAISE EXCEPTION 'E2E encryption downgrade is forbidden';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER dossier_sections_encryption_floor BEFORE UPDATE ON dossier_sections
    FOR EACH ROW EXECUTE FUNCTION enforce_section_encryption_floor();
ALTER TABLE sync_changes ADD COLUMN access_metadata jsonb;
