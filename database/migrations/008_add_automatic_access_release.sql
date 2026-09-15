ALTER TABLE dossier_invitations
    ADD COLUMN access_release_at timestamptz,
    ADD COLUMN auto_released_at timestamptz;

CREATE INDEX dossier_invitations_auto_release_idx
    ON dossier_invitations(access_release_at)
    WHERE status = 'pending' AND access_release_at IS NOT NULL;
