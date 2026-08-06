import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/app/life_quest_app.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 글꼴은 `ThemeData.fontFamily` 한 곳에서만 정해진다. 위젯이 개별로
/// `fontFamily`를 지정하면 테마 글꼴이 조용히 덮이므로, 토큰 스타일을 얹은
/// 텍스트에도 A2Z가 남는지 고정한다.
void main() {
  testWidgets('본문 텍스트는 번들 글꼴 A2Z로 그려진다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLifeQuestTheme(),
        home: Scaffold(
          body: Column(
            children: [
              const Text('기본 스타일'),
              Text('토큰 스타일', style: LqText.body),
            ],
          ),
        ),
      ),
    );

    for (final label in ['기본 스타일', '토큰 스타일']) {
      final text = tester.widget<Text>(find.text(label));
      final effective = DefaultTextStyle.of(
        tester.element(find.text(label)),
      ).style.merge(text.style);
      expect(effective.fontFamily, 'A2Z', reason: label);
    }
  });

  testWidgets('pubspec에 등록한 글꼴 파일이 실제로 번들된다', (tester) async {
    for (final asset in const [
      'assets/fonts/A2Z-Regular.ttf',
      'assets/fonts/A2Z-Medium.ttf',
      'assets/fonts/A2Z-Bold.ttf',
    ]) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0), reason: asset);
    }
  });

  test('타이포 토큰은 글꼴을 직접 지정하지 않는다', () {
    const styles = <TextStyle>[
      LqText.displayTitle,
      LqText.bigTitle,
      LqText.levelNumber,
      LqText.sectionTitle,
      LqText.screenTitle,
      LqText.cardTitle,
      LqText.body,
      LqText.bodySm,
      LqText.label,
      LqText.caption,
      LqText.badge,
      LqText.tabLabel,
    ];
    for (final style in styles) {
      expect(style.fontFamily, isNull);
    }
  });
}
