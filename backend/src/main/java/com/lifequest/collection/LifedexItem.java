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
}
