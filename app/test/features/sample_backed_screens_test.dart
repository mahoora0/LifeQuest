import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:life_quest/features/achievement/application/achievement_providers.dart';
import 'package:life_quest/features/achievement/data/achievement_repository.dart';
import 'package:life_quest/features/achievement/presentation/achievement_screen.dart';
import 'package:life_quest/features/lifedex/application/lifedex_providers.dart';
import 'package:life_quest/features/lifedex/data/lifedex_repository.dart';
import 'package:life_quest/features/lifedex/presentation/lifedex_screen.dart';

/// 백엔드에 컨트롤러가 없는 도감·업적은 404를 받아 표본으로 떨어진다.
///
/// 화면을 검토·시연할 수 있게 하는 것이 목적이므로, "준비 중"이 아니라 실제 내용이
/// 그려지는지를 본다. 서버가 열리면 표본은 저절로 물러난다(`sample_data_test.dart`).
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// 어디에도 닿지 않는 Dio — 붙지 않은 서버를 흉내 낸다.
  Dio unreachableDio() {
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1/api'));
    dio.httpClientAdapter = IOHttpClientAdapter();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: 404,
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
      ),
    );
    return dio;
  }

  testWidgets('도감은 컨트롤러가 없어도 카테고리와 수집률을 보여준다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lifedexRepositoryProvider.overrideWithValue(
            LifedexRepository(unreachableDio()),
          ),
        ],
        child: const MaterialApp(home: LifedexScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('도감은 아직 준비 중이에요'), findsNothing);
    // 카테고리는 필터 칩과 격자 타일 양쪽에 나온다.
    expect(find.text('카페'), findsWidgets);
    expect(find.text('공원 · 산책로'), findsWidgets);
    // 12+11+7+8+4 = 42, 24+20+18+22+16 = 100 → 시안의 42%를 재현한다.
    expect(find.textContaining('42'), findsWidgets);
  });

  testWidgets('업적은 컨트롤러가 없어도 달성·진행 중을 함께 보여준다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          achievementRepositoryProvider.overrideWithValue(
            AchievementRepository(unreachableDio()),
          ),
        ],
        child: const MaterialApp(home: AchievementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('업적 목록은 아직 준비 중이에요'), findsNothing);
    expect(find.text('첫 걸음'), findsOneWidget);
    expect(find.text('꾸준한 모험가'), findsOneWidget);
  });

  testWidgets('미달성 비밀 업적은 표본에서도 마스킹된 채로 온다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          achievementRepositoryProvider.overrideWithValue(
            AchievementRepository(unreachableDio()),
          ),
        ],
        child: const MaterialApp(home: AchievementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // 비밀 업적은 목록 아래쪽이라 필터로 좁혀야 화면에 올라온다.
    await tester.tap(find.text('비밀'));
    await tester.pumpAndSettle();

    // 표본에 실제 이름을 적어 두면 마스킹 처리 경로가 화면에서 검증되지 않는다.
    // 화면은 빈 이름을 "비밀 업적"으로 대체한다.
    expect(find.text('비밀 업적'), findsOneWidget);
    // 해금된 비밀 업적은 이름이 드러나야 한다.
    expect(find.text('야행성 탐험가'), findsOneWidget);
  });
}
