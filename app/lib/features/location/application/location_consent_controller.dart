import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:life_quest/core/location/location_service.dart';
import 'package:life_quest/core/storage/local_preferences.dart';

/// 위치 권한 안내가 지금 어느 단계에 있는지 (시안 "화면 구성 규칙" §11).
enum LocationConsentStage {
  /// 권한 상태를 아직 읽지 못했다. 아무것도 띄우지 않는다 —
  /// 판단이 서기 전에 안내부터 띄우면 이미 허용한 사람에게도 보인다.
  unknown,

  /// 1단계. 전면 안내를 띄운다.
  intro,

  /// 미루는 중. 2단계(배너·시트)만 동작한다.
  deferred,

  /// 권한이 있다. 두 단계 모두 영구히 사라진다.
  granted,

  /// OS가 영구 거부로 굳혔다. 같은 버튼으로 다시 요청해도 팝업이 뜨지 않으므로
  /// 시트의 CTA를 "설정에서 켜기"로 바꾼다.
  blocked;

  /// 홈 배너를 띄울 단계인지.
  bool get needsBanner =>
      this == LocationConsentStage.deferred ||
      this == LocationConsentStage.blocked;

  /// 위치 퀘스트를 열 때 시트를 올려야 하는 단계인지.
  bool get needsSheet =>
      this != LocationConsentStage.granted &&
      this != LocationConsentStage.unknown;
}

/// 권한 안내의 단계 판정과 "미룬 날짜" 보관.
final locationConsentProvider =
    AsyncNotifierProvider<LocationConsentNotifier, LocationConsentStage>(
      LocationConsentNotifier.new,
    );

class LocationConsentNotifier extends AsyncNotifier<LocationConsentStage> {
  /// 미룬 날짜(`yyyy-MM-dd`). 기기별 권한 상태라 계정을 따라다닐 값이 아니다.
  static const _deferKey = 'location.consent.deferredOn';

  @override
  Future<LocationConsentStage> build() async {
    try {
      return await _resolve();
    } on Object {
      // 위치 플러그인이 없는 환경(테스트·데스크톱)에서도 앱이 죽지 않아야 한다.
      // 판정을 못 하면 아무것도 띄우지 않는다.
      return LocationConsentStage.unknown;
    }
  }

  Future<LocationConsentStage> _resolve() async {
    final permission = await ref
        .read(locationServiceProvider)
        .checkPermission();

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      // 허용하면 두 단계 모두 영구히 사라진다. 미룬 기록도 함께 걷는다 —
      // 남겨 두면 나중에 권한을 껐을 때 엉뚱한 날짜로 판정된다.
      final prefs = await ref.read(sharedPreferencesProvider.future);
      await prefs.remove(_deferKey);
      return LocationConsentStage.granted;
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationConsentStage.blocked;
    }

    final prefs = await ref.read(sharedPreferencesProvider.future);
    return prefs.getString(_deferKey) == todayKey()
        ? LocationConsentStage.deferred
        : LocationConsentStage.intro;
  }

  /// "나중에 할게요" · "지금은 넘어가기".
  ///
  /// 이미 영구 거부로 굳은 상태는 낮추지 않는다. `deferred`로 내리면 다음 시트가
  /// "위치 권한 허용하기"를 보여주는데, 그 버튼은 OS 팝업을 띄우지 못해 눌러도
  /// 아무 일이 없다 — 상태를 되돌릴 유일한 경로("설정에서 켜기")를 잃는 셈이다.
  Future<void> defer() async {
    await _rememberDeferredToday();
    if (state.value == LocationConsentStage.blocked) return;
    state = const AsyncData(LocationConsentStage.deferred);
  }

  Future<void> _rememberDeferredToday() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(_deferKey, todayKey());
  }

  /// OS 권한 팝업을 띄운다. 설명을 보여준 뒤에만 부른다 —
  /// 설명 없이 먼저 띄우면 영구 거부로 굳어 되돌릴 방법이 설정 앱뿐이 된다.
  ///
  /// 허용됐으면 `true`.
  Future<bool> request() async {
    final service = ref.read(locationServiceProvider);
    final permission = await service.requestPermission();

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      await prefs.remove(_deferKey);
      state = const AsyncData(LocationConsentStage.granted);
      return true;
    }

    // 거절도 미룬 것으로 기록한다. 남기지 않으면 다음 실행에서 `intro`로 판정돼
    // 전면 안내가 매번 다시 뜬다 — "나중에 할게요"로 부드럽게 넘긴 사람은 하루
    // 쉬는데 OS 팝업까지 눌러 거절한 사람이 더 자주 시달리는 뒤집힌 결과가 된다.
    await _rememberDeferredToday();

    state = AsyncData(
      permission == LocationPermission.deniedForever
          ? LocationConsentStage.blocked
          : LocationConsentStage.deferred,
    );
    return false;
  }

  /// 영구 거부 복구용 — 앱 설정 화면을 연다.
  Future<void> openSettings() =>
      ref.read(locationServiceProvider).openAppSettings();

  /// 날짜 경계로 센다. 시각을 쓰면 밤에 미룬 사람의 재노출 시점이 한밤중이 된다.
  ///
  /// 마이페이지 "최근 획득"의 날짜 계산과 같은 규칙이다(시안 §11-③).
  ///
  // TODO(design): 이 규칙이면 밤 11시에 미룬 사람이 자정을 넘겨 앱을 다시 켰을 때
  //  안내를 한 번 더 보게 된다. 시안 §11-③은 그 경우를 막겠다고 적었지만 같은 항목이
  //  지정한 계산 방식(날짜 경계)으로는 막히지 않는다 — 두 문장이 어긋난다.
  //  전면 안내를 앱 실행당 한 번으로 묶어 실사용에서의 빈도는 낮췄다.
  //  "미룬 뒤 최소 N시간"을 더할지 결정 필요.
  static String todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}

/// 전면 안내를 이번 실행에서 이미 띄웠는지.
///
/// 시안 §11-②는 "다음 **실행** 때 한 번 더"라고 적었다. 홈으로 돌아올 때마다
/// 다시 띄우면 재촉으로 읽힌다.
final locationIntroShownProvider =
    NotifierProvider<LocationIntroShownNotifier, bool>(
      LocationIntroShownNotifier.new,
    );

class LocationIntroShownNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markShown() => state = true;
}
