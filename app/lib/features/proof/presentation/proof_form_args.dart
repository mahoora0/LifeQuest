/// 퀘스트 완료 결과 화면에서 작성 화면으로 넘길 인자.
///
/// 완료 기록 ID만 넘기면 화면이 퀘스트명을 모르기 때문에 후보 목록을 다시 그려야 하고,
/// 그러면 "이미 정해진 퀘스트"가 아니라 "고를 수 있는 퀘스트"로 보인다. 제목과 등급을
/// 함께 넘기면 추가 조회 없이 읽기 전용 카드로 고정해 보여줄 수 있다.
class ProofFormArgs {
  const ProofFormArgs({
    required this.completionId,
    this.questTitle,
    this.questGrade,
  });

  final int completionId;
  final String? questTitle;
  final String? questGrade;
}
