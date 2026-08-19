import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:life_quest/core/config/app_config.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

/// 지도 SDK를 감싸는 유일한 파일.
///
/// `05-business-rules.md` §3-4가 지도 표시 SDK를 애플리케이션 코드와 분리하도록
/// 정했다. 그래서 화면 코드는 SDK의 타입(`NLatLng`·`NMarker`·`NaverMapController`)을
/// 알지 못하고 [LqLatLng]·[LqMapMarker]만 다룬다. 제공자를 바꾸면 이 파일 하나가
/// 바뀐다.
///
/// **키가 없으면 지도를 초기화하지 않는다.** `flutter test`와 CI의 `build apk`는
/// `NAVER_MAP_CLIENT_ID`를 주입하지 않으므로 그쪽에서는 [LqMap.fallback]이 그려진다.
/// 지도가 없는 것은 오류 상태가 아니라 정상 경로 중 하나다.

/// 지도 좌표. SDK 타입이 화면 코드로 새지 않게 하는 경계다.
@immutable
class LqLatLng {
  const LqLatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is LqLatLng &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// 지도 위의 한 지점.
@immutable
class LqMapMarker {
  const LqMapMarker({
    required this.id,
    required this.position,
    this.label,
    this.color = LqColors.primary,
    this.selected = false,
    this.onTap,
  });

  /// 오버레이 식별자. 같은 지도 안에서 유일해야 한다.
  final String id;
  final LqLatLng position;

  /// 마커 아래 표시할 짧은 이름. 길면 지도가 글자로 덮인다.
  final String? label;

  /// 핀 색. 등급 색을 그대로 넘기면 목록과 지도가 같은 언어를 쓴다.
  final Color color;

  /// 선택된 마커는 한 단계 크게 그린다.
  final bool selected;

  final VoidCallback? onTap;
}

/// 인증 반경처럼 "이 안에 들어와야 한다"를 나타내는 원.
@immutable
class LqMapCircle {
  const LqMapCircle({
    required this.center,
    required this.radiusM,
    this.satisfied = false,
  });

  final LqLatLng center;
  final double radiusM;

  /// 조건이 충족된 상태(반경 안)면 색이 바뀐다.
  final bool satisfied;

  /// 원이 차지하는 사각형의 네 귀퉁이. 카메라가 반경 전체를 담는 데 쓴다.
  ///
  /// 위도 1도는 어디서나 약 111km이고, 경도 1도는 위도가 높을수록 짧아지므로
  /// `cos(위도)`로 줄인다. 카메라 여유를 잡는 용도라 이 근사로 충분하다.
  List<LqLatLng> get bounds {
    final dLat = radiusM / 111320;
    final dLng =
        radiusM / (111320 * math.cos(center.latitude * math.pi / 180).abs());
    return [
      LqLatLng(center.latitude - dLat, center.longitude - dLng),
      LqLatLng(center.latitude + dLat, center.longitude + dLng),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is LqMapCircle &&
      other.center == center &&
      other.radiusM == radiusM &&
      other.satisfied == satisfied;

  @override
  int get hashCode => Object.hash(center, radiusM, satisfied);
}

/// 카메라를 무엇에 맞출지.
enum LqMapFocus {
  /// 마커와 내 위치가 모두 보이도록 맞춘다.
  fitAll,

  /// 사용자가 움직인 카메라를 그대로 둔다.
  manual,
}

/// 지도. 키가 없거나 초기화에 실패하면 [fallback]을 그린다.
class LqMap extends StatefulWidget {
  const LqMap({
    super.key,
    required this.height,
    required this.fallback,
    this.markers = const [],
    this.circle,
    this.myLocation,
    this.focus = LqMapFocus.fitAll,
    this.focusToken = 0,
    this.interactive = true,
    this.onTap,
  });

  final double height;

  /// 지도를 그릴 수 없을 때 대신 그릴 위젯.
  final Widget fallback;

  final List<LqMapMarker> markers;
  final LqMapCircle? circle;

  /// 내 위치. 앱이 직접 넘긴다 — SDK에 위치 추적을 맡기지 않는다.
  final LqLatLng? myLocation;

  final LqMapFocus focus;

  /// 값이 바뀌면 카메라를 다시 맞춘다. 사용자가 지도를 옮긴 뒤 "내 위치"로 되돌릴
  /// 때 쓴다 — 데이터가 그대로면 [didUpdateWidget]이 카메라를 건드리지 않으므로,
  /// 되돌리기에는 별도의 신호가 필요하다.
  final int focusToken;

  /// 스크롤 뷰 안에서 제스처를 지도가 가져갈지. 인증 화면처럼 프레임이 고정된
  /// 곳에서는 `false`로 두어 화면 스크롤을 방해하지 않는다.
  final bool interactive;

  /// 지도 빈 곳을 탭했을 때. 마커 선택을 해제하는 데 쓴다.
  final VoidCallback? onTap;

  @override
  State<LqMap> createState() => _LqMapState();
}

class _LqMapState extends State<LqMap> {
  /// SDK 초기화는 앱 전체에서 한 번이면 된다. 지도가 두 화면에 있으므로
  /// 인스턴스마다 초기화하면 두 번째 화면에서 채널 호출이 중복된다.
  static Future<bool>? _sdkReady;

  /// 핀 이미지는 색마다 하나씩만 만든다. 마커 수가 아니라 등급 수만큼 렌더링된다.
  static final Map<int, NOverlayImage> _pinCache = {};

  NaverMapController? _controller;
  Future<bool>? _ready;

  /// 인증 실패는 초기화 성공 뒤에 비동기로 온다 — 그때 대체 화면으로 내린다.
  bool _authFailed = false;

  @override
  void initState() {
    super.initState();
    if (AppConfig.isMapEnabled) _ready = _initializeSdk();
  }

  Future<bool> _initializeSdk() {
    return _sdkReady ??= FlutterNaverMap()
        .init(
          clientId: AppConfig.naverMapClientId,
          onAuthFailed: (_) {
            // 키가 틀렸거나 패키지 이름이 콘솔 등록값과 다르면 여기로 온다.
            // 지도 자리를 빈 채로 두지 않고 대체 화면으로 되돌린다.
            if (mounted) setState(() => _authFailed = true);
          },
        )
        .then((_) => true)
        .catchError((_) => false);
  }

  @override
  void didUpdateWidget(LqMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller == null) return;

    final markersChanged = !_sameMarkers(oldWidget.markers, widget.markers);
    if (markersChanged || oldWidget.circle != widget.circle) {
      _applyOverlays();
    }
    if (oldWidget.myLocation != widget.myLocation) {
      _applyMyLocation();
    }
    if (markersChanged ||
        oldWidget.myLocation != widget.myLocation ||
        oldWidget.focusToken != widget.focusToken) {
      _applyCamera();
    }
  }

  bool _sameMarkers(List<LqMapMarker> a, List<LqMapMarker> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].position != b[i].position ||
          a[i].selected != b[i].selected) {
        return false;
      }
    }
    return true;
  }

  Future<void> _onMapReady(NaverMapController controller) async {
    _controller = controller;
    await _applyOverlays();
    _applyMyLocation();
    await _applyCamera();
  }

  Future<void> _applyOverlays() async {
    final controller = _controller;
    if (controller == null) return;

    await controller.clearOverlays(type: NOverlayType.marker);
    await controller.clearOverlays(type: NOverlayType.circleOverlay);

    final circle = widget.circle;
    if (circle != null) {
      final tone = circle.satisfied ? LqColors.primary : LqColors.accent;
      await controller.addOverlay(
        NCircleOverlay(
          id: 'lq-radius',
          center: NLatLng(circle.center.latitude, circle.center.longitude),
          radius: circle.radiusM,
          color: tone.withValues(alpha: 0.16),
          outlineColor: tone,
          outlineWidth: 2,
        ),
      );
    }

    for (final marker in widget.markers) {
      final overlay = NMarker(
        id: marker.id,
        position: NLatLng(marker.position.latitude, marker.position.longitude),
        icon: await _pinImage(marker.color, selected: marker.selected),
        size: marker.selected ? const Size(40, 50) : const Size(32, 40),
        caption: marker.label == null
            ? null
            : NOverlayCaption(
                text: marker.label!,
                color: LqColors.textPrimary,
                haloColor: LqColors.surfaceRaised,
                textSize: 11,
              ),
      );
      final onTap = marker.onTap;
      if (onTap != null) overlay.setOnTapListener((_) => onTap());
      await controller.addOverlay(overlay);
    }
  }

  /// 핀은 이미지가 아니라 벡터로 그린다 — `fromWidget`은 내부 이미지 위젯에서
  /// 로드 실패가 나므로 패키지 문서가 쓰지 말라고 명시한다.
  Future<NOverlayImage> _pinImage(Color color, {required bool selected}) async {
    final key = Object.hash(color.toARGB32(), selected);
    final cached = _pinCache[key];
    if (cached != null) return cached;

    final image = await NOverlayImage.fromWidget(
      widget: _MapPin(color: color, selected: selected),
      size: const Size(32, 40),
      context: context,
    );
    return _pinCache[key] = image;
  }

  void _applyMyLocation() {
    final controller = _controller;
    final position = widget.myLocation;
    if (controller == null) return;

    final overlay = controller.getLocationOverlay();
    if (position == null) {
      overlay.setIsVisible(false);
      return;
    }

    // 위치 추적 모드를 켜지 않는다. 켜면 SDK가 스스로 위치를 요청해 권한 팝업이
    // 앱의 안내와 별개로 한 번 더 뜬다. 좌표는 앱이 이미 갖고 있다.
    overlay.setIsVisible(true);
    overlay.setPosition(NLatLng(position.latitude, position.longitude));
    overlay.setCircleColor(LqColors.primary.withValues(alpha: 0.18));
  }

  Future<void> _applyCamera() async {
    final controller = _controller;
    if (controller == null || widget.focus != LqMapFocus.fitAll) return;

    final circle = widget.circle;
    final points = <NLatLng>[
      for (final marker in widget.markers)
        NLatLng(marker.position.latitude, marker.position.longitude),
      if (widget.myLocation != null)
        NLatLng(widget.myLocation!.latitude, widget.myLocation!.longitude),
      // 반경 원은 이 화면이 보여주려는 것 자체다. 중심만 담으면 원의 테두리가
      // 프레임 밖으로 나가 "반경 안에 있는가"를 눈으로 판단할 수 없다.
      if (circle != null)
        for (final corner in circle.bounds)
          NLatLng(corner.latitude, corner.longitude),
    ];
    if (points.isEmpty) return;

    // 한 점만 있으면 bounds의 넓이가 0이라 최대 줌까지 당겨진다.
    if (points.length == 1) {
      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: points.first, zoom: 15),
      );
      return;
    }

    await controller.updateCamera(
      NCameraUpdate.fitBounds(
        NLatLngBounds.from(points),
        padding: const EdgeInsets.all(56),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isMapEnabled || _authFailed) {
      return SizedBox(height: widget.height, child: widget.fallback);
    }

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: LqShape.cardRadius,
        child: FutureBuilder<bool>(
          future: _ready,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _MapLoading();
            }
            if (snapshot.data != true) return widget.fallback;
            return _buildMap();
          },
        ),
      ),
    );
  }

  Widget _buildMap() {
    final first =
        widget.myLocation ??
        (widget.markers.isEmpty ? null : widget.markers.first.position);

    return NaverMap(
      // 두 화면 모두 ListView 안이라 제스처를 명시적으로 넘겨야 지도가 받는다.
      forceGesture: widget.interactive,
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: first == null
              ? const NLatLng(37.5666, 126.9784)
              : NLatLng(first.latitude, first.longitude),
          zoom: 14,
        ),
        // 로고는 가리지 않는다 — Maps 이용약관 제7조 ⑩이 지정 표시 게재를 요구한다.
        scaleBarEnable: false,
        indoorLevelPickerEnable: false,
        rotationGesturesEnable: false,
        tiltGesturesEnable: false,
        scrollGesturesEnable: widget.interactive,
        zoomGesturesEnable: widget.interactive,
        stopGesturesEnable: widget.interactive,
      ),
      onMapReady: _onMapReady,
      onMapTapped: widget.onTap == null ? null : (_, _) => widget.onTap!(),
    );
  }
}

/// 초기화 대기. 대체 화면을 먼저 보였다가 지도로 바뀌면 깜빡여 보이므로
/// 그 사이에는 빈 카드 톤을 유지한다.
class _MapLoading extends StatelessWidget {
  const _MapLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: LqColors.surfaceCard,
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: LqColors.primary,
          ),
        ),
      ),
    );
  }
}

/// 마커 핀. 앱의 손그림 톤(굵은 ink 테두리)을 지도 위에서도 유지한다.
class _MapPin extends StatelessWidget {
  const _MapPin({required this.color, required this.selected});

  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 40,
      child: CustomPaint(
        painter: _MapPinPainter(color: color, selected: selected),
      ),
    );
  }
}

class _MapPinPainter extends CustomPainter {
  const _MapPinPainter({required this.color, required this.selected});

  final Color color;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.width / 2);
    final radius = size.width / 2 - LqShape.borderWidth;

    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..moveTo(center.dx - radius * 0.52, center.dy + radius * 0.72)
      ..lineTo(center.dx, size.height - LqShape.borderWidth / 2)
      ..lineTo(center.dx + radius * 0.52, center.dy + radius * 0.72)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = LqColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = LqShape.borderWidth
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      center,
      radius * (selected ? 0.42 : 0.34),
      Paint()..color = LqColors.surfaceRaised,
    );
  }

  @override
  bool shouldRepaint(_MapPinPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.selected != selected;
}
