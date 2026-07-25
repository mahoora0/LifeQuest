package com.lifequest.growth;

import java.util.List;

public record GrowthResult(
        int expGained,
        int previousLevel,
        int currentLevel,
        boolean levelUp,
        boolean duplicated,
        List<String> rewards) {
}
