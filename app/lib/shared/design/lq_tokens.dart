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

  /// 배지 칸·아이콘 웰의 채움. 카드보다 한 톤 진해 안에 든 것이 도드라진다.
  /// 대표 배지처럼 골드로 강조된 칸과 나란히 놓였을 때 대비가 생기는 값이다.
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
    '월간',
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

/// 타이포그래피. 글꼴(Gaegu)은 `ThemeData.textTheme`에서 일괄 적용되므로
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

  static Border get inkBorder =>
      Border.all(color: LqColors.ink, width: borderWidth);

  static Border mutedBorder([Color color = LqColors.borderMuted]) =>
      Border.all(color: color, width: borderWidth);
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
