ALTER TABLE push_device_tokens
    DROP CONSTRAINT IF EXISTS push_device_tokens_device_token_check;

ALTER TABLE push_device_tokens
    ADD CONSTRAINT push_device_tokens_device_token_check
    CHECK (
        char_length(device_token) BETWEEN 64 AND 256
        AND device_token ~ '^[0-9a-f]+$'
    );
