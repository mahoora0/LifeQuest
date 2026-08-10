import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/friends/application/friend_providers.dart';
import 'package:life_quest/features/friends/data/friend_dto.dart';
import 'package:life_quest/features/friends/data/friend_repository.dart';
import 'package:life_quest/features/friends/presentation/friend_journey_screen.dart';
import 'package:life_quest/features/friends/presentation/friend_requests_screen.dart';
import 'package:life_quest/features/friends/presentation/friend_search_screen.dart';

/// 친구 확장 3화면(S-18 · S-19 · S-21).
void main() {
  test('친구 목록 응답에서 프로필 사진 URL을 파싱한다', () {
    final friend = Friend.fromJson(const {
      'userId': 7,
      'nickname': '하늘',
      'level': 4,
      'profileImageUrl': '/uploads/profiles/sky.png',
    });

    expect(friend.profileImageUrl, '/uploads/profiles/sky.png');
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          friendRepositoryProvider.overrideWithValue(
            const _FakeFriendRepository(),
          ),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('S-18 동료 찾기', () {
    testWidgets('검색 전에는 결과 없음이 아니라 안내를 보여준다', (tester) async {
      await pump(tester, const FriendSearchScreen());

      // 아직 찾지 않은 것과 찾았는데 없는 것은 다른 상태다.
      expect(find.text('함께할 동료의 닉네임을 적어 보세요'), findsOneWidget);
      expect(find.textContaining('검색 결과'), findsNothing);
      // 코드 카드는 검색과 무관하게 늘 보인다.
      expect(find.text('내 코드 · LQ-4821'), findsOneWidget);
    });

    testWidgets('관계 3상태를 각각 다른 라벨로 구분한다', (tester) async {
      await pump(tester, const FriendSearchScreen());

      await tester.enterText(find.byType(TextField), '초록');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('검색 결과 3명'), findsOneWidget);
      expect(find.text('친구'), findsOneWidget);
      expect(find.text('요청'), findsOneWidget);
      expect(find.text('대기'), findsOneWidget);
      expect(find.text('이미 함께 모험 중'), findsOneWidget);
    });

    testWidgets('요청을 보내면 대기로 바뀌고 다시 누를 수 없다', (tester) async {
      await pump(tester, const FriendSearchScreen());

      await tester.enterText(find.byType(TextField), '초록');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      await tester.tap(find.text('요청'));
      await tester.pumpAndSettle();

      expect(find.text('요청'), findsNothing);
      expect(find.text('대기'), findsNWidgets(2));
      expect(find.text('요청을 보냈어요 · 대기 중'), findsNWidgets(2));
    });

    testWidgets('찾지 못하면 질의어를 짚어 알린다', (tester) async {
      await pump(tester, const FriendSearchScreen());

      await tester.enterText(find.byType(TextField), '없는이름');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('"없는이름" 로는 아직 못 찾았어요'), findsOneWidget);
    });
  });

  group('S-19 받은 요청', () {
    testWidgets('받은 요청을 함께하기·거절 두 갈래로 보여준다', (tester) async {
      await pump(tester, const FriendRequestsScreen());

      expect(find.text('받은 요청 2'), findsOneWidget);
      expect(find.text('보낸 요청 1'), findsOneWidget);
      expect(find.text('솔방울'), findsOneWidget);
      // 수락 카피는 "수락"이 아니라 길드 어휘를 쓴다.
      expect(find.text('함께하기'), findsNWidgets(2));
      expect(find.text('수락'), findsNothing);
    });

    testWidgets('보낸 요청 탭에서 대기 중인 상대를 확인한다', (tester) async {
      await pump(tester, const FriendRequestsScreen());

      await tester.tap(find.text('보낸 요청 1'));
      await tester.pumpAndSettle();

      expect(find.text('초록수풀'), findsOneWidget);
      expect(find.text('요청 수락을 기다리는 중'), findsOneWidget);
      expect(find.text('요청 취소'), findsOneWidget);
    });

    testWidgets('보낸 요청을 취소하면 목록에서 제거한다', (tester) async {
      await pump(tester, const FriendRequestsScreen());
      await tester.tap(find.text('보낸 요청 1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('요청 취소'));
      await tester.pumpAndSettle();

      expect(find.text('초록수풀'), findsNothing);
      expect(find.text('아직 보낸 신청이 없어요'), findsOneWidget);
    });

    testWidgets('처리한 요청은 목록에서 걷힌다', (tester) async {
      await pump(tester, const FriendRequestsScreen());

      await tester.tap(find.text('함께하기').first);
      await tester.pumpAndSettle();

      expect(find.text('솔방울'), findsNothing);
      expect(find.text('받은 요청 1'), findsOneWidget);
    });

    testWidgets('거절은 조용히 처리한다', (tester) async {
      await pump(tester, const FriendRequestsScreen());

      await tester.tap(find.text('거절').first);
      await tester.pumpAndSettle();

      expect(find.text('솔방울'), findsNothing);
      // 처리 결과를 띄우면 상대에게 알린 것처럼 읽힌다.
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('모두 처리하면 빈 자리를 안내한다', (tester) async {
      await pump(tester, const FriendRequestsScreen());

      await tester.tap(find.text('함께하기').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('함께하기').first);
      await tester.pumpAndSettle();

      expect(find.text('요청을 모두 처리하면\n이 자리가 비어요'), findsOneWidget);
    });
  });

  group('S-21 동료 여정 비교', () {
    testWidgets('항목별 카드에서 두 사람의 우세와 차이를 보여준다', (tester) async {
      await pump(tester, const FriendJourneyScreen(userId: 11));

      expect(find.text('하늘님의 여정'), findsOneWidget);
      expect(find.text('여정 비교'), findsOneWidget);
      expect(find.text('레벨'), findsOneWidget);
      expect(find.text('+2Lv.'), findsOneWidget);
      expect(find.text('Lv. 12'), findsOneWidget);
      expect(find.text('Lv. 14'), findsNWidgets(2));
      expect(find.text('누적 EXP'), findsOneWidget);
      expect(find.text('업적'), findsOneWidget);
      expect(find.text('+7개'), findsOneWidget);
      expect(find.text('24개'), findsOneWidget);
      expect(find.text('31개'), findsOneWidget);
      expect(find.text('도감'), findsOneWidget);
      expect(find.text('+9개'), findsOneWidget);
      expect(find.text('42개'), findsOneWidget);
      expect(find.text('51개'), findsOneWidget);
      expect(find.text('사용 중인 칭호'), findsOneWidget);
      expect(find.text('하늘 · 새벽의 개척자'), findsOneWidget);
    });

    testWidgets('연속 달성은 서버 판정 전까지 칸째 감춘다', (tester) async {
      await pump(tester, const FriendJourneyScreen(userId: 11));

      // LqFeatures.streakEnabled가 꺼져 있는 동안은 값이 있어도 그리지 않는다.
      expect(find.text('연속 달성'), findsNothing);
      expect(find.text('14 · 9일'), findsNothing);
    });

    testWidgets('이미 응원했으면 응원 버튼이 잠긴다', (tester) async {
      await pump(tester, const FriendJourneyScreen(userId: 11));

      expect(find.text('응원함 ✓'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('오늘은 응원했어요'),
        240,
        scrollable: find.byType(Scrollable).first,
      );

      // 되돌릴 수 없는 단방향 동작이라 다시 누를 수 있으면 안 된다.
      expect(find.text('오늘은 응원했어요'), findsOneWidget);
      expect(find.text('응원 보내기'), findsNothing);
    });
  });
}

class _FakeFriendRepository extends FriendRepository {
  const _FakeFriendRepository();

  @override
  Future<String?> fetchMyCode() async => 'LQ-4821';

  @override
  Future<List<AdventurerSearchResult>> searchAdventurers(String query) async {
    const pool = [
      AdventurerSearchResult(
        userId: 2,
        nickname: '초록곰',
        level: 9,
        relation: FriendRelation.friend,
        statusLine: '이미 함께 모험 중',
      ),
      AdventurerSearchResult(
        userId: 11,
        nickname: '초록별',
        level: 6,
        relation: FriendRelation.none,
        statusLine: '칭호 · 첫 걸음',
      ),
      AdventurerSearchResult(
        userId: 12,
        nickname: '초록수풀',
        level: 21,
        relation: FriendRelation.requestSent,
        statusLine: '요청을 보냈어요 · 대기 중',
      ),
    ];
    return [
      for (final candidate in pool)
        if (candidate.nickname.contains(query)) candidate,
    ];
  }

  @override
  Future<FriendRequestBox> fetchRequests() async => const FriendRequestBox(
    received: [
      FriendRequest(
        userId: 20,
        nickname: '솔방울',
        level: 13,
        statusLine: '칭호 · 새벽의 개척자',
      ),
      FriendRequest(userId: 21, nickname: '단풍', level: 4),
    ],
    sent: [FriendRequest(userId: 12, nickname: '초록수풀', level: 21)],
  );

  @override
  Future<FriendJourney> fetchJourney(int userId) async => const FriendJourney(
    userId: 11,
    nickname: '하늘',
    titleLine: '칭호 · 새벽의 개척자',
    cheered: true,
    me: JourneySide(
      level: 12,
      lifedexCollected: 42,
      achievements: 24,
      streakDays: 14,
    ),
    friend: JourneySide(
      level: 14,
      lifedexCollected: 51,
      achievements: 31,
      streakDays: 9,
    ),
  );
}
