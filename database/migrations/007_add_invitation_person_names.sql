ALTER TABLE dossier_invitations
    ADD COLUMN owner_name text,
    ADD COLUMN requester_name text;

UPDATE dossier_invitations
   SET owner_name = 'Vorsorgende Person'
 WHERE owner_name IS NULL;

ALTER TABLE dossier_invitations
    ALTER COLUMN owner_name SET NOT NULL,
    ADD CONSTRAINT dossier_invitations_owner_name_check
        CHECK (char_length(owner_name) BETWEEN 1 AND 120),
    ADD CONSTRAINT dossier_invitations_requester_name_check
        CHECK (requester_name IS NULL OR char_length(requester_name) BETWEEN 1 AND 120);
