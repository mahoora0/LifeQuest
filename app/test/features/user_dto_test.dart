import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/user/data/user_dto.dart';

void main() {
  test('프로필 사진과 게임 캐릭터를 별도 필드로 파싱한다', () {
    final profile = UserProfile.fromJson({
      'id': 7,
      'nickname': '모험가',
      'profileImageUrl': '/uploads/profile/me.png',
      'representativeTitle': {'id': 1, 'name': '새내기 모험가'},
      'selectedCharacter': {
        'id': 3,
        'code': 'MONGLE',
        'name': '몽글',
        'assetKey': 'mongle.png',
      },
      'selectedAccessory': {'id': 5, 'code': 'EXPLORER_HAT', 'name': '탐험가 모자'},
    });

    expect(profile.profileImageUrl, '/uploads/profile/me.png');
    expect(profile.selectedCharacter?.code, 'MONGLE');
    expect(profile.selectedAccessory?.code, 'EXPLORER_HAT');
    expect(profile.representativeTitleId, 1);
  });

  test('최근 획득은 칭호와 아이템을 획득 시각 내림차순으로 합친다', () {
    final history = RewardHistory.fromJson({
      'titles': [
        {'id': 1, 'name': '새내기 모험가', 'acquiredAt': '2026-07-20T10:00:00Z'},
      ],
      'profileItems': [
        {
          'id': 2,
          'name': '탐험가 모자',
          'itemType': 'OUTFIT',
          'acquiredAt': '2026-07-25T09:00:00Z',
        },
        {
          'id': 3,
          'name': '이름표',
          'itemType': 'NAMEPLATE',
          'acquiredAt': '2026-07-22T09:00:00Z',
        },
      ],
    });

    // 두 목록이 각각 최신순으로 와도 종류를 섞으면 순서가 깨진다.
    expect(history.recent.map((entry) => entry.name), [
      '탐험가 모자',
      '이름표',
      '새내기 모험가',
    ]);
    expect(history.recent.first.kind, RewardKind.item);
    expect(history.recent[1].kind, RewardKind.item);
    expect(history.recent.last.kind, RewardKind.title);
  });

  test('획득 시각이 없는 보상은 최신으로 오해되지 않게 뒤로 밀린다', () {
    final history = RewardHistory.fromJson({
      'titles': [
        {'id': 1, 'name': '시각 없는 칭호'},
      ],
      'profileItems': [
        {
          'id': 2,
          'name': '탐험가 모자',
          'itemType': 'OUTFIT',
          'acquiredAt': '2026-07-25T09:00:00Z',
        },
      ],
    });

    expect(history.recent.map((entry) => entry.name), ['탐험가 모자', '시각 없는 칭호']);
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

  test('캐릭터별 착용 액세서리를 파싱한다', () {
    final collection = AccessoryCollection.fromJson({
      'accessories': [
        {'id': 4, 'code': 'APRON', 'name': '앞치마'},
        {'id': 5, 'code': 'EXPLORER_HAT', 'name': '탐험가 모자'},
      ],
      'selectedAccessoryId': 5,
      'selectedAccessoryIdsByCharacter': {'1': 4, '2': 5},
    });

    expect(collection.selectedAccessoryIdsByCharacter, {1: 4, 2: 5});
  });
}
