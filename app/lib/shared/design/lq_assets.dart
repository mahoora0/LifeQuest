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

  /// 깃발 아이콘(GPS 레이더 중앙 목표 지점).
  static const iconFlag = '${_dir}icon-flag.png';

  /// 지도 아이콘.
  static const iconMap = '${_dir}icon-map.png';

  /// 가방 아이콘(LifeDex).
  static const iconBackpack = '${_dir}icon-backpack.png';

  static String character(String code) =>
      '${_dir}characters/${code.toLowerCase()}.png';
}
