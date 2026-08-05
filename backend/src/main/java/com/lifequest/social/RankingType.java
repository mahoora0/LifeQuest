package com.lifequest.social;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;

public enum RankingType {
    EXP,
    LEVEL;

    public static RankingType parse(String value) {
        try {
            return RankingType.valueOf(value == null ? "EXP" : value.trim().toUpperCase());
        } catch (IllegalArgumentException exception) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
    }
}
