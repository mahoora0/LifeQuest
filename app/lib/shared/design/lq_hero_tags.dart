/// 화면을 넘나드는 공유 요소(`Hero`)의 tag.
///
/// 한자리에 모아 두는 이유는 **같은 tag가 한 화면에 둘 있으면 즉시 크래시**이기
/// 때문이다. 호출부에서 문자열을 직접 만들면 `'avatar-$id'`와 `'user-$id'`처럼
/// 어긋나 애니메이션이 조용히 사라지거나, 반대로 서로 다른 것이 같은 tag를 갖는다.
abstract final class LqHeroTags {
  /// 모험가 아바타. 동료 목록 행 → 여정 화면.
  static String adventurer(int userId) => 'lq-adventurer-$userId';
}
