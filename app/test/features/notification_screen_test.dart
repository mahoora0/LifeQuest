import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/notification/application/notification_providers.dart';
import 'package:life_quest/features/notification/data/notification_dto.dart';
import 'package:life_quest/features/notification/data/notification_repository.dart';
import 'package:life_quest/features/notification/presentation/notification_screen.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 알림 목록 + 설정 (화면맵 2d).
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('백엔드 알림 목록과 친구 수락 종류를 해석한다', () {
    final feed = LqNotificationFeed.fromJson({
      'content': [
        {
          'id': 42,
          'kind': 'FRIEND_ACCEPTED',
          'title': '친구 요청을 수락했어요',
          'timeLabel': '방금',
          'read': false,
          'route': '/friends',
        },
      ],
      'unreadCount': 1,
    });

    expect(feed.items, hasLength(1));
    expect(feed.items.single.kind, LqNotificationKind.friendAccepted);
    expect(feed.items.single.route, '/friends');
    expect(feed.unreadCount, 1);
  });

  Future<void> pumpNotifications(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(
            const _FakeNotificationRepository(),
          ),
        ],
        child: const MaterialApp(home: NotificationScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 읽지 않은 행은 tint 배경 + ink 테두리를 쓴다. 행 라운드로 설정 카드와 가른다.
  int unreadRows(WidgetTester tester) => tester
      .widgetList<LqCard>(find.byType(LqCard))
      .where(
        (card) =>
            card.radius == LqShape.rowRadius &&
            card.background == LqColors.surfaceCard,
      )
      .length;

  testWidgets('읽지 않음과 읽음을 배경으로 구분한다', (tester) async {
    await pumpNotifications(tester);

    expect(find.text('비밀 업적 "야행성 탐험가" 해금!'), findsOneWidget);
    expect(find.text('방금'), findsOneWidget);
    expect(unreadRows(tester), 2);
  });

  testWidgets('오늘의 퀘스트 알림은 중복 페이지 없이 퀘스트 탭으로 이동한다', (tester) async {
    final router = GoRouter(
      initialLocation: '/notifications',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => Scaffold(body: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/quests',
                  builder: (context, state) => const Text('퀘스트 목록'),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(
            const _QuestNotificationRepository(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('오늘의 퀘스트가 도착했어요'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/quests');
    expect(find.text('퀘스트 목록'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('모두 읽음을 누르면 읽지 않은 행이 남지 않는다', (tester) async {
    await pumpNotifications(tester);

    await tester.tap(find.text('모두 읽음'));
    await tester.pumpAndSettle();

    expect(unreadRows(tester), 0);
    // 행 자체는 사라지지 않는다 — 읽었다고 소식이 없어지는 것은 아니다.
    expect(find.text('비밀 업적 "야행성 탐험가" 해금!'), findsOneWidget);
  });

  testWidgets('시점 문구는 서버가 준 것을 그대로 쓴다', (tester) async {
    await pumpNotifications(tester);

    // 기기 시계가 어긋나도 "3일 전"이 "-1일 전"이 되지 않아야 한다.
    expect(find.text('어제 · 오전 7:00'), findsOneWidget);
  });

  testWidgets('알림 설정 4종을 목록 하단에 함께 둔다', (tester) async {
    await pumpNotifications(tester);

    await tester.scrollUntilVisible(find.text('알림 설정'), 200);
    await tester.pumpAndSettle();

    for (final channel in LqNotificationChannel.values) {
      expect(find.text(channel.label), findsOneWidget);
    }
    expect(find.text('"재촉" 계열은 기본으로 꺼 둬요. 필요할 때만 켜세요.'), findsOneWidget);
  });

  test('마감 임박 재촉만 기본으로 꺼져 있다', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final settings = await container.read(notificationSettingsProvider.future);

    expect(settings[LqNotificationChannel.questAssigned], isTrue);
    expect(settings[LqNotificationChannel.social], isTrue);
    expect(settings[LqNotificationChannel.growth], isTrue);
    // 격려 우선 원칙에서 유일하게 압박으로 읽힐 수 있는 알림이다.
    expect(settings[LqNotificationChannel.deadline], isFalse);
  });

  test('토글은 기기에 남아 다시 열어도 되살아나지 않는다', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(notificationSettingsProvider.future);

    await container
        .read(notificationSettingsProvider.notifier)
        .toggle(LqNotificationChannel.questAssigned, false);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('notification.channel.quest_assigned'), isFalse);
  });
}

class _FakeNotificationRepository extends NotificationRepository {
  const _FakeNotificationRepository();

  @override
  Future<LqNotificationFeed> fetchFeed() async => const LqNotificationFeed(
    items: [
      LqNotification(
        id: 1,
        kind: LqNotificationKind.achievement,
        title: '비밀 업적 "야행성 탐험가" 해금!',
        timeLabel: '방금',
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
        kind: LqNotificationKind.questAssigned,
        title: '오늘의 퀘스트 3개가 도착했어요',
        timeLabel: '어제 · 오전 7:00',
        read: true,
      ),
    ],
  );
}

class _QuestNotificationRepository extends NotificationRepository {
  const _QuestNotificationRepository();

  @override
  Future<LqNotificationFeed> fetchFeed() async => const LqNotificationFeed(
    items: [
      LqNotification(
        id: 100,
        kind: LqNotificationKind.questAssigned,
        title: '오늘의 퀘스트가 도착했어요',
        timeLabel: '방금',
        route: '/quests',
      ),
    ],
  );
}
