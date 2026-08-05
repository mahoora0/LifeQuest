import 'package:life_quest/shared/data/json_reader.dart';

/// 알림 종류. 행 앞머리 표식과 진입 경로가 종류마다 다르다.
enum LqNotificationKind {
  /// 업적·비밀 업적 해금.
  achievement,

  /// 친구가 보낸 응원.
  cheer,

  /// 동료 신청 도착.
  friendRequest,

  /// 친구 요청 수락.
  friendAccepted,

  /// 오늘의 퀘스트 배정.
  questAssigned,

  /// 레벨업과 그에 딸린 보상.
  levelUp;

  static LqNotificationKind parse(String? raw) => switch (raw) {
    'ACHIEVEMENT' || 'achievement' => achievement,
    'CHEER' || 'cheer' => cheer,
    'FRIEND_REQUEST' || 'friendRequest' => friendRequest,
    'FRIEND_ACCEPTED' || 'friendAccepted' => friendAccepted,
    'LEVEL_UP' || 'levelUp' => levelUp,
    _ => questAssigned,
  };
}

/// 알림 한 줄 (`GET /api/notifications`).
class LqNotification {
  const LqNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.timeLabel,
    this.read = false,
    this.leadingText,
    this.route,
  });

  final int id;
  final LqNotificationKind kind;
  final String title;

  /// "방금", "2시간 전"처럼 서버가 이미 사람이 읽을 형태로 준 시점 문구.
  ///
  /// 클라이언트에서 상대 시각을 계산하지 않는다 — 기기 시계가 어긋나면
  /// "3일 전"이 "-1일 전"이 되는 식으로 조용히 틀린 값을 보여주게 된다.
  final String timeLabel;

  final bool read;

  /// 아바타 이니셜(응원·동료 신청)이나 레벨 숫자(레벨업)처럼 앞머리에 적을 짧은 글자.
  /// 없으면 종류별 기본 표식을 쓴다.
  final String? leadingText;

  /// 눌렀을 때 이동할 앱 내 경로. 서버가 주지 않으면 행은 읽음 처리만 한다.
  final String? route;

  LqNotification copyWith({bool? read}) => LqNotification(
    id: id,
    kind: kind,
    title: title,
    timeLabel: timeLabel,
    read: read ?? this.read,
    leadingText: leadingText,
    route: route,
  );

  factory LqNotification.fromJson(Map<String, dynamic> json) => LqNotification(
    id: asInt(pick(json, ['id', 'notificationId'])) ?? 0,
    kind: LqNotificationKind.parse(asString(pick(json, ['kind', 'type']))),
    title: asString(pick(json, ['title', 'message'])) ?? '',
    timeLabel: asString(pick(json, ['timeLabel', 'displayTime'])) ?? '',
    read: asBool(pick(json, ['read', 'isRead'])),
    leadingText: asString(pick(json, ['leadingText', 'initial'])),
    route: asString(pick(json, ['route', 'link'])),
  );
}

/// 알림 목록 + 읽지 않음 개수.
class LqNotificationFeed {
  const LqNotificationFeed({required this.items});

  final List<LqNotification> items;

  bool get isEmpty => items.isEmpty;

  int get unreadCount => items.where((item) => !item.read).length;

  factory LqNotificationFeed.fromJson(Object? body) {
    final json = asMap(body);
    return LqNotificationFeed(
      items: asMapList(
        pick(json, ['notifications', 'content', 'items']),
      ).map(LqNotification.fromJson).toList(),
    );
  }
}

/// 알림 수신 토글 4종.
///
/// 마감 임박 재촉만 기본 OFF다 — 격려 우선 원칙에서 유일하게 압박으로 읽힐 수 있는
/// 알림이라, 켜는 것을 사용자가 직접 고르게 한다.
enum LqNotificationChannel {
  questAssigned('오늘의 퀘스트 도착', 'quest_assigned', true),
  social('친구 응원 · 길드 초대', 'social', true),
  growth('업적 · 레벨업', 'growth', true),
  deadline('마감 임박 재촉', 'deadline', false);

  const LqNotificationChannel(this.label, this.key, this.defaultOn);

  final String label;
  final String key;
  final bool defaultOn;
}
