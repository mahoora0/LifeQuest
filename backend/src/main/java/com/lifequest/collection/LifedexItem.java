package com.lifequest.collection;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "lifedex_items")
class LifedexItem {

    @Id
    private Long id;

    @Column(name = "category_id", nullable = false)
    private Long categoryId;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(length = 500)
    private String description;

    @Column(name = "display_order", nullable = false)
    private int displayOrder;

    /**
     * 장소 모티프 아이콘 키. 항목마다 그림을 두지 않고 장소 유형을 가리킨다 —
     * 도감 항목은 전국 시드를 따라 계속 늘어나지만 유형은 닫혀 있기 때문이다.
     * 키 목록과 규칙은 docs/09-design-system.md §2 「도감 모티프」에 있다.
     * 비어 있으면 앱이 카테고리 모티프로 물러난다.
     */
    @Column(name = "icon_key", length = 40)
    private String iconKey;

    protected LifedexItem() {
    }

    Long getId() {
        return id;
    }

    Long getCategoryId() {
        return categoryId;
    }

    String getName() {
        return name;
    }

    String getDescription() {
        return description;
    }

    String getIconKey() {
        return iconKey;
    }
}
