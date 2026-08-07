package com.lifequest.quest.domain;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * 개인 AI 퀘스트의 불변식.
 *
 * <p>등급·EXP·완료 방식·주기를 <b>서버가 고정</b>한다는 것이 핵심이다. LLM 응답이나 앱 요청에서
 * 받으면 보상을 부풀리는 경로가 열리고, 그 결함은 예외 없이 조용히 EXP만 더 준다.
 */
class PrivateAiQuestInvariantTests {

    @Test
    void AI_주간_퀘스트는_등급과_보상과_완료방식이_고정된다() {
        Quest quest = Quest.createPrivateAiWeekly(
            7L, "성수동 전시 관람", "가까운 전시를 하나 골라 다녀오세요", "성수동 전시 공간",
            "관람을 마친 뒤 완료를 눌러 주세요");

        assertThat(quest.getGrade()).isEqualTo(QuestGrade.RARE);
        assertThat(quest.getExpReward()).isEqualTo(40);
        assertThat(quest.getCadence()).isEqualTo(QuestCadence.WEEKLY);
        assertThat(quest.getCompletionType()).isEqualTo(CompletionType.SELF_REPORT);
        assertThat(quest.getCreatedBy()).isEqualTo(QuestCreator.AI);
        assertThat(quest.getOwnerUserId()).isEqualTo(7L);
        assertThat(quest.isPrivate()).isTrue();
        assertThat(quest.getCompletionGuide()).isEqualTo("관람을 마친 뒤 완료를 눌러 주세요");
    }

    /**
     * 좌표를 만들지 않는다. 추천 시스템 지시가 좌표·인증 반경 생성을 막고 있고, 좌표 없는
     * LOCATION은 생성자와 {@code ck_quests_location_verifiable}이 거부한다.
     * {@code suggestedPlaceName}은 표시용 이름일 뿐이라 placeName에만 들어간다.
     */
    @Test
    void AI_주간_퀘스트는_좌표를_만들지_않는다() {
        Quest quest = Quest.createPrivateAiWeekly(1L, "제목", "설명", "장소 이름", "완료 기준");

        assertThat(quest.getPlaceName()).isEqualTo("장소 이름");
        assertThat(quest.getLatitude()).isNull();
        assertThat(quest.getLongitude()).isNull();
        assertThat(quest.getRadiusM()).isNull();
        assertThat(quest.isLocationBased()).isFalse();
    }

    /** 주인만 볼 수 있다. 상세 조회 권한이 이 판정에 기댄다. */
    @Test
    void 개인_퀘스트는_주인에게만_보인다() {
        Quest quest = Quest.createPrivateAiWeekly(7L, "제목", "설명", "장소", "완료 기준");

        assertThat(quest.isVisibleTo(7L)).isTrue();
        assertThat(quest.isVisibleTo(8L)).isFalse();
    }

    /** 공용 퀘스트는 누구나 볼 수 있다 — 소유자 검사가 시드 카탈로그를 막으면 안 된다. */
    @Test
    void 공용_퀘스트는_누구에게나_보인다() {
        Quest quest = publicQuest(QuestCreator.SYSTEM);

        assertThat(quest.isPrivate()).isFalse();
        assertThat(quest.isVisibleTo(1L)).isTrue();
        assertThat(quest.isVisibleTo(2L)).isTrue();
    }

    /**
     * 공용 생성자로는 AI 퀘스트를 만들 수 없다. 만들 수 있으면 주인 없는 AI 퀘스트가 생기고,
     * 그 행은 배정 풀에서도 빠지고 아무에게도 배정되지 않는 고아가 된다
     * ({@code ck_quests_ai_owner}가 DB에서 같은 것을 막는다).
     */
    @Test
    void 공용_생성자로는_AI_퀘스트를_만들_수_없다() {
        assertThatThrownBy(() -> publicQuest(QuestCreator.AI))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessageContaining("owner_user_id");
    }

    private Quest publicQuest(QuestCreator createdBy) {
        return new Quest(
            "공용 퀘스트", "설명", QuestGrade.NORMAL, QuestCadence.DAILY,
            CompletionType.SELF_REPORT, 10, null, null, null, null, null,
            createdBy, true);
    }
}
