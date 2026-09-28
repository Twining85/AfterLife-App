ALTER TABLE dossier_invitations
    ADD COLUMN access_reminder_last_sent_at timestamptz;

CREATE INDEX dossier_invitations_access_reminder_idx
    ON dossier_invitations(requested_at, access_reminder_last_sent_at)
    WHERE status = 'pending';
