-- 인증 게시물을 지울 때 행을 남긴다.
--
-- V13의 UNIQUE(quest_completion_id)는 "완료 1건당 게시물 1개"라는 부정 방지 규칙을 담고
-- 있는데, 행을 실제로 지우면 그 제약이 함께 사라진다. 그러면 다음이 성립한다 —
-- 게시물 등록 → 지인들이 투표해 EXP 획득 → 삭제 → 같은 완료 기록으로 재등록 →
-- 같은 지인들이 다시 투표해 또 EXP 획득. 투표 EXP의 멱등성 키가 게시물 ID라서
-- 새 게시물이 되면 지급 이력도 새로 열린다.
--
-- 행을 남기면 제약이 계속 유효해 재등록 자체가 막힌다. 사진 파일과 사진 행은 실제로
-- 지우므로 "삭제했는데 사진이 남는" 문제는 생기지 않는다. 남는 것은 완료 기록을
-- 이미 썼다는 사실뿐이다.
ALTER TABLE quest_proof_posts ADD COLUMN deleted_at DATETIME(6) NULL;

-- 피드 질의는 전부 삭제되지 않은 것만 본다. 기존 (status, id) 인덱스 앞에 deleted_at을
-- 두지 않는 이유는 선택도가 낮아서다 — 삭제된 게시물은 소수이므로 뒤에 붙인다.
CREATE INDEX idx_quest_proof_posts_live ON quest_proof_posts (deleted_at, id);
