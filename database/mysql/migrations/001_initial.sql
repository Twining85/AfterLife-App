CREATE TABLE IF NOT EXISTS app_users (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    email VARCHAR(254) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    password_salt VARCHAR(255) NOT NULL,
    email_verified_at DATETIME(6) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    disabled_at DATETIME(6),
    UNIQUE KEY app_users_email_uq (email),
    CONSTRAINT app_users_email_lowercase_ck CHECK (email = LOWER(email))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS user_sessions (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    refresh_token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin,
    expires_at DATETIME(6) NOT NULL,
    refresh_expires_at DATETIME(6),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    revoked_at DATETIME(6),
    UNIQUE KEY user_sessions_token_uq (token_hash),
    UNIQUE KEY user_sessions_refresh_token_uq (refresh_token_hash),
    KEY user_sessions_user_idx (user_id),
    CONSTRAINT user_sessions_user_fk FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE,
    CONSTRAINT user_sessions_refresh_pair_ck CHECK (
        (refresh_token_hash IS NULL AND refresh_expires_at IS NULL)
        OR (refresh_token_hash IS NOT NULL AND refresh_expires_at IS NOT NULL)
    )
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS password_reset_challenges (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    expires_at DATETIME(6) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    consumed_at DATETIME(6),
    attempts INT UNSIGNED NOT NULL DEFAULT 0,
    UNIQUE KEY password_reset_token_uq (token_hash),
    KEY password_reset_user_idx (user_id, created_at),
    CONSTRAINT password_reset_user_fk FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dossiers (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    owner_user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    created_by_user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    title VARCHAR(200) NOT NULL,
    description VARCHAR(2000),
    is_primary BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_released BOOLEAN NOT NULL DEFAULT FALSE,
    released_at DATETIME(6),
    last_opened_at DATETIME(6),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    active_primary_owner CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
        GENERATED ALWAYS AS (CASE WHEN is_primary = TRUE AND is_active = TRUE THEN owner_user_id ELSE NULL END) VIRTUAL,
    UNIQUE KEY dossiers_one_active_primary_uq (active_primary_owner),
    KEY dossiers_owner_idx (owner_user_id, is_active, is_primary),
    CONSTRAINT dossiers_owner_fk FOREIGN KEY (owner_user_id) REFERENCES app_users(id) ON DELETE CASCADE,
    CONSTRAINT dossiers_creator_fk FOREIGN KEY (created_by_user_id) REFERENCES app_users(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dossier_sections (
    dossier_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    owner_user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    section_type VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    schema_version INT UNSIGNED NOT NULL DEFAULT 1,
    revision BIGINT UNSIGNED NOT NULL DEFAULT 1,
    payload JSON,
    deleted_at DATETIME(6),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (dossier_id, section_type),
    KEY dossier_sections_owner_idx (owner_user_id, dossier_id),
    CONSTRAINT dossier_sections_dossier_fk FOREIGN KEY (dossier_id) REFERENCES dossiers(id) ON DELETE CASCADE,
    CONSTRAINT dossier_sections_owner_fk FOREIGN KEY (owner_user_id) REFERENCES app_users(id) ON DELETE CASCADE,
    CONSTRAINT dossier_sections_payload_ck CHECK (
        (deleted_at IS NULL AND payload IS NOT NULL) OR
        (deleted_at IS NOT NULL AND payload IS NULL)
    )
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sync_changes (
    change_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    owner_user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    dossier_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    section_type VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    schema_version INT UNSIGNED NOT NULL,
    revision BIGINT UNSIGNED NOT NULL,
    operation ENUM('upsert', 'delete') NOT NULL,
    payload JSON,
    changed_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    KEY sync_changes_owner_cursor_idx (owner_user_id, change_id),
    CONSTRAINT sync_changes_owner_fk FOREIGN KEY (owner_user_id) REFERENCES app_users(id) ON DELETE CASCADE,
    CONSTRAINT sync_changes_dossier_fk FOREIGN KEY (dossier_id) REFERENCES dossiers(id) ON DELETE CASCADE,
    CONSTRAINT sync_changes_payload_ck CHECK (
        (operation = 'upsert' AND payload IS NOT NULL) OR
        (operation = 'delete' AND payload IS NULL)
    )
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sync_idempotency (
    owner_user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    idempotency_key VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    request_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    response_status SMALLINT UNSIGNED NOT NULL,
    response_body JSON NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    expires_at DATETIME(6) NOT NULL,
    PRIMARY KEY (owner_user_id, idempotency_key),
    KEY sync_idempotency_expiry_idx (expires_at),
    CONSTRAINT sync_idempotency_owner_fk FOREIGN KEY (owner_user_id) REFERENCES app_users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS push_device_tokens (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    device_token VARCHAR(256) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    environment ENUM('sandbox', 'production') NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    UNIQUE KEY push_device_token_uq (device_token, environment),
    KEY push_device_user_idx (user_id),
    CONSTRAINT push_device_user_fk FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dossier_invitations (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    dossier_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    owner_user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    invited_email VARCHAR(254) NOT NULL,
    owner_name VARCHAR(120) NOT NULL,
    requester_user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin,
    requester_email VARCHAR(254),
    requester_name VARCHAR(120),
    status ENUM('open', 'pending', 'accepted', 'declined', 'revoked') NOT NULL DEFAULT 'open',
    expires_at DATETIME(6) NOT NULL,
    requested_at DATETIME(6),
    decided_at DATETIME(6),
    access_release_at DATETIME(6),
    auto_released_at DATETIME(6),
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    UNIQUE KEY dossier_invitations_token_uq (token_hash),
    KEY dossier_invitations_owner_idx (owner_user_id, status),
    KEY dossier_invitations_requester_idx (requester_user_id, status),
    KEY dossier_invitations_release_idx (status, access_release_at),
    CONSTRAINT dossier_invitations_dossier_fk FOREIGN KEY (dossier_id) REFERENCES dossiers(id) ON DELETE CASCADE,
    CONSTRAINT dossier_invitations_owner_fk FOREIGN KEY (owner_user_id) REFERENCES app_users(id) ON DELETE CASCADE,
    CONSTRAINT dossier_invitations_requester_fk FOREIGN KEY (requester_user_id) REFERENCES app_users(id) ON DELETE SET NULL,
    CONSTRAINT dossier_invitations_email_lowercase_ck CHECK (invited_email = LOWER(invited_email)),
    CONSTRAINT dossier_invitations_requester_email_lowercase_ck CHECK (requester_email IS NULL OR requester_email = LOWER(requester_email))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dossier_access_grants (
    dossier_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    invitation_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    role ENUM('trusted_person', 'read_only') NOT NULL DEFAULT 'trusted_person',
    granted_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    revoked_at DATETIME(6),
    PRIMARY KEY (dossier_id, user_id),
    CONSTRAINT dossier_access_dossier_fk FOREIGN KEY (dossier_id) REFERENCES dossiers(id) ON DELETE CASCADE,
    CONSTRAINT dossier_access_user_fk FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE,
    CONSTRAINT dossier_access_invitation_fk FOREIGN KEY (invitation_id) REFERENCES dossier_invitations(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dossier_key_envelopes (
    dossier_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    recipient_user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    key_version INT UNSIGNED NOT NULL,
    algorithm VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    encrypted_key MEDIUMBLOB NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    revoked_at DATETIME(6),
    PRIMARY KEY (dossier_id, recipient_user_id, key_version),
    CONSTRAINT dossier_keys_dossier_fk FOREIGN KEY (dossier_id) REFERENCES dossiers(id) ON DELETE CASCADE,
    CONSTRAINT dossier_keys_recipient_fk FOREIGN KEY (recipient_user_id) REFERENCES app_users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS stored_files (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    dossier_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    owner_user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    object_key VARCHAR(768) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    original_filename VARCHAR(255) NOT NULL,
    media_type VARCHAR(127) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    byte_size BIGINT UNSIGNED NOT NULL,
    sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    category VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    related_entity_type VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin,
    related_entity_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin,
    encryption_algorithm VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin,
    encryption_key_version INT UNSIGNED,
    status ENUM('pending', 'available', 'deleting', 'deleted', 'failed') NOT NULL DEFAULT 'pending',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    deleted_at DATETIME(6),
    UNIQUE KEY stored_files_object_key_uq (object_key),
    KEY stored_files_dossier_idx (dossier_id, status),
    CONSTRAINT stored_files_dossier_fk FOREIGN KEY (dossier_id) REFERENCES dossiers(id) ON DELETE CASCADE,
    CONSTRAINT stored_files_owner_fk FOREIGN KEY (owner_user_id) REFERENCES app_users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS admin_users (
    user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT admin_users_user_fk FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS audit_log (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    actor_user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin,
    action VARCHAR(100) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    target_user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin,
    target_dossier_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin,
    request_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin,
    metadata JSON,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    KEY audit_log_created_idx (created_at),
    KEY audit_log_target_user_idx (target_user_id, created_at),
    CONSTRAINT audit_log_actor_fk FOREIGN KEY (actor_user_id) REFERENCES app_users(id) ON DELETE SET NULL
) ENGINE=InnoDB;
