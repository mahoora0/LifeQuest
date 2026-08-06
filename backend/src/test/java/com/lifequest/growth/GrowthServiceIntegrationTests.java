package com.lifequest.growth;

import static org.assertj.core.api.Assertions.assertThat;

import com.lifequest.auth.AuthService;
import com.lifequest.auth.dto.SignupRequest;
import com.lifequest.user.User;
import com.lifequest.user.UserRepository;
import com.lifequest.user.UserService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class GrowthServiceIntegrationTests {

    @Autowired
    private AuthService authService;

    @Autowired
    private GrowthService growthService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private UserService userService;

    @Test
    void expLevelRewardsAndDuplicateProtectionWorkTogether() {
        authService.signup(new SignupRequest(
                "growth@lifequest.test", "password123", "성장테스터"));
        User user = userRepository.findByEmailIgnoreCase("growth@lifequest.test")
                .orElseThrow();

        GrowthResult first =
                growthService.grantExp(user.getId(), "QUEST_COMPLETION", 9001L, 350);
        assertThat(first.previousLevel()).isEqualTo(1);
        assertThat(first.currentLevel()).isEqualTo(3);
        assertThat(first.levelUp()).isTrue();
        // 이름만 보면 칭호와 프로필 아이템을 구분하지 못한다. 완료 응답 계약이
        // 요구하는 세 필드를 모두 고정한다(docs/04-api-spec.md §4).
        assertThat(first.rewards()).containsExactly(
                new RewardGrant("TITLE", "NEIGHBORHOOD_EXPLORER", "동네 탐험가"),
                new RewardGrant("PROFILE_ITEM", "COMPASS_BADGE", "나침반 배지"));

        GrowthResult duplicated =
                growthService.grantExp(user.getId(), "QUEST_COMPLETION", 9001L, 350);
        assertThat(duplicated.duplicated()).isTrue();
        assertThat(duplicated.expGained()).isZero();

        assertThat(userService.getLevel(user.getId()))
                .containsEntry("level", 3)
                .containsEntry("totalExp", 350)
                .containsEntry("currentLevelExp", 50)
                .containsEntry("nextLevelRequiredExp", 300);
        assertThat(userService.getTitles(user.getId()).titles())
                .extracting("name")
                .containsExactly("동네 탐험가", "새내기 모험가");
        assertThat(userService.getBadges(user.getId()).badges())
                .extracting("name")
                .containsExactly("나침반 배지", "새싹 배지");
        assertThat(userService.getAccessories(user.getId()).accessories())
                .filteredOn("unlocked", true)
                .isEmpty();
    }
}
