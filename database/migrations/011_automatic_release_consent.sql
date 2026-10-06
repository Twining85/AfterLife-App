-- Existing invitations have no explicit consent. Preserve status and grants.
ALTER TABLE dossier_invitations
    ADD COLUMN automatic_release_allowed boolean NOT NULL DEFAULT false;
UPDATE dossier_invitations SET access_release_at = NULL
 WHERE status IN ('open', 'pending');
