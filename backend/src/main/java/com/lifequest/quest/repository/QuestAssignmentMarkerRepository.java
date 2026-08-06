package com.lifequest.quest.repository;

import com.lifequest.quest.domain.QuestAssignmentMarker;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 배정 생성 마커 저장소.
 *
 * <p>조회 메서드를 두지 않는다. "이미 만들어졌는가"를 조회로 판정하면 두 요청이 모두 "없음"을 보는
 * 창이 남아, 마커를 도입한 이유가 사라진다. 판정은 저장 시점의 유니크 제약 위반으로만 한다 —
 * 저장이 성공하면 이 요청이 생성 담당이고, 실패하면 다른 요청이 이미 만든 것이다.
 *
 * <p>따라서 호출부는 {@code saveAndFlush}로 저장해야 한다. {@code save}만 하면 INSERT가 트랜잭션
 * 커밋 시점까지 미뤄져 제약 위반을 그 자리에서 잡을 수 없다.
 */
public interface QuestAssignmentMarkerRepository extends JpaRepository<QuestAssignmentMarker, Long> {
}
