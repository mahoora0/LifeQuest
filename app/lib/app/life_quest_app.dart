import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
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
    // 화면 전환은 플랫폼 기본을 그대로 쓴다. 값은 Flutter 기본과 같지만 적어 두는
    // 이유는 **의도적인 선택**이기 때문이다.
    //
    // 한 번 앱 전체를 커스텀 전환(`CustomTransitionPage`)으로 옮겼다가 되돌렸다.
    // 그 경로는 `PageTransitionsTheme`을 우회해서 iOS 가장자리 스와이프 뒤로가기와
    // Android predictive back을 잃는다. 전환 모양의 통일보다 플랫폼 네비게이션
    // 관습이 우선이다.
    //
    // Android 기본 `PredictiveBackPageTransitionsBuilder`는 제스처가 없을 때
    // `FadeForwardsPageTransitionsBuilder`(가로 25% 슬라이드 + 페이드, 450ms)로
    // 떨어진다. 우리가 손으로 만들었던 2% 슬라이드보다 이쪽이 훨씬 낫다.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
