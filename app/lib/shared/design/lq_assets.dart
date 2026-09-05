/// 디자인 프로젝트 `assets/`에서 가져온 캐릭터·아이콘 PNG 경로.
///
/// 파일은 `app/assets/images/`에 위치하며 `pubspec.yaml`에 등록되어 있다.
/// 파일이 아직 배치되지 않은 환경에서도 화면이 깨지지 않도록,
/// 모든 사용처는 [LqImage]를 통해 대체 도형으로 폴백한다.
abstract final class LqAssets {
  static const _dir = 'assets/images/';

  /// 앱 로고 캐릭터(홈 상단).
  static const logoChar = '${_dir}logo-char.png';

  /// 인사하는 캐릭터(홈 인사말).
  static const charWave = '${_dir}char-wave.png';

  /// 앉아 있는 캐릭터(퀘스트 상세 · 빈 상태).
  static const charSit = '${_dir}char-sit.png';

  /// 걷는 캐릭터(완료 결과).
  static const charWalk = '${_dir}char-walk.png';

  /// 지도를 든 캐릭터(위치 퀘스트 · LifeDex 안내 · 인증 성공).
  static const charMap = '${_dir}char-map.png';

  /// 정면 캐릭터(지도 현재 위치 · 프로필 기본 아바타).
  static const charFront = '${_dir}char-front.png';

  /// 배경 없이 앉아 있는 캐릭터(카드 안 빈 상태 — 처리할 일이 없을 때).
  static const charPlainSit = '${_dir}char-plain-sit.png';

  /// 깃발 아이콘(GPS 레이더 중앙 목표 지점).
  static const iconFlag = '${_dir}accessory/icon-flag.png';

  /// 지도 아이콘.
  static const iconMap = '${_dir}accessory/icon-map.png';

  /// 가방 아이콘(LifeDex).
  static const iconBackpack = '${_dir}accessory/icon-backpack.png';

  /// 나의 기록 도감 아이콘.
  static const book = '${_dir}icons/Book.png';

  /// 나의 기록 업적·칭호 아이콘.
  static const trophyCup = '${_dir}icons/Trophy Cup.png';

  /// 깃털 뱃지 아이콘.
  static const featherBadge = '${_dir}accessory/Feather Badge.png';

  /// 필드 수첩 아이콘.
  static const fieldNotebook = '${_dir}accessory/Field Notebook.png';

  /// 퀘스트 티켓 아이콘.
  static const questTicket = '${_dir}accessory/Quest Ticket.png';

  static String character(String code) =>
      '${_dir}characters/${code.toLowerCase()}.png';

  static String characterWithAccessory(
    String characterCode,
    String? accessoryCode,
  ) {
    if (characterCode.toUpperCase() != 'ROOKIE' || accessoryCode == null) {
      return character(characterCode);
    }
    final fileName = switch (accessoryCode.toUpperCase()) {
      'APRON' => 'rookie_apron.png',
      'EXPLORER_HAT' => 'rookie_explorerHat.png',
      'HERO_CAPE' => 'rookie_heroCape.png',
      'HOOD' => 'rookie_hood.png',
      'LEAF_HAT' => 'rookie_leafHat.png',
      'MAGNIFYING' => 'rookie_magnifying.png',
      'MAP_SCROLL' => 'rookie_mapScroll.png',
      'MOON_GLASSES' => 'rookie_moonGlasses.png',
      'PICNIC_BASKET' => 'rookie_picnicBasket.png',
      'RAIN_PONCHO' => 'rookie_rainPoncho.png',
      'RIBBON_BOW' => 'rookie_ribbonBow.png',
      'ROUND_GLASSES' => 'rookie_roundGlasses.png',
      'SHOULDER_STRAP_BAG' => 'rookie_shoulderStrapBag.png',
      'TINY_BACKPACK' => 'rookie_tinyBackpack.png',
      _ => null,
    };
    return fileName == null
        ? character(characterCode)
        : '${_dir}characters/rookie_accessory/$fileName';
  }

  static String accessory(String code) {
    final fileName = switch (code.toUpperCase()) {
      'APRON' => 'Apron.png',
      'EXPLORER_HAT' => 'Explorer Hat.png',
      'HERO_CAPE' => 'Hero Cape.png',
      'HOOD' => 'Hood.png',
      'LEAF_HAT' => 'Leaf Hat.png',
      'MAGNIFYING' => 'Magnifying.png',
      'MAP_SCROLL' => 'Map Scroll.png',
      'MOON_GLASSES' => 'Moon Glasses.png',
      'PICNIC_BASKET' => 'Picnic Basket.png',
      'RAIN_PONCHO' => 'Rain Poncho.png',
      'RIBBON_BOW' => 'Ribbon Bow.png',
      'ROUND_GLASSES' => 'Round Glasses.png',
      'SHOULDER_STRAP_BAG' => 'Shoulder Strap Bag.png',
      'TINY_BACKPACK' => 'Tiny Backpack.png',
      _ => 'icon-backpack.png',
    };
    return '${_dir}accessory/$fileName';
  }
}

/// 선 아이콘 SVG 경로 — 24 그리드 · stroke 2.2 · round cap.
///
/// 아이콘 폰트와 이모지를 쓰지 않는 것이 시안 규칙이므로, 탭 아이콘과
/// 기능 아이콘은 모두 이 목록에서 가져온다. 새 아이콘이 필요하면 같은 규격의
/// Lucide 아이콘을 stroke 2.2로 맞춰 이 디렉터리에 추가한다.
abstract final class LqIcons {
  static const _dir = 'assets/images/icons/';

  static const home = '${_dir}home.svg';
  static const quest = '${_dir}quest.svg';

  /// 지도. 탭에서 빠졌고 지금은 쓰는 곳이 없다 — `/map` 라우트는 남아 있으므로
  /// 다시 진입점을 만들면 여기서 가져다 쓴다.
  static const map = '${_dir}map.svg';

  /// 그룹 탭. 친구 아이콘과 구분되도록 가운데 인물이 큰 3인 실루엣이다.
  static const group = '${_dir}group.svg';
  static const friends = '${_dir}friends.svg';
  static const my = '${_dir}my.svg';

  /// 도감. 디자인 프로젝트가 탭 아이콘과 함께 내려준 것이나 아직 쓰는 곳이 없다 —
  /// 마이페이지 "나의 기록"의 도감 행은 아이콘 없이 제목·진척만 보여준다.
  /// 그 행에 아이콘을 넣기로 하면 여기서 가져다 쓴다.
  static const lifedex = '${_dir}lifedex.svg';

  /// 검색 — 시안이 인라인 SVG로 그려 둔 것을 같은 규격으로 파일화했다.
  static const search = '${_dir}search.svg';
}

/// 도감 항목의 장소 모티프 아이콘 — 규격은 [LqIcons]와 같다(24 그리드 · stroke 2.2).
///
/// **항목마다 한 장씩 그리지 않는다.** 도감 항목 수가 열려 있기 때문이다. 전국
/// 위치 퀘스트 시드(V33 37건 · V34 174건)가 도감으로 올라오면 항목은 수백 개가
/// 되지만, 그 장소들이 속하는 *유형*은 아래 17종으로 닫힌다. 새 항목은 기존
/// 모티프를 가리키기만 하면 되고, 그림을 새로 그리는 것은 유형이 늘어날 때뿐이다.
///
/// DB의 `lifedex_items.icon_key` · `lifedex_categories.icon_key`가 이 키를 담는다.
/// 키 이름 규칙과 유형별 뜻은 `docs/09-design-system.md` §2 「도감 모티프」에 있다.
abstract final class LqLifedexIcons {
  static const _dir = 'assets/images/icons/lifedex/';

  /// 키 → SVG 경로.
  ///
  /// **앱이 가진 키의 목록이 곧 계약이다.** DB가 여기 없는 키를 보내더라도
  /// [pathOf]가 null을 돌려주고 화면은 카테고리 모티프로 물러난다. 그림 없는
  /// 키를 참조해도 화면이 깨지지 않으므로, 시드와 아트가 다른 순서로 들어와도
  /// 된다 — 다만 그동안 그 항목은 카테고리 아이콘으로 보인다.
  static const _byKey = <String, String>{
    'cafe': '${_dir}cafe.svg',
    'park_city': '${_dir}park_city.svg',
    'park_forest': '${_dir}park_forest.svg',
    'garden': '${_dir}garden.svg',
    'trail': '${_dir}trail.svg',
    'waterside': '${_dir}waterside.svg',
    'beach': '${_dir}beach.svg',
    'mountain': '${_dir}mountain.svg',
    'library': '${_dir}library.svg',
    'museum': '${_dir}museum.svg',
    'gallery': '${_dir}gallery.svg',
    'market': '${_dir}market.svg',
    'street': '${_dir}street.svg',
    'hanok': '${_dir}hanok.svg',
    'palace': '${_dir}palace.svg',
    'heritage': '${_dir}heritage.svg',
    'tower': '${_dir}tower.svg',
  };

  /// [key]의 SVG 경로. 모르는 키·null이면 null.
  static String? pathOf(String? key) => key == null ? null : _byKey[key];

  /// 그림이 준비된 키 전체. 시드가 쓴 키가 이 안에 있는지 확인할 때 쓴다.
  static Iterable<String> get keys => _byKey.keys;
}
