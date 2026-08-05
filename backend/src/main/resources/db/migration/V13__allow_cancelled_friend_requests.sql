ALTER TABLE friend_requests
    DROP CONSTRAINT ck_friend_requests_status;

ALTER TABLE friend_requests
    ADD CONSTRAINT ck_friend_requests_status CHECK (
        status IN ('PENDING', 'ACCEPTED', 'REJECTED', 'CANCELLED')
    );
