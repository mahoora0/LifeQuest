import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      theme: buildLifeQuestTheme(),
      routerConfig: router,
    );
  }
}

/// 본문 글꼴은 에이투지체(A2Z) 전용이다. `textTheme` 전체에 적용해
/// 개별 위젯이 `fontFamily`를 지정하지 않아도 되게 한다.
ThemeData buildLifeQuestTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'A2Z',
    scaffoldBackgroundColor: LqColors.surfacePanel,
    colorScheme: ColorScheme.fromSeed(
      seedColor: LqColors.primary,
      surface: LqColors.surfacePanel,
    ),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: LqColors.textPrimary,
      displayColor: LqColors.textPrimary,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
