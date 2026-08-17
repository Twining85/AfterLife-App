CREATE TABLE password_reset_challenges (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    token_hash text NOT NULL UNIQUE,
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    consumed_at timestamptz,
    attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0)
);

CREATE INDEX password_reset_challenges_user_idx
    ON password_reset_challenges(user_id, created_at DESC);

CREATE INDEX password_reset_challenges_active_idx
    ON password_reset_challenges(token_hash)
    WHERE consumed_at IS NULL;
