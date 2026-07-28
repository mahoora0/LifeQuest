import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:life_quest/features/friends/application/friend_providers.dart';
import 'package:life_quest/features/friends/data/friend_dto.dart';
import 'package:life_quest/features/friends/data/friend_repository.dart';
import 'package:life_quest/features/friends/presentation/friend_journey_screen.dart';
import 'package:life_quest/features/friends/presentation/friends_screen.dart';
import 'package:life_quest/features/notification/application/notification_providers.dart';
import 'package:life_quest/features/notification/data/notification_dto.dart';
import 'package:life_quest/features/notification/data/notification_repository.dart';
import 'package:life_quest/features/notification/presentation/notification_screen.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 코드 리뷰가 프로브로 재현한 결함들을 고정한다.
///
/// 프로브는 한 번 확인하고 사라지므로, 같은 실수가 되돌아오는 것을 막으려면
/// 여기 남겨야 한다. 각 테스트는 고치기 전 코드에서 실패한다.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 시안 기준 프레임. 오버플로는 이 크기에서만 드러난다.
  void useDesignFrame(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpJourney(
    WidgetTester tester,
    FriendRepository repository, {
    int userId = 7,
  }) async {
    final router = GoRouter(
      initialLocation: '/friends/$userId',
      routes: [
        GoRoute(
          path: '/friends/:userId',
          builder: (context, state) => FriendJourneyScreen(
            userId: int.parse(state.pathParameters['userId']!),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [friendRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('동료 해제가 라우트의 상대에게 나간다', () {
    testWidgets('응답에 userId가 없어도 라우트 id로 호출한다', (tester) async {
      // 서버가 userId를 빠뜨리면 FriendJourney.fromJson이 0으로 채운다. 그 값으로
      // 프로바이더를 잡으면 되돌릴 수 없는 동작이 엉뚱한 상대에게 나간다.
      final repository = _SpyFriendRepository(responseUserId: 0);
      await pumpJourney(tester, repository, userId: 7);

      await tester.tap(find.text('동료 해제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('동료 해제').last);
      await tester.pumpAndSettle();

      expect(repository.unfriended, [7]);
    });

    testWidgets('응원도 라우트 id로 호출한다', (tester) async {
      final repository = _SpyFriendRepository(responseUserId: 0);
      await pumpJourney(tester, repository, userId: 7);

      await tester.tap(find.text('응원 보내기'));
      await tester.pumpAndSettle();

      expect(repository.cheered, [7]);
    });
  });

  group('빈 이름이 화면을 죽이지 않는다', () {
    testWidgets('배지 이름이 비어 있어도 여정 화면이 그려진다', (tester) async {
      // `''.characters.first`는 StateError를 던진다. 서버가 이름을 빈 문자열로
      // 주는 것은 이 앱의 마스킹 규약이라 실제로 올 수 있는 값이다.
      await pumpJourney(
        tester,
        _SpyFriendRepository(badges: const [JourneyBadge(name: '')]),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('나란히 보기'), findsOneWidget);
    });
  });

  group('디자인 프레임에서 넘치지 않는다', () {
    testWidgets('20자 닉네임이 카드 제목 띠를 넘치게 하지 않는다', (tester) async {
      useDesignFrame(tester);
      // 프로필 수정 화면이 20자까지 허용하므로 합법적인 입력이다.
      await pumpJourney(
        tester,
        _SpyFriendRepository(nickname: '가나다라마바사아자차카타파하가나다라마바'),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('배지가 여러 개여도 카드가 넘치지 않는다', (tester) async {
      useDesignFrame(tester);
      // 개수는 서버가 정한다 — 한 줄에 고정하면 일정 개수부터 반드시 넘친다.
      await pumpJourney(
        tester,
        _SpyFriendRepository(
          badges: const [
            JourneyBadge(name: '가'),
            JourneyBadge(name: '나'),
            JourneyBadge(name: '다'),
            JourneyBadge(name: '라'),
            JourneyBadge(name: '마'),
            JourneyBadge(name: '바'),
            JourneyBadge(name: '사'),
            JourneyBadge(name: '아'),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('알림 설정은 목록 상태와 무관하게 닿을 수 있다', () {
    Future<void> pumpNotifications(
      WidgetTester tester,
      NotificationRepository repository,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: NotificationScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('새 소식이 없어도 설정 카드가 남는다', (tester) async {
      await pumpNotifications(tester, const _EmptyNotificationRepository());

      expect(find.text('새 소식이 없어요'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('알림 설정'), 200);
      expect(find.text('알림 설정'), findsOneWidget);
    });

    testWidgets('준비 중 안내가 가리키는 설정 카드가 실제로 있다', (tester) async {
      await pumpNotifications(tester, const _NotReadyNotificationRepository());

      // 안내문이 "아래에서 미리 정해 둘 수 있어요"라고 말하는 대상이다.
      expect(find.text('알림은 아직 준비 중이에요'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('알림 설정'), 200);
      expect(find.text('알림 설정'), findsOneWidget);
      expect(find.text(LqNotificationChannel.deadline.label), findsOneWidget);
    });
  });

  group('받은 요청 배너는 목록이 실패해도 남는다', () {
    testWidgets('친구 목록이 준비 중이어도 요청 배너로 갈 수 있다', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            friendRepositoryProvider.overrideWithValue(
              _ListBrokenFriendRepository(),
            ),
          ],
          child: const MaterialApp(home: FriendsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('친구 목록은 아직 준비 중이에요'), findsOneWidget);
      // /friends/requests로 가는 유일한 문이다.
      expect(find.text('동료 신청이 2건 도착했어요'), findsOneWidget);
    });
  });

  group('응원 버튼이 행 탭을 삼킨다', () {
    testWidgets('응원함 ✓를 눌러도 여정 화면으로 넘어가지 않는다', (tester) async {
      final router = GoRouter(
        initialLocation: '/friends',
        routes: [
          GoRoute(
            path: '/friends',
            builder: (context, state) => const FriendsScreen(),
          ),
          GoRoute(
            path: '/friends/:userId',
            builder: (context, state) => const Scaffold(body: Text('여정 화면 도착')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            friendRepositoryProvider.overrideWithValue(
              _CheeredFriendRepository(),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // 이미 응원한 버튼은 아무 일도 하지 않아야 한다. 빈 콜백을 지우면 부모가
      // 탭을 가져가 여기서 화면이 넘어간다.
      await tester.tap(find.text('응원함 ✓'));
      await tester.pumpAndSettle();
      expect(find.text('여정 화면 도착'), findsNothing);

      // 같은 행의 이름을 누르면 넘어가야 한다 — 행 자체는 살아 있다는 대조군.
      await tester.tap(find.text('하늘'));
      await tester.pumpAndSettle();
      expect(find.text('여정 화면 도착'), findsOneWidget);
    });
  });
}

class _SpyFriendRepository extends FriendRepository {
  _SpyFriendRepository({
    this.responseUserId = 7,
    this.nickname = '하늘',
    this.badges = const [JourneyBadge(name: '새벽의 개척자')],
  });

  final int responseUserId;
  final String nickname;
  final List<JourneyBadge> badges;

  final unfriended = <int>[];
  final cheered = <int>[];

  @override
  Future<FriendJourney> fetchJourney(int userId) async => FriendJourney(
    userId: responseUserId,
    nickname: nickname,
    titleLine: '칭호 · 새벽의 개척자',
    me: const JourneySide(level: 12, lifedexCollected: 42, achievements: 24),
    friend: const JourneySide(
      level: 14,
      lifedexCollected: 51,
      achievements: 31,
    ),
    badges: badges,
  );

  @override
  Future<void> unfriend(int userId) async => unfriended.add(userId);

  @override
  Future<void> cheer(int userId) async => cheered.add(userId);

  @override
  Future<FriendList> fetchFriends() async => const FriendList(friends: []);
}

class _CheeredFriendRepository extends FriendRepository {
  @override
  Future<FriendList> fetchFriends() async => const FriendList(
    myCode: 'LQ-4821',
    friends: [Friend(userId: 3, nickname: '하늘', level: 14, cheered: true)],
  );

  @override
  Future<FriendRequestBox> fetchRequests() async => const FriendRequestBox();
}

class _ListBrokenFriendRepository extends FriendRepository {
  @override
  Future<FriendList> fetchFriends() async {
    throw const ApiException(
      code: 'FEATURE_NOT_READY',
      message: '',
      statusCode: 404,
    );
  }

  @override
  Future<FriendRequestBox> fetchRequests() async => const FriendRequestBox(
    received: [
      FriendRequest(userId: 20, nickname: '솔방울', level: 13),
      FriendRequest(userId: 21, nickname: '단풍', level: 4),
    ],
  );
}

class _EmptyNotificationRepository extends NotificationRepository {
  const _EmptyNotificationRepository();

  @override
  Future<LqNotificationFeed> fetchFeed() async =>
      const LqNotificationFeed(items: []);
}

class _NotReadyNotificationRepository extends NotificationRepository {
  const _NotReadyNotificationRepository();

  @override
  Future<LqNotificationFeed> fetchFeed() async {
    throw const ApiException(
      code: 'FEATURE_NOT_READY',
      message: '',
      statusCode: 404,
    );
  }
}
