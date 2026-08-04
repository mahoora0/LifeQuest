import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:life_quest/features/achievement/application/achievement_providers.dart';
import 'package:life_quest/features/achievement/data/achievement_dto.dart';
import 'package:life_quest/features/achievement/presentation/achievement_screen.dart';

/// 업적 화면은 업적과 칭호만 제공한다.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('업적·칭호 두 탭만 제공한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          achievementOverviewProvider.overrideWith(
            (ref) async => const AchievementOverview(achievements: []),
          ),
        ],
        child: const MaterialApp(home: AchievementScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('업적'), findsOneWidget);
    expect(find.text('칭호'), findsOneWidget);
    expect(find.text('배지'), findsNothing);
  });
}
