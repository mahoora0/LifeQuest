import 'package:life_quest/features/friends/data/friend_dto.dart';

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
/// 보여 레이아웃·상호작용을 전혀 검토할 수 없기 때문이다.
class FriendRepository {
  const FriendRepository();

  /// 서버 연동 전까지 화면이 그리는 표본 친구 목록.
  static const _sampleFriends = [
    Friend(
      userId: 11,
      nickname: '민서',
      level: 7,
      statusLine: '오늘 퀘스트 2 / 3 진행 중',
    ),
    Friend(
      userId: 12,
      nickname: '준호',
      level: 5,
      statusLine: '어제 남산 전망대를 다녀왔어요',
      cheered: true,
    ),
    Friend(userId: 13, nickname: '하윤', level: 9, statusLine: '오늘 퀘스트 3 / 3 완료'),
    Friend(userId: 14, nickname: '지우', level: 4, statusLine: '이번 주 첫 퀘스트를 기다리는 중'),
  ];

  Future<FriendList> fetchFriends() async {
    return const FriendList(friends: _sampleFriends, myCode: 'LQ-4821');
  }

  Future<WeeklyRanking> fetchWeeklyRanking() async {
    return const WeeklyRanking(
      entries: [
        RankEntry(rank: 1, userId: 13, nickname: '하윤', weeklyExp: 420),
        RankEntry(rank: 2, userId: 11, nickname: '민서', weeklyExp: 380),
        RankEntry(rank: 3, userId: 1, nickname: '나', weeklyExp: 305, isMe: true),
        RankEntry(rank: 4, userId: 12, nickname: '준호', weeklyExp: 260),
        RankEntry(rank: 5, userId: 14, nickname: '지우', weeklyExp: 95),
      ],
      rankDelta: 1,
    );
  }

  /// 친구 응원. 서버가 붙기 전까지는 성공한 것으로 둔다.
  ///
  /// 응원에 EXP 보상이 걸려 있어 중복 요청 차단이 필요한데, 그 규칙(1일 1회 여부·보상 크기)이
  /// 아직 정해지지 않았다. 화면은 되돌리기 없는 단방향 동작으로 다룬다 — 취소를 허용하면
  /// 서버 규칙이 정해지기 전에 재지급 경로를 만들어 두는 셈이 된다.
  Future<void> cheer(int userId) async {}
}
