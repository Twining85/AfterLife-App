-- V2 remains disabled until the client invitation/migration flow is ready.
ALTER TABLE dossier_sections ADD COLUMN encryption_version TINYINT UNSIGNED NOT NULL DEFAULT 1,
    ADD CONSTRAINT dossier_sections_encryption_version CHECK (encryption_version IN (1, 2));
ALTER TABLE dossiers ADD UNIQUE KEY dossiers_owner_id_uq (owner_user_id, id);
CREATE TABLE IF NOT EXISTS dossier_access_metadata (
    dossier_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    owner_user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    section_type VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    revision BIGINT UNSIGNED NOT NULL,
    metadata JSON NOT NULL,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (dossier_id, section_type),
    CONSTRAINT access_metadata_section_type CHECK (section_type IN ('kontakte', 'dossier_einstellungen')),
    CONSTRAINT access_metadata_positive_revision CHECK (revision > 0),
    CONSTRAINT access_metadata_section FOREIGN KEY (dossier_id, section_type)
        REFERENCES dossier_sections(dossier_id, section_type) ON DELETE CASCADE,
    CONSTRAINT access_metadata_owner FOREIGN KEY (owner_user_id, dossier_id)
        REFERENCES dossiers(owner_user_id, id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Enforce the floor even if an old backend image is accidentally started.
ALTER TABLE dossier_sections ADD CONSTRAINT dossier_sections_v2_ciphertext CHECK (
    encryption_version = 1 OR deleted_at IS NOT NULL OR
    COALESCE(JSON_EXTRACT(payload, '$.formatVersion') = 2, FALSE) OR
    COALESCE(JSON_EXTRACT(payload, '$._tschluessliStorage.encryptionVersion') = 2, FALSE)
);
-- Managed MySQL does not permit triggers with binary logging and no SUPER
-- privilege. Legacy backends never update encryption_version, so this CHECK
-- still rejects their plaintext writes. The current backend retains the floor
-- in both its locked application check and its SQL upsert.
ALTER TABLE sync_changes ADD COLUMN access_metadata JSON;
