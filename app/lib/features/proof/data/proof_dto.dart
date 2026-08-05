import 'package:life_quest/core/config/app_config.dart';
import 'package:life_quest/shared/data/json_reader.dart';

/// 인증 게시물의 판정 상태.
enum ProofStatus {
  voting,
  verified,
  unclear,
  rejected;

  static ProofStatus parse(Object? value) => switch (asString(value)) {
    'VERIFIED' => ProofStatus.verified,
    'UNCLEAR' => ProofStatus.unclear,
    'REJECTED' => ProofStatus.rejected,
    _ => ProofStatus.voting,
  };
}

/// 투표 선택지. 화면 문구가 서버 이름보다 길고 부드러운 것이 의도다 —
/// `옳음/아님`으로 표시하면 판정하는 쪽이 남을 심판하는 느낌이 된다.
enum ProofVoteChoice {
  agree('AGREE', '인증 맞아요'),
  unsure('UNSURE', '판단하기 어려워요'),
  reject('REJECT', '인증이 아닌 것 같아요');

  const ProofVoteChoice(this.wire, this.label);

  final String wire;
  final String label;

  static ProofVoteChoice? tryParse(Object? value) {
    final raw = asString(value);
    if (raw == null) return null;
    for (final choice in ProofVoteChoice.values) {
      if (choice.wire == raw) return choice;
    }
    return null;
  }
}

class ProofAuthor {
  const ProofAuthor({
    required this.userId,
    required this.nickname,
    this.profileImageUrl,
  });

  final int userId;
  final String nickname;
  final String? profileImageUrl;

  factory ProofAuthor.fromJson(Map<String, dynamic> json) => ProofAuthor(
    userId: asInt(json['userId']) ?? 0,
    nickname: asString(json['nickname']) ?? '모험가',
    // 서버는 `/uploads/profile/...` 상대 경로를 준다. 그대로 Image.network에 넘기면
    // 호스트가 없어 항상 실패하고 닉네임 첫 글자만 남는다.
    profileImageUrl: AppConfig.resolveMediaUrl(
      asString(json['profileImageUrl']),
    ),
  );
}

class ProofPost {
  const ProofPost({
    required this.postId,
    required this.author,
    required this.questId,
    required this.questTitle,
    required this.questGrade,
    required this.photoUrls,
    required this.status,
    required this.agreeCount,
    required this.unsureCount,
    required this.rejectCount,
    required this.decidedVoteCount,
    required this.minVotes,
    required this.commentCount,
    required this.mine,
    required this.createdAt,
    this.content,
    this.myVote,
  });

  final int postId;
  final ProofAuthor author;
  final int questId;
  final String questTitle;
  final String questGrade;
  final String? content;

  /// 서버가 내려주는 값은 `/uploads/proof/...` 상대 경로다. 표시 직전에 서버 origin을
  /// 붙여야 하므로 여기서 한 번에 절대 URL로 바꿔 둔다.
  final List<String> photoUrls;

  final ProofStatus status;
  final int agreeCount;
  final int unsureCount;
  final int rejectCount;

  /// "판단하기 어려워요"를 뺀 유효 표 수. 진행 표기의 분자다.
  final int decidedVoteCount;

  /// 판정에 필요한 표 수. 서버 설정값이라 앱에 하드코딩하지 않는다.
  final int minVotes;

  final int commentCount;
  final ProofVoteChoice? myVote;
  final bool mine;
  final DateTime createdAt;

  bool get canVote => !mine && myVote == null;

  /// 찬성 비율. 유효표가 없으면 `null`이라 화면이 0%로 오해하지 않는다.
  double? get agreeRatio =>
      decidedVoteCount == 0 ? null : agreeCount / decidedVoteCount;

  factory ProofPost.fromJson(Map<String, dynamic> json) => ProofPost(
    postId: asInt(json['postId']) ?? 0,
    author: ProofAuthor.fromJson(asMap(json['author'])),
    questId: asInt(json['questId']) ?? 0,
    questTitle: asString(json['questTitle']) ?? '퀘스트',
    questGrade: asString(json['questGrade']) ?? 'NORMAL',
    content: asString(json['content']),
    photoUrls:
        (json['photoUrls'] is List ? json['photoUrls'] as List : const [])
            .map((url) => AppConfig.resolveMediaUrl(asString(url)))
            .where((url) => url.isNotEmpty)
            .toList(),
    status: ProofStatus.parse(json['status']),
    agreeCount: asInt(json['agreeCount']) ?? 0,
    unsureCount: asInt(json['unsureCount']) ?? 0,
    rejectCount: asInt(json['rejectCount']) ?? 0,
    decidedVoteCount: asInt(json['decidedVoteCount']) ?? 0,
    minVotes: asInt(json['minVotes']) ?? 3,
    commentCount: asInt(json['commentCount']) ?? 0,
    myVote: ProofVoteChoice.tryParse(json['myVote']),
    mine: asBool(json['mine']),
    createdAt:
        DateTime.tryParse(asString(json['createdAt']) ?? '') ?? DateTime.now(),
  );
}

class ProofFeedPage {
  const ProofFeedPage({required this.items, this.nextCursor});

  final List<ProofPost> items;

  /// `null`이면 마지막 페이지다. 무한 스크롤은 이 값만 보고 멈춘다.
  final int? nextCursor;

  bool get hasMore => nextCursor != null;

  factory ProofFeedPage.fromJson(Map<String, dynamic> json) => ProofFeedPage(
    items: asMapList(json['items']).map(ProofPost.fromJson).toList(),
    nextCursor: asInt(json['nextCursor']),
  );
}

class ProofComment {
  const ProofComment({
    required this.commentId,
    required this.author,
    required this.content,
    required this.mine,
    required this.createdAt,
  });

  final int commentId;
  final ProofAuthor author;
  final String content;
  final bool mine;
  final DateTime createdAt;

  factory ProofComment.fromJson(Map<String, dynamic> json) => ProofComment(
    commentId: asInt(json['commentId']) ?? 0,
    author: ProofAuthor.fromJson(asMap(json['author'])),
    content: asString(json['content']) ?? '',
    mine: asBool(json['mine']),
    createdAt:
        DateTime.tryParse(asString(json['createdAt']) ?? '') ?? DateTime.now(),
  );
}

/// 아직 인증을 올리지 않은 내 완료 기록. 작성 화면의 퀘스트 선택 목록이다.
class ProofCandidate {
  const ProofCandidate({
    required this.completionId,
    required this.questId,
    required this.questTitle,
    required this.questGrade,
    required this.completedAt,
  });

  final int completionId;
  final int questId;
  final String questTitle;
  final String questGrade;
  final DateTime completedAt;

  factory ProofCandidate.fromJson(Map<String, dynamic> json) => ProofCandidate(
    completionId: asInt(json['completionId']) ?? 0,
    questId: asInt(json['questId']) ?? 0,
    questTitle: asString(json['questTitle']) ?? '퀘스트',
    questGrade: asString(json['questGrade']) ?? 'NORMAL',
    completedAt:
        DateTime.tryParse(asString(json['completedAt']) ?? '') ??
        DateTime.now(),
  );
}

class ProofVoteResult {
  const ProofVoteResult({required this.post, required this.expGained});

  final ProofPost post;

  /// 하루 지급 한도를 넘겼으면 0이다. 화면은 이 값으로 안내 문구를 정한다.
  final int expGained;

  factory ProofVoteResult.fromJson(Map<String, dynamic> json) =>
      ProofVoteResult(
        post: ProofPost.fromJson(asMap(json['post'])),
        expGained: asInt(json['expGained']) ?? 0,
      );
}

/// 피드 상단 세그먼트.
enum ProofFeedTab {
  needsVote('NEEDS_VOTE', '투표 필요'),
  all('ALL', '전체'),
  mine('MINE', '내 인증');

  const ProofFeedTab(this.wire, this.label);

  final String wire;
  final String label;
}
