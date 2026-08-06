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
    this.profileImageUrl,
    this.statusLine,
    this.cheered = false,
  });

  final int userId;
  final String nickname;
  final int level;
  final String? profileImageUrl;

  /// 오늘 진행도나 최근 활동 같은 보조 문구. 서버가 주지 않으면 비운다.
  final String? statusLine;

  /// 오늘 이 친구를 응원했는지.
  final bool cheered;

  Friend copyWith({bool? cheered}) => Friend(
    userId: userId,
    nickname: nickname,
    level: level,
    profileImageUrl: profileImageUrl,
    statusLine: statusLine,
    cheered: cheered ?? this.cheered,
  );

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
    userId: asInt(pick(json, ['userId', 'id'])) ?? 0,
    nickname: asString(pick(json, ['nickname', 'name'])) ?? '모험가',
    level: asInt(json['level']) ?? 1,
    profileImageUrl: asString(json['profileImageUrl']),
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

/// 나와 상대의 관계. 동료 찾기 결과 행의 우측 표시가 이 값으로 갈린다.
enum FriendRelation {
  /// 아직 아무 관계도 아님 — 유일하게 누를 수 있는 상태.
  none('요청'),

  /// 이미 함께 모험 중.
  friend('친구'),

  /// 내가 보낸 요청이 처리되기를 기다리는 중.
  requestSent('대기'),

  /// 상대가 나에게 보낸 요청이 있음.
  ///
  // TODO(design): 시안의 동료 찾기는 상태를 셋(친구 / 요청 / 대기)으로만 그린다.
  //  "상대가 먼저 요청을 보낸 경우"의 표시가 정해지지 않아 대기와 같은 모습으로
  //  묶어 뒀다. 이 자리에서 바로 수락하게 할지, 받은 요청으로 보낼지 결정 필요.
  requestReceived('대기');

  const FriendRelation(this.actionLabel);

  /// 행 우측에 적는 짧은 라벨.
  final String actionLabel;

  /// 이 화면에서 누를 수 있는 것은 아직 관계가 없는 상대뿐이다.
  bool get isActionable => this == FriendRelation.none;

  static FriendRelation parse(String? raw) => switch (raw) {
    'FRIEND' || 'friend' => friend,
    'REQUEST_SENT' || 'requestSent' || 'PENDING' => requestSent,
    'REQUEST_RECEIVED' || 'requestReceived' => requestReceived,
    _ => none,
  };
}

/// 동료 찾기 결과 한 줄 (`GET /api/users/search`).
class AdventurerSearchResult {
  const AdventurerSearchResult({
    required this.userId,
    required this.nickname,
    required this.level,
    required this.relation,
    this.statusLine,
  });

  final int userId;
  final String nickname;
  final int level;
  final FriendRelation relation;

  /// "이미 함께 모험 중", "칭호 · 첫 걸음"처럼 관계·상태를 한 줄로 적은 보조 문구.
  final String? statusLine;

  AdventurerSearchResult copyWith({
    FriendRelation? relation,
    String? statusLine,
  }) => AdventurerSearchResult(
    userId: userId,
    nickname: nickname,
    level: level,
    relation: relation ?? this.relation,
    statusLine: statusLine ?? this.statusLine,
  );

  factory AdventurerSearchResult.fromJson(Map<String, dynamic> json) =>
      AdventurerSearchResult(
        userId: asInt(pick(json, ['userId', 'id'])) ?? 0,
        nickname: asString(pick(json, ['nickname', 'name'])) ?? '모험가',
        level: asInt(json['level']) ?? 1,
        relation: FriendRelation.parse(
          asString(pick(json, ['relation', 'status'])),
        ),
        statusLine: asString(pick(json, ['statusLine', 'summary'])),
      );
}

/// 동료 신청 한 건 (`GET /api/friends/requests`).
class FriendRequest {
  const FriendRequest({
    this.requestId = 0,
    required this.userId,
    required this.nickname,
    required this.level,
    this.statusLine,
  });

  final int requestId;
  final int userId;
  final String nickname;
  final int level;
  final String? statusLine;

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
    requestId: asInt(pick(json, ['requestId', 'id'])) ?? 0,
    userId: asInt(pick(json, ['userId', 'senderId', 'receiverId'])) ?? 0,
    nickname:
        asString(
          pick(json, ['nickname', 'senderNickname', 'receiverNickname']),
        ) ??
        '모험가',
    level: asInt(pick(json, ['level', 'senderLevel', 'receiverLevel'])) ?? 1,
    statusLine: asString(pick(json, ['statusLine', 'summary'])),
  );
}

/// 받은 요청 · 보낸 요청.
class FriendRequestBox {
  const FriendRequestBox({this.received = const [], this.sent = const []});

  final List<FriendRequest> received;
  final List<FriendRequest> sent;

  /// 친구 목록 상단 배너는 **받은** 요청이 있을 때만 뜬다.
  /// 보낸 요청은 내가 처리할 일이 아니라 기다릴 일이다.
  int get receivedCount => received.length;

  bool get isEmpty => received.isEmpty && sent.isEmpty;

  FriendRequestBox removeReceived(int userId) => FriendRequestBox(
    received: [
      for (final request in received)
        if (request.userId != userId) request,
    ],
    sent: sent,
  );

  FriendRequestBox removeSent(int requestId) => FriendRequestBox(
    received: received,
    sent: [
      for (final request in sent)
        if (request.requestId != requestId) request,
    ],
  );

  factory FriendRequestBox.fromJson(Object? body) {
    final json = asMap(body);
    return FriendRequestBox(
      received: asMapList(
        pick(json, ['received', 'incoming']),
      ).map(FriendRequest.fromJson).toList(),
      sent: asMapList(
        pick(json, ['sent', 'outgoing']),
      ).map(FriendRequest.fromJson).toList(),
    );
  }
}

/// 나란히 보기 한쪽의 수치.
class JourneySide {
  const JourneySide({
    required this.level,
    this.totalExp = 0,
    int? completedQuestCount,
    int? visitedPlaceCount,
    int? lifedexCollected,
    int? achievements,
    int? streakDays,
    int lifedexTotal = 100,
  }) : completedQuestCount = completedQuestCount ?? achievements ?? 0,
       visitedPlaceCount = visitedPlaceCount ?? lifedexCollected ?? 0;

  final int level;
  final int totalExp;
  final int completedQuestCount;
  final int visitedPlaceCount;

  factory JourneySide.fromJson(Map<String, dynamic> json) => JourneySide(
    level: asInt(json['level']) ?? 1,
    totalExp: asInt(json['totalExp']) ?? 0,
    completedQuestCount: asInt(json['completedQuestCount']) ?? 0,
    visitedPlaceCount: asInt(json['visitedPlaceCount']) ?? 0,
  );
}

/// 동료의 대표 배지 한 칸.
class JourneyBadge {
  const JourneyBadge({required this.name, this.iconAsset});

  final String name;

  /// 번들 아이콘 경로. 없으면 이름 첫 글자로 그린다(마이페이지 배지 칸과 같은 방식).
  final String? iconAsset;
}

/// S-21 동료 여정 비교 (`GET /api/friends/{userId}/journey`).
class FriendJourney {
  const FriendJourney({
    required this.userId,
    required this.nickname,
    required this.me,
    required this.friend,
    this.titleLine,
    this.cheered = false,
    this.badges = const [],
  });

  final int userId;
  final String nickname;

  /// "칭호 · 새벽의 개척자". 대표 칭호가 없으면 비운다.
  final String? titleLine;

  final bool cheered;
  final JourneySide me;
  final JourneySide friend;
  final List<JourneyBadge> badges;

  FriendJourney copyWith({bool? cheered}) => FriendJourney(
    userId: userId,
    nickname: nickname,
    titleLine: titleLine,
    cheered: cheered ?? this.cheered,
    me: me,
    friend: friend,
    badges: badges,
  );

  factory FriendJourney.fromJson(Object? body) {
    final json = asMap(body);
    return FriendJourney(
      userId: asInt(pick(json, ['userId', 'id'])) ?? 0,
      nickname: asString(pick(json, ['nickname', 'name'])) ?? '모험가',
      titleLine: asString(
        pick(json, ['titleLine', 'title', 'representativeTitle']),
      ),
      cheered: asBool(pick(json, ['cheered', 'cheeredToday'])),
      me: JourneySide.fromJson(asMap(json['me'])),
      friend: JourneySide.fromJson(asMap(pick(json, ['friend', 'other']))),
      badges: [
        if (asString(json['representativeBadge']) case final badge?)
          JourneyBadge(name: badge),
        for (final badge in asMapList(json['badges']))
          JourneyBadge(name: asString(pick(badge, ['name', 'label'])) ?? '배지'),
      ],
    );
  }
}

/// 주간 랭킹 한 줄 (`GET /api/rankings/friends`).
enum RankingType {
  exp('EXP'),
  level('LEVEL');

  const RankingType(this.apiValue);
  final String apiValue;
}

enum RankingScope {
  global('/rankings/global'),
  friends('/rankings/friends');

  const RankingScope(this.path);
  final String path;
}

typedef RankingQuery = ({RankingScope scope, RankingType type});

class RankEntry {
  const RankEntry({
    required this.rank,
    required this.userId,
    required this.nickname,
    required this.weeklyExp,
    this.level = 1,
    this.isMe = false,
  });

  final int rank;
  final int userId;
  final String nickname;
  final int weeklyExp;
  final int level;
  final bool isMe;

  factory RankEntry.fromJson(Map<String, dynamic> json) => RankEntry(
    rank: asInt(json['rank']) ?? 0,
    userId: asInt(pick(json, ['userId', 'id'])) ?? 0,
    nickname: asString(pick(json, ['nickname', 'name'])) ?? '모험가',
    weeklyExp: asInt(pick(json, ['weeklyExp', 'exp', 'totalExp'])) ?? 0,
    level: asInt(json['level']) ?? 1,
    isMe: asBool(pick(json, ['isMe', 'me'])),
  );
}

/// 이번 주 친구 랭킹.
class WeeklyRanking {
  const WeeklyRanking({
    required this.entries,
    this.rankDelta,
    this.totalElements,
  });

  final List<RankEntry> entries;

  /// 지난주 대비 순위 변동. 서버가 지난주 집계를 주지 않으면 null이고 등락 표시를 감춘다.
  /// 0을 기본값으로 두면 "변동 없음"이라는 없는 사실을 말하게 된다.
  final int? rankDelta;
  final int? totalElements;

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
      totalElements: asInt(json['totalElements']),
    );
  }
}
