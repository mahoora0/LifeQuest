import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';

void main() {
  group('DailyQuest.fromJson', () {
    test('퀘스트 요약이 중첩으로 오는 형태를 읽는다', () {
      final quest = DailyQuest.fromJson({
        'dailyQuestId': 901,
        'questId': 12,
        'status': 'ASSIGNED',
        'quest': {
          'id': 12,
          'title': '새로운 카페 방문하기',
          'completionType': 'LOCATION',
          'expReward': 50,
          'placeName': '연남동 카페',
          'latitude': 37.5665,
          'longitude': 126.9780,
          'radiusM': 30,
        },
      });

      expect(quest.dailyQuestId, 901);
      expect(quest.questId, 12);
      expect(quest.status, DailyQuestStatus.assigned);
      expect(quest.quest.title, '새로운 카페 방문하기');
      expect(quest.quest.completionType.isLocation, isTrue);
      expect(quest.quest.radiusM, 30);
      expect(quest.quest.hasRadius, isTrue);
      expect(quest.quest.hasCoordinates, isTrue);
    });

    test('중첩 객체가 questId 키를 쓰면 그 값을 퀘스트 id로 삼는다', () {
      // 최상위 questId가 없을 때 0으로 덮이면 /quests/0으로 이동해 버린다.
      final quest = DailyQuest.fromJson({
        'id': 901,
        'status': 'ASSIGNED',
        'quest': {'questId': 12, 'title': '새로운 카페 방문하기'},
      });

      expect(quest.dailyQuestId, 901);
      expect(quest.questId, 12);
    });

    test('반경을 모르면 hasRadius가 false다 (기본값을 추측하지 않는다)', () {
      final quest = DailyQuest.fromJson({
        'dailyQuestId': 1,
        'questId': 2,
        'title': '어딘가 가기',
        'completionType': 'LOCATION',
        'latitude': 37.5,
        'longitude': 127.0,
      });

      expect(quest.quest.hasRadius, isFalse);
      expect(quest.quest.radiusM, isNull);
    });

    test('퀘스트 요약이 평탄화되어 오는 형태도 읽는다', () {
      final quest = DailyQuest.fromJson({
        'dailyQuestId': 902,
        'questId': 13,
        'status': 'COMPLETED',
        'title': '아침 7시 전에 일어나기',
        'completionType': 'SELF_REPORT',
        'expReward': 40,
      });

      expect(quest.questId, 13);
      expect(quest.status.isCompleted, isTrue);
      expect(quest.quest.title, '아침 7시 전에 일어나기');
      expect(quest.quest.completionType, QuestCompletionType.selfReport);
      expect(quest.quest.expReward, 40);
    });

    test('알 수 없는 completionType은 SELF_REPORT로 다룬다', () {
      final quest = DailyQuest.fromJson({
        'dailyQuestId': 903,
        'questId': 14,
        'title': '무언가',
      });

      expect(quest.quest.completionType, QuestCompletionType.selfReport);
      expect(quest.quest.hasCoordinates, isFalse);
    });
  });

  group('DailyQuestStatus.isActionable', () {
    test('배정 상태만 완료 요청을 보낼 수 있다', () {
      expect(DailyQuestStatus.assigned.isActionable, isTrue);
      // 만료·완료 건은 서버가 거절하므로 UI에서도 막아야 한다.
      expect(DailyQuestStatus.expired.isActionable, isFalse);
      expect(DailyQuestStatus.completed.isActionable, isFalse);
    });
  });

  group('CompletionCoordinates', () {
    test('세 값을 항상 함께 직렬화한다', () {
      const coordinates = CompletionCoordinates(
        latitude: 37.5665,
        longitude: 126.9780,
        accuracy: 12.5,
      );

      expect(coordinates.toJson(), {
        'latitude': 37.5665,
        'longitude': 126.9780,
        'accuracy': 12.5,
      });
    });
  });

  group('TodayQuests', () {
    final today = TodayQuests.fromJson({
      'assignedDate': '2026-07-24',
      'quests': [
        {'dailyQuestId': 1, 'questId': 11, 'status': 'COMPLETED', 'title': 'A'},
        {'dailyQuestId': 2, 'questId': 22, 'status': 'ASSIGNED', 'title': 'B'},
        {'dailyQuestId': 3, 'questId': 33, 'status': 'EXPIRED', 'title': 'C'},
      ],
    });

    test('완료 수를 센다', () {
      expect(today.total, 3);
      expect(today.completedCount, 1);
      expect(today.isEmpty, isFalse);
    });

    test('배정 id로 현재 배정 상태를 찾는다', () {
      final found = today.findAssignment(dailyQuestId: 1);
      expect(found?.status, DailyQuestStatus.completed);
    });

    test('배정 id가 없으면 퀘스트 id로 찾는다', () {
      final found = today.findAssignment(questId: 33);
      expect(found?.dailyQuestId, 3);
      expect(found?.status.isExpired, isTrue);
    });

    test('없는 항목은 null', () {
      expect(today.findAssignment(dailyQuestId: 999), isNull);
      expect(today.findAssignment(questId: 999), isNull);
    });
  });

  group('QuestCompletionResult.fromJson', () {
    test('통합 완료 응답을 읽는다', () {
      final result = QuestCompletionResult.fromJson({
        'completionId': 4821,
        'dailyQuestId': 901,
        'questId': 12,
        'grade': 'RARE',
        'completedAt': '2026-08-03T14:20:00',
        'duplicated': false,
        'location': {'distanceM': 23.4, 'accuracyM': 12.5},
        'growth': {
          'expGained': 30,
          'totalExp': 350,
          'previousLevel': 4,
          'currentLevel': 5,
          'levelUp': true,
          'rewards': [
            {'type': 'TITLE', 'code': 'novice_explorer', 'name': '초보 탐험가'},
          ],
        },
        'collection': {
          'newLifedexItems': [
            {'id': 12, 'name': '첫 카페 탐험'},
          ],
          'newAchievements': [
            {'id': 3, 'name': '카페 탐험가 I'},
          ],
        },
      });

      expect(result.completionId, 4821);
      expect(result.duplicated, isFalse);
      expect(result.location?.distanceM, 23.4);
      expect(result.growth.levelUp, isTrue);
      expect(result.growth.rewards.single.isTitle, isTrue);
      expect(result.collection.newLifedexItems.single.name, '첫 카페 탐험');
      expect(result.collection.isEmpty, isFalse);
    });

    test('중복 완료 응답은 보상이 비어 있고 레벨이 그대로다', () {
      final result = QuestCompletionResult.fromJson({
        'completionId': 4821,
        'dailyQuestId': 901,
        'questId': 12,
        'duplicated': true,
        'growth': {
          'expGained': 0,
          'totalExp': 350,
          'previousLevel': 5,
          'currentLevel': 5,
          'levelUp': false,
          'rewards': <Object>[],
        },
        'collection': {
          'newLifedexItems': <Object>[],
          'newAchievements': <Object>[],
        },
      });

      expect(result.duplicated, isTrue);
      expect(result.growth.expGained, 0);
      expect(result.growth.levelUp, isFalse);
      expect(result.collection.isEmpty, isTrue);
    });

    test('growth·collection이 없어도 기본값으로 견딘다', () {
      final result = QuestCompletionResult.fromJson({
        'completionId': 1,
        'dailyQuestId': 2,
        'questId': 3,
      });

      expect(result.duplicated, isFalse);
      expect(result.growth.expGained, 0);
      expect(result.collection.isEmpty, isTrue);
      expect(result.location, isNull);
    });

    test('withQuestTitle은 나머지 필드를 보존한다', () {
      final result = QuestCompletionResult.fromJson({
        'completionId': 7,
        'dailyQuestId': 8,
        'questId': 9,
        'duplicated': true,
      }).withQuestTitle('물 2L 마시기');

      expect(result.questTitle, '물 2L 마시기');
      expect(result.completionId, 7);
      expect(result.duplicated, isTrue);
    });
  });
}
