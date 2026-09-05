package com.lifequest.collection;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "lifedex_categories")
class LifedexCategory {

    @Id
    private Long id;

    @Column(nullable = false, length = 50)
    private String name;

    @Column(name = "display_order", nullable = false)
    private int displayOrder;

    /** 카테고리 대표 모티프 키. 항목이 자기 키를 갖지 않을 때 물러날 자리이기도 하다. */
    @Column(name = "icon_key", length = 40)
    private String iconKey;

    protected LifedexCategory() {
    }

    Long getId() {
        return id;
    }

    String getName() {
        return name;
    }

    int getDisplayOrder() {
        return displayOrder;
    }

    String getIconKey() {
        return iconKey;
    }
}
