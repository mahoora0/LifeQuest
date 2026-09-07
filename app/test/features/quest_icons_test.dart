import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/proof/data/proof_dto.dart';
import 'package:life_quest/features/quest/data/quest_dto.dart';
import 'package:life_quest/features/quest/presentation/widgets/quest_rows.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/widgets/lq_chip.dart';
import 'package:life_quest/shared/widgets/lq_icon.dart';

/// 퀘스트 카테고리 아이콘의 계약을 고정한다.
///
/// 도감 모티프와 같은 이유로 눈에 안 띄는 실패만 검사한다 — 아이콘이 어긋나도
/// 화면은 죽지 않고 그림만 사라지므로, 실기기를 들여다보지 않으면 지나간다.
/// 여기서 막는 것은 넷이다. 키와 파일이 따로 노는 것, `quests.category`가
/// 그림 없는 값을 갖는 것, wire 값(대문자)과 파일명(소문자)의 표기 차이,
/// 그리고 주제를 모를 때 무엇으로 물러나는가다.
void main() {
  const dir = 'assets/images/icons/quest/';

  group('카테고리 키와 그림', () {
    test('키는 이름 규칙을 지키고 경로가 키에서 그대로 나온다', () {
      final rule = RegExp(r'^[a-z][a-z0-9_]*$');
      expect(LqQuestIcons.keys, isNotEmpty);
      for (final key in LqQuestIcons.keys) {
        expect(rule.hasMatch(key), isTrue, reason: '키 이름 규칙 위반: $key');
        expect(LqQuestIcons.pathOf(key), '$dir$key.svg');
      }
    });

    test('등록된 키에는 모두 그림 파일이 있다', () {
      for (final key in LqQuestIcons.keys) {
        final path = LqQuestIcons.pathOf(key)!;
        expect(File(path).existsSync(), isTrue, reason: '그림이 없다: $path');
      }
    });

    test('그림 파일은 모두 SVG로 읽힌다', () async {
      // 손으로 그린 path라 좌표 개수 하나만 틀려도 파서가 조용히 빈 그림을
      // 돌려준다. 경로만 맞추는 검사로는 그 실패가 잡히지 않는다.
      for (final key in LqQuestIcons.keys) {
        final path = LqQuestIcons.pathOf(key)!;
        final source = File(path).readAsStringSync();
        final picture = await vg.loadPicture(SvgStringLoader(source), null);
        addTearDown(picture.picture.dispose);
        expect(picture.size.width, 24, reason: '규격이 24 그리드가 아니다: $path');
        expect(picture.size.height, 24, reason: '규격이 24 그리드가 아니다: $path');
      }
    });

    test('아이콘 디렉터리가 pubspec에 등록돼 있다', () {
      // 등록을 빠뜨리면 파일은 있는데 앱 번들에는 없어, 실기기에서만 아이콘이
      // 사라진다. 테스트는 파일 시스템을 보므로 그것만으로는 잡히지 않는다.
      expect(File('pubspec.yaml').readAsStringSync(), contains(dir));
    });

    test('서버가 보내는 카테고리는 모두 그림을 갖는다', () {
      // 카테고리는 DB CHECK 제약으로 닫혀 있으므로 빈 칸이 남으면 안 된다.
      // 카테고리가 늘어나면 이 테스트가 먼저 깨지는 것이 의도다.
      for (final category in ProofQuestCategory.values) {
        expect(
          LqQuestIcons.pathOf(category.wire),
          isNotNull,
          reason: '그림 없는 카테고리: ${category.wire}',
        );
      }
    });

    test('wire 값은 대문자 그대로 넘겨도 찾는다', () {
      // 서버는 HEALTH_FITNESS로 보내고 파일명은 health_fitness다. 호출부가
      // 표기를 맞추게 두면 한 곳만 빠뜨려도 그 칩만 조용히 아이콘을 잃는다.
      expect(LqQuestIcons.pathOf('HEALTH_FITNESS'), '${dir}health_fitness.svg');
    });

    test('모르는 카테고리와 null은 경로가 없다', () {
      expect(LqQuestIcons.pathOf('MEDITATION'), isNull);
      expect(LqQuestIcons.pathOf(null), isNull);
    });
  });

  group('필터 칩', () {
    testWidgets('아이콘을 준 칩에만 그림이 붙는다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LqChipRow(
              labels: const ['모든 주제', '건강·운동'],
              icons: [null, LqQuestIcons.pathOf('HEALTH_FITNESS')],
              selectedIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      final icons = tester.widgetList<LqIcon>(find.byType(LqIcon)).toList();
      expect(icons, hasLength(1), reason: '"모든 주제"는 카테고리가 아니라 해제 버튼이다');
      expect(icons.single.asset, '${dir}health_fitness.svg');
    });

    test('아이콘 목록이 라벨보다 짧으면 만들어지지 않는다', () {
      // 길이가 어긋나면 뒤쪽 칩만 아이콘을 잃어 화면에서 알아채기 어렵다.
      expect(
        () => LqChipRow(
          labels: const ['하나', '둘'],
          icons: const [null],
          selectedIndex: 0,
          onSelected: (_) {},
        ),
        throwsAssertionError,
      );
    });
  });

  group('퀘스트 목록 행', () {
    DailyQuest daily(String? category) => DailyQuest(
      dailyQuestId: 1,
      status: DailyQuestStatus.assigned,
      quest: Quest(
        id: 1,
        title: '물 여덟 잔 마시기',
        category: category,
        completionType: QuestCompletionType.selfReport,
        expReward: 20,
      ),
    );

    Future<void> pump(WidgetTester tester, String? category) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: QuestListRow(dailyQuest: daily(category), onTap: () {}),
            ),
          ),
        );

    testWidgets('대표 주제가 있으면 그 아이콘을 그린다', (tester) async {
      await pump(tester, 'DAILY_HABIT');

      expect(
        tester.widget<LqIcon>(find.byType(LqIcon)).asset,
        '${dir}daily_habit.svg',
      );
      expect(find.text('물'), findsNothing, reason: '아이콘이 첫 글자를 대신한다');
    });

    testWidgets('주제가 없으면 지금처럼 제목 첫 글자를 그린다', (tester) async {
      // `category`를 아직 싣지 않는 서버와도 목록이 성립해야 한다.
      await pump(tester, null);

      expect(find.byType(LqIcon), findsNothing);
      expect(find.text('물'), findsOneWidget);
    });

    testWidgets('모르는 주제도 첫 글자로 물러난다', (tester) async {
      // 그림 없는 값을 ETC로 접으면 "기타 퀘스트"와 구분이 사라진다.
      await pump(tester, 'MEDITATION');

      expect(find.byType(LqIcon), findsNothing);
      expect(find.text('물'), findsOneWidget);
    });
  });

  group('퀘스트 응답 파싱', () {
    test('category를 중첩·평탄화 어느 쪽에서도 읽는다', () {
      // `GET /quests/today`는 요약을 중첩으로, 다른 응답은 평탄화해서 준다.
      expect(
        DailyQuest.fromJson(const {
          'dailyQuestId': 7,
          'status': 'ASSIGNED',
          'quest': {'questId': 3, 'title': '산책', 'category': 'NATURE_OUTDOOR'},
        }).quest.category,
        'NATURE_OUTDOOR',
      );
      expect(
        Quest.fromJson(const {
          'questId': 3,
          'questCategory': 'FOOD_CAFE',
        }).category,
        'FOOD_CAFE',
      );
    });
  });
}
