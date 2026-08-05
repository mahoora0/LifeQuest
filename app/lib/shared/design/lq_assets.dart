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
  static const map = '${_dir}map.svg';
  static const friends = '${_dir}friends.svg';
  static const my = '${_dir}my.svg';

  /// 도감. 디자인 프로젝트가 탭 아이콘과 함께 내려준 것이나 아직 쓰는 곳이 없다 —
  /// 마이페이지 "나의 기록"의 도감 행은 아이콘 없이 제목·진척만 보여준다.
  /// 그 행에 아이콘을 넣기로 하면 여기서 가져다 쓴다.
  static const lifedex = '${_dir}lifedex.svg';

  /// 검색 — 시안이 인라인 SVG로 그려 둔 것을 같은 규격으로 파일화했다.
  static const search = '${_dir}search.svg';
}
