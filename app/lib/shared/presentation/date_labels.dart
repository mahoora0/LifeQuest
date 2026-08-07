/// 그룹 퀘스트 예정 일시 문구.
///
/// `8/8`처럼 슬래시로 줄여 쓰지 않는다 — 그룹 화면에는 `1/10명`(멤버 수/정원)이
/// 같이 놓여 있어 날짜가 인원수로 읽힌다. 실제로 8월 8일 퀘스트의 `8/8`을
/// 참가 인원으로 오해한 사례가 있었다.
library;

/// `8월 8일`.
String questDateLabel(DateTime at) => '${at.month}월 ${at.day}일';

/// `8월 8일 16:13`.
String questDateTimeLabel(DateTime at) =>
    '${questDateLabel(at)} '
    '${at.hour.toString().padLeft(2, '0')}:'
    '${at.minute.toString().padLeft(2, '0')}';
