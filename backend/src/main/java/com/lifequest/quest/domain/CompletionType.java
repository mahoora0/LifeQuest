package com.lifequest.quest.domain;

/**
 * 완료 방식. LOCATION은 GPS 위치 인증을 거치고, SELF_REPORT는 사용자 완료 입력만으로 처리한다
 * (docs/05-business-rules.md §4).
 */
public enum CompletionType {
    LOCATION,
    SELF_REPORT
}
