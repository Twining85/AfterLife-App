ALTER TABLE dossier_invitations
    ADD COLUMN shared_key_package VARBINARY(512) NULL AFTER requester_name;
