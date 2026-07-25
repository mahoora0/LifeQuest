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
    this.representativeTitleId,
    this.representativeBadge,
    this.representativeBadgeId,
    this.selectedCharacter,
  });

  final int id;
  final String nickname;
  final String? email;
  final String? profileImageUrl;
  final String? role;
  final String? representativeTitle;
  final int? representativeTitleId;
  final String? representativeBadge;
  final int? representativeBadgeId;
  final AvatarCharacter? selectedCharacter;

  factory UserProfile.fromJson(Object? body) {
    final json = asMap(body);
    final title = json['representativeTitle'];
    final badge = json['representativeBadge'];
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
      representativeTitleId: title is Map ? asInt(asMap(title)['id']) : null,
      representativeBadge: badge is Map
          ? asString(asMap(badge)['name'])
          : asString(badge),
      representativeBadgeId: badge is Map ? asInt(asMap(badge)['id']) : null,
      selectedCharacter: json['selectedCharacter'] is Map
          ? AvatarCharacter.fromJson(asMap(json['selectedCharacter']))
          : null,
    );
  }
}

class AvatarCharacter {
  const AvatarCharacter({
    required this.id,
    required this.code,
    required this.name,
    required this.assetKey,
  });

  final int id;
  final String code;
  final String name;
  final String assetKey;

  factory AvatarCharacter.fromJson(Map<String, dynamic> json) =>
      AvatarCharacter(
        id: asInt(json['id']) ?? 0,
        code: asString(json['code']) ?? 'ROOKIE',
        name: asString(json['name']) ?? '캐릭터',
        assetKey: asString(json['assetKey']) ?? 'rookie.png',
      );
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
  const ProfileItem({
    required this.name,
    this.id,
    this.imageUrl,
    this.itemType,
    this.sourceType,
    this.acquiredAt,
  });

  final String name;
  final int? id;
  final String? imageUrl;
  final String? itemType;
  final String? sourceType;
  final DateTime? acquiredAt;

  factory ProfileItem.fromJson(Map<String, dynamic> json) => ProfileItem(
    id: asInt(pick(json, ['id', 'profileItemId'])),
    name: asString(pick(json, ['name', 'itemName'])) ?? '배지',
    imageUrl: asString(pick(json, ['imageUrl', 'iconUrl'])),
    itemType: asString(json['itemType']),
    sourceType: asString(json['sourceType']),
    acquiredAt: DateTime.tryParse(asString(json['acquiredAt']) ?? ''),
  );
}

class BadgeCollection {
  const BadgeCollection({
    required this.badges,
    required this.representativeBadgeId,
  });

  final List<ProfileItem> badges;
  final int? representativeBadgeId;

  factory BadgeCollection.fromJson(Object? body) {
    final json = asMap(body);
    return BadgeCollection(
      badges: asMapList(json['badges']).map(ProfileItem.fromJson).toList(),
      representativeBadgeId: asInt(json['representativeBadgeId']),
    );
  }
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
