import 'package:life_quest/shared/data/json_reader.dart';

/// `GET /users/me`
class UserProfile {
  const UserProfile({
    required this.id,
    required this.nickname,
    this.email,
    this.profileImageUrl,
    this.role,
    this.representativeTitle,
  });

  final int id;
  final String nickname;
  final String? email;
  final String? profileImageUrl;
  final String? role;
  final String? representativeTitle;

  factory UserProfile.fromJson(Object? body) {
    final json = asMap(body);
    final title = json['representativeTitle'];
    return UserProfile(
      id: asInt(pick(json, ['id', 'userId'])) ?? 0,
      nickname: asString(json['nickname']) ?? '모험가',
      email: asString(json['email']),
      profileImageUrl: asString(json['profileImageUrl']),
      role: asString(json['role']),
      // 문자열로 오든 `{id,name}` 객체로 오든 이름만 뽑아 쓴다.
      representativeTitle: title is Map
          ? asString(asMap(title)['name'])
          : asString(title),
    );
  }
}

/// `GET /users/me/level`
class LevelStatus {
  const LevelStatus({
    required this.level,
    required this.totalExp,
    required this.currentLevelExp,
    required this.nextLevelRequiredExp,
  });

  final int level;
  final int totalExp;
  final int currentLevelExp;
  final int nextLevelRequiredExp;

  int get remainingExp =>
      (nextLevelRequiredExp - currentLevelExp).clamp(0, nextLevelRequiredExp);

  factory LevelStatus.fromJson(Object? body) {
    final json = asMap(body);
    return LevelStatus(
      level: asInt(json['level']) ?? 1,
      totalExp: asInt(json['totalExp']) ?? 0,
      currentLevelExp: asInt(json['currentLevelExp']) ?? 0,
      nextLevelRequiredExp: asInt(json['nextLevelRequiredExp']) ?? 0,
    );
  }
}

/// 보유 칭호 1건.
class UserTitle {
  const UserTitle({required this.id, required this.name, this.description});

  final int id;
  final String name;
  final String? description;

  factory UserTitle.fromJson(Map<String, dynamic> json) => UserTitle(
    id: asInt(pick(json, ['id', 'titleId'])) ?? 0,
    name: asString(pick(json, ['name', 'title'])) ?? '칭호',
    description: asString(pick(json, ['description', 'condition'])),
  );
}

/// `GET /users/me/titles`
class TitleCollection {
  const TitleCollection({
    required this.titles,
    required this.representativeTitleId,
  });

  final List<UserTitle> titles;
  final int? representativeTitleId;

  factory TitleCollection.fromJson(Object? body) {
    final json = asMap(body);
    return TitleCollection(
      titles: asMapList(
        pick(json, ['titles', 'content', 'items']),
      ).map(UserTitle.fromJson).toList(),
      representativeTitleId: asInt(json['representativeTitleId']),
    );
  }
}

/// 프로필 아이템(마이페이지 "내 배지").
class ProfileItem {
  const ProfileItem({required this.name, this.id, this.imageUrl});

  final String name;
  final int? id;
  final String? imageUrl;

  factory ProfileItem.fromJson(Map<String, dynamic> json) => ProfileItem(
    id: asInt(pick(json, ['id', 'profileItemId'])),
    name: asString(pick(json, ['name', 'itemName'])) ?? '배지',
    imageUrl: asString(pick(json, ['imageUrl', 'iconUrl'])),
  );
}

/// `GET /users/me/rewards`
class RewardHistory {
  const RewardHistory({required this.titles, required this.profileItems});

  final List<UserTitle> titles;
  final List<ProfileItem> profileItems;

  factory RewardHistory.fromJson(Object? body) {
    final json = asMap(body);
    return RewardHistory(
      titles: asMapList(json['titles']).map(UserTitle.fromJson).toList(),
      profileItems: asMapList(
        json['profileItems'],
      ).map(ProfileItem.fromJson).toList(),
    );
  }
}
