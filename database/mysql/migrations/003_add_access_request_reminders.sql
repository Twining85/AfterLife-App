ALTER TABLE dossier_invitations
    ADD COLUMN access_reminder_last_sent_at DATETIME(6) NULL AFTER requested_at,
    ADD KEY dossier_invitations_access_reminder_idx
        (status, requested_at, access_reminder_last_sent_at);
