package com.lifequest.collection;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "achievements")
class Achievement {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 50)
    private String code;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(nullable = false, length = 255)
    private String description;

    @Column(name = "condition_type", nullable = false, length = 30)
    private String conditionType;

    @Column(name = "condition_key", length = 30)
    private String conditionKey;

    @Column(name = "target_quest_id")
    private Long targetQuestId;

    @Column(name = "target_lifedex_category_id")
    private Long targetLifedexCategoryId;

    @Column(name = "is_secret", nullable = false)
    private boolean secret;

    @Column(name = "display_order", nullable = false)
    private int displayOrder;

    protected Achievement() {
    }

    Long getId() {
        return id;
    }

    String getName() {
        return name;
    }

    String getDescription() {
        return description;
    }

    String getConditionType() {
        return conditionType;
    }

    String getConditionKey() {
        return conditionKey;
    }

    Long getTargetQuestId() {
        return targetQuestId;
    }

    Long getTargetLifedexCategoryId() {
        return targetLifedexCategoryId;
    }

    boolean isSecret() {
        return secret;
    }
}
