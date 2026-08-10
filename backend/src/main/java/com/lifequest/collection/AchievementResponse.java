package com.lifequest.collection;

import java.util.List;

public record AchievementResponse(List<Item> achievements) {

    public record Item(
            Long id,
            String name,
            boolean achieved,
            boolean secret,
            String condition,
            int currentValue,
            int requiredValue,
            int currentStep) {
    }
}
