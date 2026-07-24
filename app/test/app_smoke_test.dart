import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:life_quest/app/life_quest_app.dart';
import 'package:life_quest/features/quest/application/quest_providers.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/data/quest_repository.dart';
import 'package:life_quest/features/user/application/user_providers.dart';
import 'package:life_quest/features/user/data/user_dto.dart';
import 'package:life_quest/features/user/data/user_repository.dart';

void main() {
  setUpAll(() {
    // 테스트에서 폰트를 내려받지 않는다(네트워크 의존 제거).
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('시안 확정 탭 구성을 표시한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questRepositoryProvider.overrideWithValue(_FakeQuestRepository()),
          userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
        ],
        child: const LifeQuestApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('홈'), findsOneWidget);
    expect(find.text('퀘스트'), findsOneWidget);
    expect(find.text('지도'), findsOneWidget);
    expect(find.text('LifeDex'), findsOneWidget);
    expect(find.text('마이'), findsOneWidget);

    // 친구 탭은 Phase 2로 미뤄 라우트를 등록하지 않는다.
    expect(find.text('친구'), findsNothing);
  });

  testWidgets('배정된 퀘스트가 없으면 빈 상태를 보여준다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questRepositoryProvider.overrideWithValue(_FakeQuestRepository()),
          userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
        ],
        child: const LifeQuestApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('오늘의 퀘스트'), findsOneWidget);
    expect(find.text('오늘 배정된 퀘스트가 없어요'), findsOneWidget);
    expect(find.text('안녕하세요, 테스터님!\n오늘도 멋진 하루가 될 거예요!'), findsOneWidget);
    expect(find.text('Lv. 3'), findsOneWidget);
  });
}

class _FakeQuestRepository extends QuestRepository {
  _FakeQuestRepository() : super(Dio());

  @override
  Future<TodayQuests> fetchToday() async =>
      const TodayQuests(assignedDate: '2026-07-24', quests: []);
}

class _FakeUserRepository extends UserRepository {
  _FakeUserRepository() : super(Dio());

  @override
  Future<UserProfile> fetchMe() async =>
      const UserProfile(id: 1, nickname: '테스터');

  @override
  Future<LevelStatus> fetchLevel() async => const LevelStatus(
    level: 3,
    totalExp: 260,
    currentLevelExp: 60,
    nextLevelRequiredExp: 200,
  );
}
