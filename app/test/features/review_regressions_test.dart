import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/friends/application/friend_providers.dart';
import 'package:life_quest/features/friends/data/friend_dto.dart';
import 'package:life_quest/features/friends/data/friend_repository.dart';
import 'package:life_quest/features/friends/presentation/friend_journey_screen.dart';
import 'package:life_quest/features/friends/presentation/friends_screen.dart';
import 'package:life_quest/features/lifedex/application/lifedex_providers.dart';
import 'package:life_quest/features/lifedex/data/lifedex_dto.dart';
import 'package:life_quest/features/lifedex/data/lifedex_repository.dart';
import 'package:life_quest/features/lifedex/presentation/lifedex_screen.dart';
import 'package:life_quest/features/notification/application/notification_providers.dart';
import 'package:life_quest/features/notification/data/notification_dto.dart';
import 'package:life_quest/features/notification/data/notification_repository.dart';
import 'package:life_quest/features/home/presentation/home_screen.dart';
import 'package:life_quest/features/notification/presentation/notification_screen.dart';
import 'package:life_quest/features/quest/application/quest_providers.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/data/quest_repository.dart';
import 'package:life_quest/features/quest/presentation/quest_list_screen.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/core/network/provider_retry.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/stub_location_service.dart';

/// 코드 리뷰가 프로브로 재현한 결함들을 고정한다.
///
/// 프로브는 한 번 확인하고 사라지므로, 같은 실수가 되돌아오는 것을 막으려면
/// 여기 남겨야 한다. 각 테스트는 고치기 전 코드에서 실패한다.
void main() {
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

  group('친구 삭제가 라우트의 상대에게 나간다', () {
    testWidgets('확인 팝업에서 취소하면 삭제하지 않는다', (tester) async {
      final repository = _SpyFriendRepository();
      await pumpJourney(tester, repository, userId: 7);

      await tester.scrollUntilVisible(find.text('친구 삭제'), 200);
      await tester.tap(find.text('친구 삭제'));
      await tester.pumpAndSettle();
      expect(find.textContaining('다시 함께하려면 친구 요청을 새로 보내야 해요.'), findsOneWidget);

      await tester.tap(find.text('그대로 둘래요'));
      await tester.pumpAndSettle();

      expect(repository.unfriended, isEmpty);
    });

    testWidgets('응답에 userId가 없어도 라우트 id로 호출한다', (tester) async {
      // 서버가 userId를 빠뜨리면 FriendJourney.fromJson이 0으로 채운다. 그 값으로
      // 프로바이더를 잡으면 되돌릴 수 없는 동작이 엉뚱한 상대에게 나간다.
      final repository = _SpyFriendRepository(responseUserId: 0);
      await pumpJourney(tester, repository, userId: 7);

      await tester.scrollUntilVisible(find.text('친구 삭제'), 200);
      await tester.tap(find.text('친구 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('친구 삭제').last);
      await tester.pumpAndSettle();

      expect(repository.unfriended, [7]);
    });

    testWidgets('응원도 라우트 id로 호출한다', (tester) async {
      final repository = _SpyFriendRepository(responseUserId: 0);
      await pumpJourney(tester, repository, userId: 7);

      await tester.scrollUntilVisible(find.text('응원 보내기'), 200);
      await tester.tap(find.text('응원 보내기'));
      await tester.pumpAndSettle();

      expect(repository.cheered, [7]);
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

    testWidgets('두 줄로 접히는 장소 이름이 도감 타일을 넘치게 하지 않는다', (tester) async {
      useDesignFrame(tester);
      // 도감이 전국으로 넓어지면서 "서울시립미술관"처럼 타일 폭에서 두 줄이 되는
      // 이름이 들어왔다. 타일 높이는 childAspectRatio가 고정하므로, 두 줄 이름은
      // 한 줄 이름이 남기던 여백을 다 쓰고도 모자란다.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lifedexRepositoryProvider.overrideWithValue(
              _TwoLineLifedexRepository(),
            ),
          ],
          child: const MaterialApp(home: LifedexScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // 카테고리 격자(S-13)와 항목 격자(S-14)는 같은 타일을 쓴다. 둘 다 본다.
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('문화 · 전시').first);
      await tester.pumpAndSettle();

      expect(find.text('서울시립미술관'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('홈 알림 화면은 기록만 보여 준다', () {
    Future<void> pumpNotifications(
      WidgetTester tester,
      NotificationRepository repository,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stubLocation,
            notificationRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: NotificationScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('새 소식이 없을 때도 설정은 노출하지 않는다', (tester) async {
      await pumpNotifications(tester, const _EmptyNotificationRepository());

      expect(find.text('새 소식이 없어요'), findsOneWidget);
      expect(find.text('알림 설정'), findsNothing);
    });

    testWidgets('준비 중이어도 설정은 노출하지 않는다', (tester) async {
      await pumpNotifications(tester, const _NotReadyNotificationRepository());

      expect(find.text('알림은 아직 준비 중이에요'), findsOneWidget);
      expect(find.text('알림 설정'), findsNothing);
      expect(find.text(LqNotificationChannel.deadline.label), findsNothing);
    });
  });

  group('준비 중에는 재시도 버튼을 붙이지 않는다', () {
    // 시안 §5 상태 4종 — "준비 중: 재시도 버튼 없음. 눌러도 결과가 같아 헛돌게 됨."
    //
    // 백엔드가 미매핑 경로를 500으로 감싸던 동안에는 준비 중 분기 자체가 죽어 있어
    // 이 규칙을 어긴 화면이 드러나지 않았다. 서버가 ENDPOINT_NOT_FOUND를 내보내기
    // 시작하자 홈·목록·상세가 "아직 준비 중인 기능이에요" 아래에 "다시 시도"를
    // 달고 있는 것이 실기기에서 보였다.
    testWidgets('홈의 오늘의 퀘스트', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          // 앱과 같은 재시도 정책을 써야 404가 즉시 실패로 확정된다. 기본 정책은
          // 4xx도 재시도해서 화면이 로딩에 머문다.
          retry: lqProviderRetry,
          overrides: [
            stubLocation,
            questRepositoryProvider.overrideWithValue(
              _NotReadyQuestRepository(),
            ),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      // 홈은 프로필·레벨도 함께 물어 스피너가 계속 돌므로 pumpAndSettle이 끝나지
      // 않는다. 퀘스트 카드가 상태를 잡는 데 필요한 만큼만 진행시킨다.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('오늘의 퀘스트는 아직 준비 중이에요'), findsOneWidget);
      expect(find.text('다시 시도'), findsNothing);
    });

    testWidgets('퀘스트 목록', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          // 앱과 같은 재시도 정책을 써야 404가 즉시 실패로 확정된다. 기본 정책은
          // 4xx도 재시도해서 화면이 로딩에 머문다.
          retry: lqProviderRetry,
          overrides: [
            stubLocation,
            questRepositoryProvider.overrideWithValue(
              _NotReadyQuestRepository(),
            ),
          ],
          child: const MaterialApp(home: QuestListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('퀘스트 목록은 아직 준비 중이에요'), findsOneWidget);
      expect(find.text('다시 시도'), findsNothing);
      // 헤더는 본문과 분리되어 남아야 한다.
      expect(find.text('퀘스트 목록'), findsOneWidget);
    });
  });

  group('헤더 보조 버튼이 제목과 뒤로 가기를 덮지 않는다', () {
    testWidgets('뒤로 가기 자리를 눌러도 전체 읽음이 실행되지 않는다', (tester) async {
      // 실기기에서 잡힌 결함. `Container`에 `alignment`를 주면 부모가 허용하는
      // 최대 폭까지 커지는데, 헤더가 Stack이라 그 최대치가 화면 폭이었다.
      // "모두 읽음"이 제목 위를 덮고 좌상단까지 탭 영역으로 먹어, 뒤로 가려던
      // 탭이 전체 읽음을 실행했다. 오버플로 예외가 아니라 위젯 테스트로도
      // 화면 캡처로도 드러나지 않고 눌러 봐야만 나타난다.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stubLocation,
            notificationRepositoryProvider.overrideWithValue(
              const _UnreadNotificationRepository(),
            ),
          ],
          child: const MaterialApp(home: NotificationScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final header = tester.getRect(find.byType(LqHeader));
      final markAllRead = tester.getRect(
        find
            .ancestor(
              of: find.text('모두 읽음'),
              matching: find.byType(GestureDetector),
            )
            .first,
      );

      // 탭 영역이 헤더 오른쪽 절반 안에 있어야 뒤로 가기·제목과 겹치지 않는다.
      expect(markAllRead.left, greaterThan(header.center.dx));
    });
  });

  group('받은 요청 배너는 목록이 실패해도 남는다', () {
    testWidgets('친구 목록이 준비 중이어도 요청 배너로 갈 수 있다', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stubLocation,
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
      expect(find.text('친구 요청이 2건 도착했어요'), findsOneWidget);
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
            stubLocation,
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
  _SpyFriendRepository({this.responseUserId = 7, this.nickname = '하늘'});

  final int responseUserId;
  final String nickname;

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
      code: 'ENDPOINT_NOT_FOUND',
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

class _NotReadyQuestRepository extends QuestRepository {
  _NotReadyQuestRepository() : super(Dio());

  @override
  Future<TodayQuests> fetchToday({double? latitude, double? longitude}) async {
    throw const ApiException(
      code: 'ENDPOINT_NOT_FOUND',
      message: '',
      statusCode: 404,
    );
  }
}

class _UnreadNotificationRepository extends NotificationRepository {
  const _UnreadNotificationRepository();

  @override
  Future<LqNotificationFeed> fetchFeed() async => const LqNotificationFeed(
    items: [
      LqNotification(
        id: 1,
        kind: LqNotificationKind.achievement,
        title: '비밀 업적 해금!',
        timeLabel: '방금',
      ),
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
      code: 'ENDPOINT_NOT_FOUND',
      message: '',
      statusCode: 404,
    );
  }
}

/// 이름이 타일 폭에서 두 줄로 접히는 도감. 카테고리·항목 양쪽 다 두 줄이다.
class _TwoLineLifedexRepository extends LifedexRepository {
  _TwoLineLifedexRepository() : super(Dio());

  @override
  Future<LifedexOverview> fetchOverview() async => const LifedexOverview(
    categories: [
      LifedexCategory(id: 3, name: '문화 · 전시', totalCount: 38, ownedCount: 3),
    ],
  );

  @override
  Future<List<LifedexItem>> fetchItems(int categoryId) async => const [
    LifedexItem(id: 501, name: '서울시립미술관', categoryId: 3, owned: true),
    // 미획득 타일은 이름이 '?' 한 줄이지만 캡션이 두 줄이라, 반대쪽 한계다.
    LifedexItem(id: 502, name: '국립중앙박물관', categoryId: 3, owned: false),
  ];
}
