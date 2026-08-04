package com.lifequest.quest;

import static org.assertj.core.api.Assertions.assertThat;

import com.lifequest.quest.domain.QuestFeature;
import com.lifequest.quest.service.QuestUnlockPolicy;
import com.lifequest.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

class QuestUnlockPolicyTests {

    private final QuestUnlockPolicy policy = new QuestUnlockPolicy(Mockito.mock(UserRepository.class));

    @Test
    void unlocksFeaturesAtConfiguredLevels() {
        assertThat(policy.isUnlocked(1, QuestFeature.DAILY)).isTrue();
        assertThat(policy.isUnlocked(1, QuestFeature.WEEKLY)).isFalse();
        assertThat(policy.isUnlocked(2, QuestFeature.WEEKLY)).isFalse();
        assertThat(policy.isUnlocked(3, QuestFeature.WEEKLY)).isTrue();
        assertThat(policy.isUnlocked(4, QuestFeature.COOP)).isFalse();
        assertThat(policy.isUnlocked(5, QuestFeature.COOP)).isTrue();
    }
}
