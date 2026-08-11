import 'package:flutter/material.dart';

/// 확정 시안(`Life Quest 초안.dc.html`)의 디자인 토큰.
///
/// 시안의 px 값은 320pt 폭 프레임 기준이며 Flutter 논리 px(dp)에 1:1로 대응한다.
/// 화면·위젯 코드에서 색·치수를 하드코딩하지 말고 이 파일의 상수를 사용한다.
abstract final class LqColors {
  // 표면 — 원료(raw). 웹 디자인 시스템의 `--lq-surface*`와 이름·값이 1:1로 대응한다.
  // 이름이 어긋나 있던 옛 `card`(=raised)·`panel`(=tint)을 웹 쪽에 맞춰 정리한 것이다.
  static const surface = Color(0xFFFEF8EE); // --lq-surface
  static const surfaceRaised = Color(0xFFFFFDF6); // --lq-surface-raised
  static const surfaceTint = Color(0xFFFBF4E4); // --lq-surface-tint

  // 표면 — 역할(semantic). 레이어링 규칙은 이 네 줄에서만 정의한다.
  // 화면·위젯은 원료색이 아니라 역할 토큰을 참조하므로, 규칙이 바뀌면 여기만 고치면 된다.
  //
  // 깊이 순서(밝음 → 어두움): 프레임·리스트 항목 `#FFFDF6` › 주 카드 `#FBF4E4`.
  // 하단 탭 바 `#FEF8EE`는 프레임과 구분되는 별도 톤이다.

  /// 화면 바탕(Scaffold)·패널. 가장 밝다.
  static const surfacePanel = surfaceRaised;

  /// 주 콘텐츠 카드. 프레임보다 한 단계 눌러 담아 깊이를 만든다.
  static const surfaceCard = surfaceTint;

  /// 하단 탭 바.
  static const surfaceNav = surface;

  /// 리스트 행·아이콘 타일. 주 카드 위에서 다시 밝게 도드라진다.
  static const surfaceTile = surfaceRaised;

  /// 아이콘 웰의 채움. 카드보다 한 톤 진해 안에 든 것이 도드라진다.
  static const tileFill = Color(0xFFF3E9D0);

  // 잉크 · 텍스트
  static const ink = Color(0xFF4A4132);
  static const textPrimary = Color(0xFF443B2A);
  static const textBody = Color(0xFF5C5344);
  static const textSecondary = Color(0xFF7A7060);
  static const textMuted = Color(0xFF9A8F7B);
  static const onDark = Color(0xFFFEF8EE);

  // 테두리 · 구분선
  static const borderMuted = Color(0xFFC9BC9E);
  static const divider = Color(0xFFD8CDB4);

  // 브랜드 그린
  static const primary = Color(0xFF55663D);
  static const expFill = Color(0xFF7A8B54);
  static const expBadge = Color(0xFF5A6B3B);
  static const tabActive = Color(0xFF4A6B2F);
  static const tabInactive = Color(0xFF8A8070);
  static const gem = Color(0xFF7FA06A);

  // 재화(골드)
  static const gold = Color(0xFFE7B94F);
  static const goldBg = Color(0xFFF1DFAE);
  static const goldBorder = Color(0xFFC9A94E);
  static const goldText = Color(0xFF5C4A22);
  static const goldStamp = Color(0xFFA8842B);

  // 강조 · 위치
  static const accent = Color(0xFFC96A47);
  static const locBg = Color(0xFFEADFF3);
  static const locBorder = Color(0xFF9C87B5);

  // 잠김 · 비활성
  static const lockedBg = Color(0xFFF6EFDF);
  static const lockedTile = Color(0xFFEDE4CE);
  static const disabledBg = Color(0xFFE3DCC8);

  // 퀘스트 등급 강조. 인증 광장의 퀘스트명 배지가 등급을 색으로 구분한다.
  // 네 값을 한자리에 모아 두는 이유는 등급이 화면 여러 곳에 나오기 때문이다 —
  // 흩어지면 같은 등급이 화면마다 다른 색으로 보인다.
  static const gradeNormal = borderMuted;
  static const gradeRare = Color(0xFF8FA3AE);
  static const gradeEpic = locBorder;
  static const gradeLegendary = goldBorder;

  // 상태 배너
  static const successText = Color(0xFF55663D);
  static const successBg = Color(0xFFE9EFDC);
  static const warnText = Color(0xFFA8652B);
  static const warnBg = Color(0xFFF6E7D4);
  static const dangerText = Color(0xFF9A4B33);
  static const dangerBg = Color(0xFFF3DBD3);
}

/// 퀘스트 분류 태그 팔레트.
class LqTagPalette {
  const LqTagPalette(this.label, this.background, this.border);

  final String label;
  final Color background;
  final Color border;

  static const habit = LqTagPalette('습관', Color(0xFFE9E9D4), Color(0xFF9BA76F));
  static const daily = LqTagPalette('일간', Color(0xFFF3E4C8), Color(0xFFC9A94E));
  static const weekly = LqTagPalette(
    '주간',
    Color(0xFFE4E9EC),
    Color(0xFF8FA3AE),
  );
  static const monthly = LqTagPalette(
    '그룹',
    Color(0xFFDFEAD1),
    Color(0xFF8FA86A),
  );
  static const location = LqTagPalette(
    '위치',
    LqColors.locBg,
    LqColors.locBorder,
  );
  static const selfReport = LqTagPalette(
    '직접 완료',
    Color(0xFFE9E9D4),
    Color(0xFF9BA76F),
  );
}

/// 타이포그래피. 글꼴(A2Z)은 `ThemeData.fontFamily`에서 일괄 적용되므로
/// 여기서는 `fontFamily`를 지정하지 않는다(지정하면 테마 글꼴을 덮어쓴다).
abstract final class LqText {
  static const displayTitle = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: LqColors.textPrimary,
  );
  static const bigTitle = TextStyle(
    fontSize: 25,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: LqColors.textPrimary,
  );
  static const levelNumber = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: LqColors.textPrimary,
  );
  static const sectionTitle = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: LqColors.textPrimary,
  );
  static const screenTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: LqColors.textPrimary,
  );
  static const cardTitle = TextStyle(
    fontSize: 16.5,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: LqColors.textPrimary,
  );
  static const body = TextStyle(
    fontSize: 16,
    height: 1.35,
    color: LqColors.textBody,
  );
  static const bodySm = TextStyle(
    fontSize: 15,
    height: 1.35,
    color: LqColors.textBody,
  );
  static const label = TextStyle(
    fontSize: 14,
    height: 1.3,
    color: LqColors.textSecondary,
  );
  static const caption = TextStyle(
    fontSize: 13.5,
    height: 1.3,
    color: LqColors.textMuted,
  );
  static const badge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
  static const tabLabel = TextStyle(fontSize: 11.5, height: 1.2);
}

/// 형태 언어 — 좌우 비대칭 라운드가 손그림 느낌의 핵심이다.
abstract final class LqShape {
  /// 모든 실선 테두리 두께.
  static const borderWidth = 2.0;

  /// 화면 대형 카드 16/20/16/20.
  static const cardRadius = BorderRadius.only(
    topLeft: Radius.circular(16),
    topRight: Radius.circular(20),
    bottomRight: Radius.circular(16),
    bottomLeft: Radius.circular(20),
  );

  /// 리스트 행 14/17/14/17.
  static const rowRadius = BorderRadius.only(
    topLeft: Radius.circular(14),
    topRight: Radius.circular(17),
    bottomRight: Radius.circular(14),
    bottomLeft: Radius.circular(17),
  );

  /// 소형(아이콘 타일 등) 12/15/12/15.
  static const tileRadius = BorderRadius.only(
    topLeft: Radius.circular(12),
    topRight: Radius.circular(15),
    bottomRight: Radius.circular(12),
    bottomLeft: Radius.circular(15),
  );

  /// 버튼 14/18/14/18.
  static const buttonRadius = BorderRadius.only(
    topLeft: Radius.circular(14),
    topRight: Radius.circular(18),
    bottomRight: Radius.circular(14),
    bottomLeft: Radius.circular(18),
  );

  /// 칩 · 진행 바 — 완전 pill.
  static const pillRadius = BorderRadius.all(Radius.circular(99));

  /// blur 없는 오프셋 섀도(손그림 스티커 느낌).
  static const cardShadow = [
    BoxShadow(color: Color(0x1F5A4628), offset: Offset(4, 5)),
  ];
  static const buttonShadow = [
    BoxShadow(color: Color(0x405A4628), offset: Offset(3, 4)),
  ];

  /// 눌린 표면의 섀도 오프셋. 모든 표면이 여기까지 눌린다.
  static const pressedShadowOffset = Offset(1, 1);

  /// [base]가 [pressedShadowOffset]까지 눌리는 동안 위젯이 내려가야 하는 거리.
  ///
  /// 이 값만큼 내려가야 섀도의 바깥 경계가 제자리에 남는다 — 스티커가 종이에
  /// 눌러 붙는 것처럼 보이는 이유가 그것이다. 위젯만 내리거나 섀도만 줄이면
  /// 경계가 함께 움직여 "미끄러진" 것처럼 읽힌다.
  static Offset pressDepth(List<BoxShadow> base) =>
      base.first.offset - pressedShadowOffset;

  /// 눌림 진행도 [t](0=평상시, 1=눌림)에 맞춰 섀도를 줄인다.
  static List<BoxShadow>? pressShadow(List<BoxShadow>? base, double t) {
    if (base == null) return null;
    if (t == 0) return base;
    return [
      for (final shadow in base)
        BoxShadow(
          color: shadow.color,
          blurRadius: shadow.blurRadius,
          spreadRadius: shadow.spreadRadius,
          offset: Offset.lerp(shadow.offset, pressedShadowOffset, t)!,
        ),
    ];
  }

  static Border get inkBorder =>
      Border.all(color: LqColors.ink, width: borderWidth);

  static Border mutedBorder([Color color = LqColors.borderMuted]) =>
      Border.all(color: color, width: borderWidth);
}

/// 모션 토큰. 화면·위젯 코드에서 duration·curve를 하드코딩하지 않는다.
///
/// 시안(`09-design-system.md` §3)이 정한 손그림 톤을 지키기 위한 규칙이 둘 있다.
///
/// 1. 누르는 피드백은 축소(scale)가 아니라 **섀도 오프셋 감소 + 그만큼의 내려감**이다.
///    이 앱의 표면은 blur 없는 오프셋 섀도를 쓰는 종이 스티커라, 줄어드는 쪽이 맞다.
/// 2. 바운스([bounce])는 퀘스트 완료 결과 화면에만 쓴다. 그 밖에서 튕기면
///    앱 전체가 장난감처럼 읽힌다.
abstract final class LqMotion {
  /// 누름·뗌 피드백.
  static const press = Duration(milliseconds: 110);

  /// 아이콘 토글처럼 작은 변화.
  static const quick = Duration(milliseconds: 160);

  /// 숫자·콘텐츠 교체(`AnimatedSwitcher`).
  static const normal = Duration(milliseconds: 220);

  /// 페이지 전환(들어갈 때).
  static const page = Duration(milliseconds: 280);

  /// 페이지 전환(나올 때). 나가는 쪽이 빨라야 되돌아오는 길이 가볍다.
  static const pageReverse = Duration(milliseconds: 220);

  /// 보상 연출. 퀘스트 완료 결과 화면 전용이다.
  static const emphasized = Duration(milliseconds: 480);

  /// 목록이 순서대로 등장할 때의 항목 간 간격.
  static const staggerStep = Duration(milliseconds: 40);

  /// 시간차를 주는 항목 수 상한. 그 뒤 항목은 지연 없이 바로 나온다 —
  /// 20번째 항목까지 기다리게 하면 목록이 느린 앱이 된다.
  static const staggerMaxItems = 6;

  static const standard = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;

  /// 시안 확정 바운스 `cubic-bezier(.2,.8,.3,1.2)`.
  static const bounce = Cubic(.2, .8, .3, 1.2);

  /// 사용자가 OS에서 "동작 줄이기"를 켰는가.
  ///
  /// 켠 사람에게 움직임은 취향 문제가 아니라 어지럼증·주의 분산의 원인이다.
  /// 특히 끝나지 않는 장식(둥실·파동)은 반드시 멈춰야 한다.
  static bool isReduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// "동작 줄이기"가 켜져 있으면 0을 준다.
  ///
  /// **새 애니메이션은 duration을 이 함수로 감싸는 것이 필수 요건이다.**
  static Duration of(BuildContext context, Duration duration) =>
      isReduced(context) ? Duration.zero : duration;
}

/// 여백 · 치수 토큰.
abstract final class LqSpacing {
  /// 모든 화면 좌우 패딩.
  static const screen = 16.0;

  /// 섹션 간 기본 gap.
  static const gap = 12.0;

  /// 진행 바 높이.
  static const progressHeight = 12.0;

  /// 최소 터치 타깃.
  static const minTouchTarget = 44.0;
}

/// 서버가 아직 공급하지 못하는 데이터의 노출 스위치 (07 명세 §6).
///
/// 레이아웃·컴포넌트는 시안대로 구현하되, 아래 플래그로 노출만 제어한다.
/// 서버 확장 시 `true`로 바꾸면 시안 그대로 드러난다.
abstract final class LqFeatures {
  /// ① 골드(G)·보석 재화 — API·DB에 재화 없음.
  static const currencyEnabled = false;

  /// ② 연속 달성(streak) — 서버 판정 필요, API 미지원.
  static const streakEnabled = false;

  /// ⑤ 진행형(누적) 퀘스트 — API는 1회 완료 모델.
  static const progressiveQuestEnabled = false;
}
