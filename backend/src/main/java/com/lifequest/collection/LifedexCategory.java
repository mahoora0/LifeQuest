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
}
