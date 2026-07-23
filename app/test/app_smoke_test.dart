import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/app/life_quest_app.dart';

void main() {
  testWidgets('기본 내비게이션을 표시한다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LifeQuestApp()));
    await tester.pumpAndSettle();

    expect(find.text('오늘의 퀘스트'), findsWidgets);
    expect(find.text('지도'), findsOneWidget);
    expect(find.text('도감'), findsOneWidget);
    expect(find.text('친구'), findsOneWidget);
    expect(find.text('마이'), findsOneWidget);
  });
}
