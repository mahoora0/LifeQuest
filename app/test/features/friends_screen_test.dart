import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/friends/application/friend_providers.dart';
import 'package:life_quest/features/friends/data/friend_dto.dart';
import 'package:life_quest/features/friends/data/friend_repository.dart';
import 'package:life_quest/features/friends/presentation/friends_screen.dart';

/// 친구 화면(S-18~22)은 세그먼트 두 개로 목록과 주간 랭킹을 오간다.
/// 순위 요약은 숫자와 모수의 크기가 달라 `Text.rich`로 그린다.
/// `find.text`는 `Text.data`만 보므로 합성된 평문으로 찾는다.
Finder findComposedText(String text) => find.byWidgetPredicate(
  (widget) =>
      widget is Text && (widget.data ?? widget.textSpan?.toPlainText()) == text,
);

void main() {
  Future<void> pumpFriends(
    WidgetTester tester, {
    FriendRepository repository = const _FakeFriendRepository(),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [friendRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: FriendsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('진입 시 친구 목록 세그먼트를 보여준다', (tester) async {
    await pumpFriends(tester);

    expect(find.text('친구'), findsOneWidget);
    expect(find.text('친구 목록'), findsOneWidget);
    expect(find.text('이번 주 랭킹'), findsOneWidget);

    expect(find.text('친구 2명이 오늘도 모험 중!\n응원하면 서로 EXP 5!'), findsOneWidget);
    expect(find.text('민서'), findsOneWidget);
    expect(find.text('Lv.7'), findsOneWidget);
    expect(find.text('오늘 퀘스트 2 / 3 진행 중'), findsOneWidget);
    expect(find.text('내 코드 · LQ-4821'), findsOneWidget);
  });

  testWidgets('응원하면 되돌릴 수 없는 완료 표시로 바뀐다', (tester) async {
    await pumpFriends(tester);

    // 준호는 이미 응원한 상태라 민서 쪽 버튼 하나만 "응원"으로 남아 있다.
    expect(find.text('응원'), findsOneWidget);
    expect(find.text('응원함 ✓'), findsOneWidget);

    await tester.tap(find.text('응원'));
    await tester.pumpAndSettle();

    expect(find.text('응원'), findsNothing);
    expect(find.text('응원함 ✓'), findsNWidgets(2));

    // 응원에 EXP 보상이 걸려 있어 다시 눌러도 해제되지 않아야 한다.
    await tester.tap(find.text('응원함 ✓').first);
    await tester.pumpAndSettle();
    expect(find.text('응원함 ✓'), findsNWidgets(2));
  });

  testWidgets('랭킹 세그먼트는 내 순위와 등락을 보여준다', (tester) async {
    await pumpFriends(tester);

    await tester.tap(find.text('이번 주 랭킹'));
    await tester.pumpAndSettle();

    expect(find.text('이번 주 내 순위'), findsOneWidget);
    expect(findComposedText('2위 / 친구 2명 중'), findsOneWidget);
    expect(find.text('↑ 1'), findsOneWidget);
    expect(find.text('EXP 305'), findsOneWidget);
    expect(find.text('랭킹은 매주 월요일 0시에 초기화돼요'), findsOneWidget);
  });

  testWidgets('친구가 없어도 코드 카드는 남아 추가 경로를 잃지 않는다', (tester) async {
    await pumpFriends(tester, repository: const _EmptyFriendRepository());

    expect(find.text('아직 친구가 없어요.\n친구 코드를 나누고 함께 모험해요!'), findsOneWidget);
    // 빈 상태 화면으로 갈아끼우면 친구를 추가할 방법이 사라진다.
    expect(find.text('친구 코드로 추가'), findsOneWidget);
    expect(find.text('내 코드 · LQ-4821'), findsOneWidget);
  });

  testWidgets('지난주 집계가 없으면 등락을 만들어내지 않는다', (tester) async {
    await pumpFriends(tester, repository: const _NoDeltaFriendRepository());

    await tester.tap(find.text('이번 주 랭킹'));
    await tester.pumpAndSettle();

    expect(findComposedText('1위 / 친구 1명 중'), findsOneWidget);
    expect(find.textContaining('↑'), findsNothing);
    expect(find.textContaining('↓'), findsNothing);
  });
}

class _FakeFriendRepository extends FriendRepository {
  const _FakeFriendRepository();

  @override
  Future<FriendList> fetchFriends() async => const FriendList(
    myCode: 'LQ-4821',
    friends: [
      Friend(
        userId: 11,
        nickname: '민서',
        level: 7,
        statusLine: '오늘 퀘스트 2 / 3 진행 중',
      ),
      Friend(userId: 12, nickname: '준호', level: 5, cheered: true),
    ],
  );

  @override
  Future<WeeklyRanking> fetchWeeklyRanking() async => const WeeklyRanking(
    rankDelta: 1,
    entries: [
      RankEntry(rank: 1, userId: 11, nickname: '민서', weeklyExp: 380),
      RankEntry(rank: 2, userId: 1, nickname: '나', weeklyExp: 305, isMe: true),
      RankEntry(rank: 3, userId: 12, nickname: '준호', weeklyExp: 260),
    ],
  );
}

class _EmptyFriendRepository extends FriendRepository {
  const _EmptyFriendRepository();

  @override
  Future<FriendList> fetchFriends() async =>
      const FriendList(friends: [], myCode: 'LQ-4821');
}

class _NoDeltaFriendRepository extends FriendRepository {
  const _NoDeltaFriendRepository();

  @override
  Future<WeeklyRanking> fetchWeeklyRanking() async => const WeeklyRanking(
    entries: [
      RankEntry(rank: 1, userId: 1, nickname: '나', weeklyExp: 305, isMe: true),
      RankEntry(rank: 2, userId: 12, nickname: '준호', weeklyExp: 260),
    ],
  );
}
