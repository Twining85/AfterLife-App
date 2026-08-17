CREATE TABLE app_users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email text NOT NULL UNIQUE CHECK (email = lower(email)),
    password_hash text NOT NULL,
    password_salt text NOT NULL,
    email_verified_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    disabled_at timestamptz
);

CREATE TABLE user_sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    token_hash text NOT NULL UNIQUE,
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    revoked_at timestamptz
);
CREATE INDEX user_sessions_user_id_idx ON user_sessions(user_id);
CREATE INDEX user_sessions_token_hash_idx ON user_sessions(token_hash);

CREATE TABLE dossiers (
    id uuid PRIMARY KEY,
    owner_user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    created_by_user_id uuid NOT NULL REFERENCES app_users(id),
    title text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 200),
    description text CHECK (description IS NULL OR char_length(description) <= 2000),
    is_primary boolean NOT NULL DEFAULT true,
    is_active boolean NOT NULL DEFAULT true,
    is_released boolean NOT NULL DEFAULT false,
    released_at timestamptz,
    last_opened_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (owner_user_id, id)
);
CREATE UNIQUE INDEX one_primary_dossier_per_user_idx
    ON dossiers(owner_user_id) WHERE is_primary AND is_active;

CREATE TABLE dossier_sections (
    dossier_id uuid NOT NULL REFERENCES dossiers(id) ON DELETE CASCADE,
    owner_user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    section_type text NOT NULL CHECK (section_type ~ '^[a-z][a-z0-9_-]{0,63}$'),
    schema_version integer NOT NULL DEFAULT 1 CHECK (schema_version > 0),
    revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
    payload jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(payload) = 'object'),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (dossier_id, section_type),
    FOREIGN KEY (owner_user_id, dossier_id)
        REFERENCES dossiers(owner_user_id, id) ON DELETE CASCADE
);
CREATE INDEX dossier_sections_owner_idx ON dossier_sections(owner_user_id, dossier_id);

ALTER TABLE dossiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE dossiers FORCE ROW LEVEL SECURITY;
ALTER TABLE dossier_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE dossier_sections FORCE ROW LEVEL SECURITY;

CREATE POLICY dossiers_owner_policy ON dossiers
    USING (owner_user_id = nullif(current_setting('app.user_id', true), '')::uuid)
    WITH CHECK (owner_user_id = nullif(current_setting('app.user_id', true), '')::uuid);

CREATE POLICY dossier_sections_owner_policy ON dossier_sections
    USING (owner_user_id = nullif(current_setting('app.user_id', true), '')::uuid)
    WITH CHECK (owner_user_id = nullif(current_setting('app.user_id', true), '')::uuid);
