import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:life_quest/app/router/app_router.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

class LifeQuestApp extends ConsumerWidget {
  const LifeQuestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Life Quest',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      routerConfig: router,
    );
  }
}

/// 시안은 손글씨 글꼴 Gaegu 전용이다. `textTheme` 전체에 적용해
/// 개별 위젯이 `fontFamily`를 지정하지 않아도 되게 한다.
ThemeData _buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: LqColors.surfacePanel,
    colorScheme: ColorScheme.fromSeed(
      seedColor: LqColors.primary,
      surface: LqColors.surfacePanel,
    ),
  );

  return base.copyWith(
    textTheme: GoogleFonts.gaeguTextTheme(base.textTheme).apply(
      bodyColor: LqColors.textPrimary,
      displayColor: LqColors.textPrimary,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
