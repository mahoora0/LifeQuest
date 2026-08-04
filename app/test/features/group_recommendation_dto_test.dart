import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/group/data/group_dto.dart';
import 'package:life_quest/features/recommendation/data/quest_recommendation_dto.dart';
import 'package:life_quest/features/user/data/user_dto.dart';

void main() {
  test('그룹 상세 응답에서 권한·상태·멤버를 해석한다', () {
    final group = GroupDetail.fromJson({
      'id': 7,
      'name': '주말 산책단',
      'description': '함께 걸어요',
      'visibility': 'PRIVATE',
      'maxMembers': 12,
      'activeMemberCount': 2,
      'status': 'ACTIVE',
      'ownerUserId': 3,
      'ownerNickname': '정원',
      'joinable': false,
      'myRole': 'OWNER',
      'myMembershipStatus': 'ACTIVE',
      'members': [
        {
          'memberId': 11,
          'groupId': 7,
          'groupName': '주말 산책단',
          'userId': 3,
          'nickname': '정원',
          'role': 'OWNER',
          'status': 'ACTIVE',
        },
      ],
      'recentQuests': <Object>[],
    });

    expect(group.visibility, GroupVisibility.private);
    expect(group.isOwner, isTrue);
    expect(group.isActiveMember, isTrue);
    expect(group.members.single.role, GroupRole.owner);
  });

  test('LLM 추천 응답의 모델과 세 후보를 보존한다', () {
    final result = QuestRecommendationResult.fromJson({
      'provider': 'OPENAI',
      'model': 'gpt-5.6-luna',
      'remainingRequestsToday': 9,
      'candidates': [
        for (var index = 1; index <= 3; index++)
          {
            'index': index,
            'recommendationType': 'PLACE',
            'title': '추천 $index',
            'description': '설명',
            'category': 'EXPERIENCE',
            'durationValue': 90,
            'durationUnit': 'MINUTE',
            'estimatedCostPerPerson': 10000,
            'suggestedPlaceName': '성수동',
            'completionGuide': '사진 남기기',
          },
      ],
    });

    expect(result.model, 'gpt-5.6-luna');
    expect(result.candidates, hasLength(3));
    expect(result.candidates.first.type, RecommendationType.place);
  });

  test('레벨 응답의 주간·협동 해금 정보를 해석한다', () {
    final level = LevelStatus.fromJson({
      'level': 4,
      'totalExp': 350,
      'currentLevelExp': 50,
      'nextLevelRequiredExp': 100,
      'unlocks': {
        'daily': {'unlocked': true, 'requiredLevel': 1},
        'weekly': {'unlocked': true, 'requiredLevel': 3},
        'coop': {'unlocked': false, 'requiredLevel': 5},
      },
    });

    expect(level.unlocks.weekly.unlocked, isTrue);
    expect(level.unlocks.coop.unlocked, isFalse);
    expect(level.unlocks.coop.requiredLevel, 5);
  });
}
