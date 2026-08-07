package com.lifequest.collection;

import java.util.List;

record LifedexResponse(List<Item> items) {
    record Item(Long id, String name, Long categoryId, boolean owned, String description) {
    }
}
