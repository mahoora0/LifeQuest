import 'package:life_quest/features/notification/data/notification_dto.dart';
import 'package:life_quest/shared/data/sample_data.dart';

/// 알림 목록 조회·읽음 처리.
///
/// ⚠ **서버 미구현 구간이다.** `docs/04-api-spec.md`에 알림 엔드포인트가 아직 없다.
/// 표본은 시안(`LifeQuest 화면맵` 2d)의 예시를 옮긴 것으로 실제 사용자 데이터가 아니며,
/// [LqSampleData.guard] 때문에 **`LQ_SAMPLES`를 켰을 때만 나온다**(꺼져 있으면 준비 중 안내).
///
/// DTO에 이미 `fromJson`이 있으므로 프로바이더·화면은 손대지 않아도 된다.
///
// TODO(server): GET /api/notifications 개설 시 fetchFeed 본문을 Dio 호출로 바꾸고
//  LqSampleData.guard 호출과 _sample 상수를 지운다.
// TODO(server): PATCH /api/notifications/read 개설 시 markRead를 실제 호출로 바꾼다.
class NotificationRepository {
  const NotificationRepository();

  static const _sample = [
    LqNotification(
      id: 1,
      kind: LqNotificationKind.achievement,
      title: '비밀 업적 "야행성 탐험가" 해금!',
      timeLabel: '방금',
      route: '/achievements',
    ),
    LqNotification(
      id: 2,
      kind: LqNotificationKind.cheer,
      title: '하늘님이 응원을 보냈어요 · EXP 5',
      timeLabel: '2시간 전',
      leadingText: '하',
    ),
    LqNotification(
      id: 3,
      kind: LqNotificationKind.friendRequest,
      title: '솔방울님이 동료 신청을 보냈어요',
      timeLabel: '어제',
      leadingText: '솔',
      read: true,
      route: '/friends/requests',
    ),
    LqNotification(
      id: 4,
      kind: LqNotificationKind.questAssigned,
      title: '오늘의 퀘스트 3개가 도착했어요',
      timeLabel: '어제 · 오전 7:00',
      read: true,
      route: '/quests',
    ),
    LqNotification(
      id: 5,
      kind: LqNotificationKind.levelUp,
      title: 'Lv.12 달성 — 은빛 나침반 획득',
      timeLabel: '3일 전',
      leadingText: '12',
      read: true,
      route: '/rewards',
    ),
  ];

  Future<LqNotificationFeed> fetchFeed() async {
    LqSampleData.guard('알림');
    return const LqNotificationFeed(items: _sample);
  }

  /// 읽음 처리. 서버가 붙기 전까지는 성공한 것으로 둔다.
  ///
  /// [ids]가 비어 있으면 전체를 읽음으로 본다("모두 읽음").
  ///
  // TODO(server): 지금은 아무 일도 하지 않고 성공으로 보고한다. 앱을 다시 열면
  //  읽음 처리가 사라진다.
  Future<void> markRead(List<int> ids) async {}
}
