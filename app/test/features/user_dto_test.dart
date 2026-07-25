import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/user/data/user_dto.dart';

void main() {
  test('프로필 사진과 게임 캐릭터를 별도 필드로 파싱한다', () {
    final profile = UserProfile.fromJson({
      'id': 7,
      'nickname': '모험가',
      'profileImageUrl': '/uploads/profile/me.png',
      'representativeTitle': {'id': 1, 'name': '새내기 모험가'},
      'representativeBadge': {'id': 2, 'name': '나침반 배지'},
      'selectedCharacter': {
        'id': 3,
        'code': 'MONGLE',
        'name': '몽글',
        'assetKey': 'mongle.png',
      },
    });

    expect(profile.profileImageUrl, '/uploads/profile/me.png');
    expect(profile.selectedCharacter?.code, 'MONGLE');
    expect(profile.representativeTitleId, 1);
    expect(profile.representativeBadge, '나침반 배지');
  });

  test('대표 배지 목록과 선택 상태를 파싱한다', () {
    final collection = BadgeCollection.fromJson({
      'badges': [
        {'id': 1, 'name': '새싹 배지', 'itemType': 'BADGE'},
        {'id': 2, 'name': '나침반 배지', 'itemType': 'BADGE'},
      ],
      'representativeBadgeId': 2,
    });

    expect(collection.badges.map((item) => item.name), ['새싹 배지', '나침반 배지']);
    expect(collection.representativeBadgeId, 2);
  });

  test('명세 공식에 맞는 레벨 진행률 응답을 파싱한다', () {
    final level = LevelStatus.fromJson({
      'level': 3,
      'totalExp': 350,
      'currentLevelExp': 50,
      'nextLevelRequiredExp': 300,
    });

    expect(level.remainingExp, 250);
  });
}
