ALTER TABLE user_sessions
    ADD COLUMN refresh_token_hash text,
    ADD COLUMN refresh_expires_at timestamptz;

ALTER TABLE user_sessions
    ADD CONSTRAINT user_sessions_refresh_pair_check CHECK (
        (refresh_token_hash IS NULL AND refresh_expires_at IS NULL)
        OR
        (
            refresh_token_hash ~ '^[0-9a-f]{64}$'
            AND refresh_expires_at IS NOT NULL
        )
    );

CREATE UNIQUE INDEX user_sessions_refresh_token_hash_idx
    ON user_sessions(refresh_token_hash)
    WHERE refresh_token_hash IS NOT NULL;
