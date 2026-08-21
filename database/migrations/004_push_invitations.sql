CREATE TABLE push_device_tokens (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    device_token text NOT NULL CHECK (device_token ~ '^[0-9a-f]{64,256}$'),
    environment text NOT NULL CHECK (environment IN ('sandbox', 'production')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (device_token, environment)
);
CREATE INDEX push_device_tokens_user_idx ON push_device_tokens(user_id);

CREATE TABLE dossier_invitations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    token_hash text NOT NULL UNIQUE CHECK (token_hash ~ '^[0-9a-f]{64}$'),
    dossier_id uuid NOT NULL REFERENCES dossiers(id) ON DELETE CASCADE,
    owner_user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    invited_email text NOT NULL CHECK (invited_email = lower(invited_email)),
    requester_user_id uuid REFERENCES app_users(id) ON DELETE SET NULL,
    requester_email text,
    status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'pending', 'accepted', 'declined', 'revoked')),
    expires_at timestamptz NOT NULL,
    requested_at timestamptz,
    decided_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX dossier_invitations_owner_idx ON dossier_invitations(owner_user_id, status);
CREATE INDEX dossier_invitations_requester_idx ON dossier_invitations(requester_user_id, status);

CREATE TABLE dossier_access_grants (
    dossier_id uuid NOT NULL REFERENCES dossiers(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    invitation_id uuid NOT NULL REFERENCES dossier_invitations(id) ON DELETE CASCADE,
    granted_at timestamptz NOT NULL DEFAULT now(),
    revoked_at timestamptz,
    PRIMARY KEY (dossier_id, user_id)
);
