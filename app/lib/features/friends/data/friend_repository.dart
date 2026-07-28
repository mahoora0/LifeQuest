import 'package:life_quest/features/friends/data/friend_dto.dart';
import 'package:life_quest/shared/data/sample_data.dart';
import 'package:life_quest/shared/design/lq_assets.dart';

/// 친구 목록·주간 랭킹·응원 조회.
///
/// ⚠ **서버 미구현 구간이다.** `docs/04-api-spec.md` §3-4에 `GET /api/friends`와
/// `GET /api/rankings/friends` 스펙이 있지만 백엔드에는 아직 friend 패키지가 없고,
/// 응원(cheer) 엔드포인트는 스펙에도 없다(담당: 팀원 4).
///
/// 화면을 시연·검증할 수 있도록 이 저장소가 고정 표본을 돌려준다. 아래 값은 실제 사용자
/// 데이터가 아니라 시안(`Life Quest 초안.dc.html` 10번 화면)의 예시를 옮긴 것이다.
/// 서버가 열리면 세 메서드의 본문만 Dio 호출로 바꾸면 되고 DTO·프로바이더·화면은 그대로다
/// — 각 DTO에 이미 `fromJson`이 있다.
///
/// 표본을 쓰는 대신 없는 엔드포인트를 호출하지 않는 이유는, 그 경우 화면이 늘 오류 상태로만
/// 보여 레이아웃·상호작용을 전혀 검토할 수 없기 때문이다. 대신 [LqSampleData.guard]가
/// **릴리스 빌드에서는 표본을 막아** 준비 중 안내로 떨어뜨린다 — 회수를 잊어도 가짜 수치가
/// 배포되지 않는다.
///
// TODO(server): GET /api/friends 개설 시 fetchFriends 본문을 Dio 호출로 바꾸고
//  LqSampleData.guard 호출과 _sampleFriends 상수를 지운다.
// TODO(server): GET /api/rankings/friends 개설 시 fetchWeeklyRanking을 실제 호출로 바꾼다.
// TODO(server): 응원 엔드포인트는 스펙에도 없다. 1일 1회 제한·보상 크기가 정해지면
//  cheer를 실제 호출로 바꾸고 중복 차단을 서버 판정에 맡긴다.
class FriendRepository {
  const FriendRepository();

  /// 서버 연동 전까지 화면이 그리는 표본 친구 목록. 이름·레벨·문구 모두 시안 값 그대로다.
  static const _sampleFriends = [
    Friend(userId: 0, nickname: '하늘', level: 14, statusLine: '오늘 4 / 5 완료'),
    Friend(userId: 1, nickname: '도토리', level: 11, statusLine: '오늘 2 / 5 완료'),
    Friend(
      userId: 2,
      nickname: '초록곰',
      level: 9,
      statusLine: '오늘 5 / 5 · 올클리어!',
    ),
    Friend(userId: 3, nickname: '밤톨', level: 15, statusLine: '어제 활동 · 연속 21일'),
  ];

  Future<FriendList> fetchFriends() async {
    LqSampleData.guard('친구 목록');
    return const FriendList(friends: _sampleFriends, myCode: 'LQ-4821');
  }

  Future<WeeklyRanking> fetchWeeklyRanking() async {
    LqSampleData.guard('이번 주 랭킹');
    return const WeeklyRanking(
      entries: [
        RankEntry(rank: 1, userId: 0, nickname: '하늘', weeklyExp: 1240),
        RankEntry(rank: 2, userId: 2, nickname: '초록곰', weeklyExp: 1080),
        RankEntry(
          rank: 3,
          userId: 100,
          nickname: '모험가 (나)',
          weeklyExp: 980,
          isMe: true,
        ),
        RankEntry(rank: 4, userId: 3, nickname: '밤톨', weeklyExp: 860),
        RankEntry(rank: 5, userId: 1, nickname: '도토리', weeklyExp: 720),
      ],
      rankDelta: 1,
    );
  }

  /// 내 친구 코드. 목록을 불러오지 않아도 동료 찾기에서 바로 보여야 한다.
  Future<String?> fetchMyCode() async {
    LqSampleData.guard('내 친구 코드');
    return 'LQ-4821';
  }

  /// 동료 찾기.
  ///
  /// 표본은 부분 일치로 거른다 — 시안 2f의 목업이 "초록" 한 번에 세 명(초록곰 ·
  /// 초록별 · 초록수풀)을 띄워 관계 3상태를 보여주는 구성이라, 완전 일치로 좁히면
  /// 그 화면을 재현할 수 없다.
  ///
  // TODO(design): 완전 일치만 허용할지 부분 일치도 허용할지 미정이다(시안
  //  "화면 구성 규칙" §12-②). 부분 일치는 낯선 사람 노출 범위가 넓어진다.
  //  판정은 서버가 하므로, 정해지면 이 표본이 아니라 검색 엔드포인트를 고친다.
  Future<List<AdventurerSearchResult>> searchAdventurers(String query) async {
    LqSampleData.guard('동료 찾기');

    final normalized = query.trim();
    if (normalized.isEmpty) return const [];

    return [
      for (final candidate in _sampleSearchPool)
        if (candidate.nickname.contains(normalized)) candidate,
    ];
  }

  /// 동료 신청 보내기.
  Future<void> sendRequest(int userId) async {}

  /// 받은 요청 · 보낸 요청.
  Future<FriendRequestBox> fetchRequests() async {
    LqSampleData.guard('동료 신청');
    return const FriendRequestBox(
      received: [
        FriendRequest(
          userId: 20,
          nickname: '솔방울',
          level: 13,
          statusLine: '칭호 · 새벽의 개척자 · 연속 18일',
        ),
        FriendRequest(
          userId: 21,
          nickname: '단풍',
          level: 4,
          statusLine: '이제 막 여정을 시작했어요',
        ),
      ],
      sent: [
        FriendRequest(
          userId: 12,
          nickname: '초록수풀',
          level: 21,
          statusLine: '요청을 보냈어요 · 대기 중',
        ),
      ],
    );
  }

  /// 받은 요청 처리.
  ///
  /// 거절은 조용히 처리한다 — 상대에게 알리지 않고, 같은 사람이 다시 요청할 수
  /// 있게 둔다. 거절 사실을 알리면 거절이 관계를 끊는 사건이 된다.
  Future<void> respondToRequest(int userId, {required bool accept}) async {}

  /// 동료 여정 비교.
  ///
  // TODO(design): 공개 범위 미정(시안 §12-③). 레벨·도감·업적 **합계**까지만 내려주고
  //  개별 퀘스트 이력은 감추는 쪽으로 구현했다.
  Future<FriendJourney> fetchJourney(int userId) async {
    LqSampleData.guard('동료의 여정');

    final friend = _sampleFriends.firstWhere(
      (candidate) => candidate.userId == userId,
      orElse: () => _sampleFriends.first,
    );

    return FriendJourney(
      userId: friend.userId,
      nickname: friend.nickname,
      titleLine: '칭호 · 새벽의 개척자',
      me: const JourneySide(
        level: 12,
        lifedexCollected: 42,
        achievements: 24,
        streakDays: 14,
      ),
      friend: JourneySide(
        level: friend.level,
        lifedexCollected: 51,
        achievements: 31,
        streakDays: 9,
      ),
      badges: const [
        JourneyBadge(name: '개척자의 깃발', iconAsset: LqAssets.iconFlag),
        JourneyBadge(name: '길잡이', iconAsset: LqAssets.iconMap),
        JourneyBadge(name: '새벽의 개척자'),
      ],
    );
  }

  /// 동료 해제.
  Future<void> unfriend(int userId) async {}

  /// 동료 찾기 표본 풀. 시안 2f의 예시 3명이다.
  static const _sampleSearchPool = [
    AdventurerSearchResult(
      userId: 2,
      nickname: '초록곰',
      level: 9,
      relation: FriendRelation.friend,
      statusLine: '이미 함께 모험 중',
    ),
    AdventurerSearchResult(
      userId: 11,
      nickname: '초록별',
      level: 6,
      relation: FriendRelation.none,
      statusLine: '칭호 · 첫 걸음',
    ),
    AdventurerSearchResult(
      userId: 12,
      nickname: '초록수풀',
      level: 21,
      relation: FriendRelation.requestSent,
      statusLine: '요청을 보냈어요 · 대기 중',
    ),
  ];

  /// 친구 응원. 서버가 붙기 전까지는 성공한 것으로 둔다.
  ///
  /// 응원에 EXP 보상이 걸려 있어 중복 요청 차단이 필요한데, 그 규칙(1일 1회 여부·보상 크기)이
  /// 아직 정해지지 않았다. 화면은 되돌리기 없는 단방향 동작으로 다룬다 — 취소를 허용하면
  /// 서버 규칙이 정해지기 전에 재지급 경로를 만들어 두는 셈이 된다.
  Future<void> cheer(int userId) async {}
}
