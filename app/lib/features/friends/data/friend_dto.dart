import 'package:life_quest/shared/data/json_reader.dart';

/// 친구 1명의 공개 정보 (`GET /api/friends`의 목록 항목).
///
/// 위치 관련 값은 담지 않는다 — 친구 API에 인증 좌표·실시간 위치·정확한 방문 시각을
/// 포함하지 않는다는 규칙(docs/05-business-rules.md §3-5)이 클라이언트 모델에도 그대로 적용된다.
class Friend {
  const Friend({
    required this.userId,
    required this.nickname,
    required this.level,
    this.statusLine,
    this.cheered = false,
  });

  final int userId;
  final String nickname;
  final int level;

  /// 오늘 진행도나 최근 활동 같은 보조 문구. 서버가 주지 않으면 비운다.
  final String? statusLine;

  /// 오늘 이 친구를 응원했는지.
  final bool cheered;

  Friend copyWith({bool? cheered}) => Friend(
    userId: userId,
    nickname: nickname,
    level: level,
    statusLine: statusLine,
    cheered: cheered ?? this.cheered,
  );

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
    userId: asInt(pick(json, ['userId', 'id'])) ?? 0,
    nickname: asString(pick(json, ['nickname', 'name'])) ?? '모험가',
    level: asInt(json['level']) ?? 1,
    statusLine: asString(pick(json, ['statusLine', 'activity', 'summary'])),
    cheered: asBool(pick(json, ['cheered', 'cheeredToday'])),
  );
}

/// 친구 목록 화면이 한 번에 필요로 하는 값 묶음.
class FriendList {
  const FriendList({required this.friends, this.myCode});

  final List<Friend> friends;

  /// 내 친구 코드. 서버가 주지 않으면 null이고 화면에서 코드 줄을 감춘다.
  final String? myCode;

  bool get isEmpty => friends.isEmpty;

  factory FriendList.fromJson(Object? body) {
    final json = asMap(body);
    return FriendList(
      friends: asMapList(
        pick(json, ['friends', 'content', 'items']),
      ).map(Friend.fromJson).toList(),
      myCode: asString(pick(json, ['myCode', 'friendCode'])),
    );
  }
}

/// 주간 랭킹 한 줄 (`GET /api/rankings/friends`).
class RankEntry {
  const RankEntry({
    required this.rank,
    required this.userId,
    required this.nickname,
    required this.weeklyExp,
    this.isMe = false,
  });

  final int rank;
  final int userId;
  final String nickname;
  final int weeklyExp;
  final bool isMe;

  factory RankEntry.fromJson(Map<String, dynamic> json) => RankEntry(
    rank: asInt(json['rank']) ?? 0,
    userId: asInt(pick(json, ['userId', 'id'])) ?? 0,
    nickname: asString(pick(json, ['nickname', 'name'])) ?? '모험가',
    weeklyExp: asInt(pick(json, ['weeklyExp', 'exp', 'totalExp'])) ?? 0,
    isMe: asBool(pick(json, ['isMe', 'me'])),
  );
}

/// 이번 주 친구 랭킹.
class WeeklyRanking {
  const WeeklyRanking({required this.entries, this.rankDelta});

  final List<RankEntry> entries;

  /// 지난주 대비 순위 변동. 서버가 지난주 집계를 주지 않으면 null이고 등락 표시를 감춘다.
  /// 0을 기본값으로 두면 "변동 없음"이라는 없는 사실을 말하게 된다.
  final int? rankDelta;

  bool get isEmpty => entries.isEmpty;

  /// 본인 행. 랭킹에 본인이 없으면 null이다.
  RankEntry? get me {
    for (final entry in entries) {
      if (entry.isMe) return entry;
    }
    return null;
  }

  /// 본인을 뺀 친구 수 — "N명 중" 문구에 쓴다.
  int get friendCount => entries.where((entry) => !entry.isMe).length;

  factory WeeklyRanking.fromJson(Object? body) {
    final json = asMap(body);
    return WeeklyRanking(
      entries: asMapList(
        pick(json, ['rankings', 'content', 'items']),
      ).map(RankEntry.fromJson).toList(),
      rankDelta: asInt(pick(json, ['rankDelta', 'change'])),
    );
  }
}
