-- 그룹 퀘스트 정원.
--
-- NULL은 "정원 없음"이다. 이 컬럼이 생기기 전에 만들어진 퀘스트는 인원 제한 없이
-- 신청을 받아 왔으므로, 기본값을 넣어 소급 적용하면 이미 정원을 넘긴 퀘스트가 생긴다.
-- 하한 2는 그룹 정원과 같은 기준이다 — 혼자 하는 퀘스트는 그룹 퀘스트가 아니다.
ALTER TABLE group_quests
    ADD COLUMN max_participants INT NULL;

ALTER TABLE group_quests
    ADD CONSTRAINT ck_group_quests_max_participants
        CHECK (max_participants IS NULL OR (max_participants >= 2 AND max_participants <= 100));
