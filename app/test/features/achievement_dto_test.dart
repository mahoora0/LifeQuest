import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/achievement/data/achievement_dto.dart';

void main() {
  group('Achievement.mergeWith', () {
    test('달성한 비밀 업적은 내 현황의 실제 이름·조건을 쓴다', () {
      // 카탈로그(/achievements)는 비밀 업적을 마스킹해서 내려주지만,
      // 달성했다면 내 현황(/users/me/achievements)에 실제 값이 있다.
      // 카탈로그를 우선하면 "완료" 도장 옆에 마스킹된 이름이 남는다.
      const catalog = Achievement(
        id: 7,
        name: '비밀 업적',
        achieved: false,
        secret: true,
        condition: '조건을 달성하면 공개돼요',
      );
      const mine = Achievement(
        id: 7,
        name: '한밤의 산책자',
        achieved: true,
        secret: true,
        condition: '자정 이후 퀘스트 3회 완료',
      );

      final merged = catalog.mergeWith(mine);

      expect(merged.achieved, isTrue);
      expect(merged.name, '한밤의 산책자');
      expect(merged.condition, '자정 이후 퀘스트 3회 완료');
      expect(merged.isHiddenSecret, isFalse);
    });

    test('미달성 비밀 업적은 마스킹된 값을 그대로 유지한다', () {
      const catalog = Achievement(
        id: 7,
        name: '비밀 업적',
        achieved: false,
        secret: true,
        condition: '조건을 달성하면 공개돼요',
      );
      const mine = Achievement(
        id: 7,
        name: '',
        achieved: false,
        secret: true,
        currentValue: 1,
        requiredValue: 3,
      );

      final merged = catalog.mergeWith(mine);

      expect(merged.name, '비밀 업적');
      expect(merged.condition, '조건을 달성하면 공개돼요');
      expect(merged.isHiddenSecret, isTrue);
    });

    test('일반 업적은 카탈로그 이름을 유지하고 진행도만 덮어쓴다', () {
      const catalog = Achievement(
        id: 3,
        name: '카페 탐험가 I',
        achieved: false,
        secret: false,
        condition: '카페 5곳 방문',
        expReward: 50,
      );
      const mine = Achievement(
        id: 3,
        name: '',
        achieved: false,
        secret: false,
        currentValue: 2,
        requiredValue: 5,
        currentStep: 1,
      );

      final merged = catalog.mergeWith(mine);

      expect(merged.name, '카페 탐험가 I');
      expect(merged.currentValue, 2);
      expect(merged.requiredValue, 5);
      expect(merged.currentStep, 1);
      expect(merged.expReward, 50);
      expect(merged.hasProgress, isTrue);
      expect(merged.progressRatio, closeTo(0.4, 0.001));
    });
  });

  group('AchievementFilter', () {
    const achieved = Achievement(
      id: 1,
      name: 'A',
      achieved: true,
      secret: false,
    );
    const inProgress = Achievement(
      id: 2,
      name: 'B',
      achieved: false,
      secret: false,
    );
    const secret = Achievement(id: 3, name: 'C', achieved: false, secret: true);

    test('전체는 모두 통과', () {
      for (final item in [achieved, inProgress, secret]) {
        expect(AchievementFilter.all.matches(item), isTrue);
      }
    });

    test('달성/진행 중/비밀 필터', () {
      expect(AchievementFilter.achieved.matches(achieved), isTrue);
      expect(AchievementFilter.achieved.matches(inProgress), isFalse);
      expect(AchievementFilter.inProgress.matches(inProgress), isTrue);
      expect(AchievementFilter.inProgress.matches(achieved), isFalse);
      expect(AchievementFilter.secret.matches(secret), isTrue);
      expect(AchievementFilter.secret.matches(achieved), isFalse);
    });
  });
}
