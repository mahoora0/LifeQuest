import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/lifedex/application/lifedex_providers.dart';
import 'package:life_quest/features/lifedex/data/lifedex_dto.dart';
import 'package:life_quest/features/lifedex/data/lifedex_repository.dart';
import 'package:life_quest/features/lifedex/presentation/lifedex_screen.dart';
import 'package:life_quest/shared/design/lq_assets.dart';
import 'package:life_quest/shared/widgets/lq_icon.dart';

/// 도감 장소 모티프의 계약을 고정한다.
///
/// 여기서 검사하는 것은 그림이 예쁜지가 아니라 **조용히 어긋나는 두 갈래**다.
/// 하나는 키와 그림 파일이 따로 노는 것(오타·미등록), 다른 하나는 항목이 모티프를
/// 갖지 않았을 때 무엇으로 물러나는가다. 둘 다 어긋나도 화면이 죽지 않고 그냥
/// 아이콘만 사라지므로, 눈으로 보지 않으면 지나간다.
void main() {
  const dir = 'assets/images/icons/lifedex/';

  group('모티프 키와 그림', () {
    test('키는 이름 규칙을 지키고 경로가 키에서 그대로 나온다', () {
      final rule = RegExp(r'^[a-z][a-z0-9_]*$');
      expect(LqLifedexIcons.keys, isNotEmpty);
      for (final key in LqLifedexIcons.keys) {
        expect(rule.hasMatch(key), isTrue, reason: '키 이름 규칙 위반: $key');
        expect(LqLifedexIcons.pathOf(key), '$dir$key.svg');
      }
    });

    test('등록된 키에는 모두 그림 파일이 있다', () {
      for (final key in LqLifedexIcons.keys) {
        final path = LqLifedexIcons.pathOf(key)!;
        expect(File(path).existsSync(), isTrue, reason: '그림이 없다: $path');
      }
    });

    test('모티프 디렉터리가 pubspec에 등록돼 있다', () {
      // 등록을 빠뜨리면 파일은 있는데 앱 번들에는 없어, 실기기에서만 아이콘이
      // 사라진다. 테스트는 파일 시스템을 보므로 그것만으로는 잡히지 않는다.
      expect(File('pubspec.yaml').readAsStringSync(), contains(dir));
    });

    test('모르는 키와 null은 경로가 없다', () {
      expect(LqLifedexIcons.pathOf('없는_키'), isNull);
      expect(LqLifedexIcons.pathOf(null), isNull);
    });
  });

  group('도감 화면', () {
    /// 도감 화면에 그려진 모티프 아이콘의 자산 경로. 뒤로 가기 같은 다른 아이콘이
    /// 섞이지 않도록 모티프 디렉터리로 걸러낸다.
    List<String> motifAssets(WidgetTester tester) => tester
        .widgetList<LqIcon>(find.byType(LqIcon))
        .map((icon) => icon.asset)
        .where((asset) => asset.startsWith(dir))
        .toList();

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lifedexRepositoryProvider.overrideWithValue(
              _FakeLifedexRepository(),
            ),
          ],
          child: const MaterialApp(home: LifedexScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('카테고리 타일은 카테고리 모티프를 그린다', (tester) async {
      await pump(tester);

      expect(motifAssets(tester), ['${dir}hanok.svg']);
    });

    testWidgets('항목은 자기 모티프를, 없으면 카테고리 모티프를 그린다', (tester) async {
      await pump(tester);
      // 칩이 아니라 그리드 안의 카테고리 타일을 눌러 항목 화면으로 들어간다.
      await tester.tap(
        find.descendant(
          of: find.byType(GridView),
          matching: find.text('시장 · 골목'),
        ),
      );
      await tester.pumpAndSettle();

      expect(motifAssets(tester), [
        '${dir}market.svg', // 자기 키가 있는 항목
        '${dir}hanok.svg', // 키가 없어 카테고리 모티프로 물러난 항목
      ]);
    });

    testWidgets('모르는 키와 미획득 항목에는 모티프를 그리지 않는다', (tester) async {
      await pump(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(GridView),
          matching: find.text('시장 · 골목'),
        ),
      );
      await tester.pumpAndSettle();

      // 그려진 모티프가 둘뿐이라는 것이 곧 나머지 둘에는 없다는 뜻이다.
      expect(motifAssets(tester), hasLength(2));
      expect(find.text('아직 못 간 시장'), findsNothing, reason: '미획득은 이름을 감춘다');
    });
  });
}

class _FakeLifedexRepository extends LifedexRepository {
  _FakeLifedexRepository() : super(Dio());

  @override
  Future<LifedexOverview> fetchOverview() async => const LifedexOverview(
    categories: [
      // 카테고리 모티프를 항목 모티프와 다른 것으로 둬야 물러남이 눈에 보인다.
      LifedexCategory(
        id: 4,
        name: '시장 · 골목',
        totalCount: 4,
        ownedCount: 3,
        iconKey: 'hanok',
      ),
    ],
  );

  @override
  Future<List<LifedexItem>> fetchItems(int categoryId) async => const [
    LifedexItem(
      id: 30,
      name: '광장시장',
      categoryId: 4,
      owned: true,
      iconKey: 'market',
    ),
    LifedexItem(id: 31, name: '키 없는 골목', categoryId: 4, owned: true),
    LifedexItem(
      id: 32,
      name: '아직 그림이 없는 유형',
      categoryId: 4,
      owned: true,
      iconKey: 'temple',
    ),
    LifedexItem(
      id: 33,
      name: '아직 못 간 시장',
      categoryId: 4,
      owned: false,
      iconKey: 'market',
    ),
  ];
}
