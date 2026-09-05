package com.lifequest.collection;

import java.util.List;

record LifedexCategoryResponse(List<Category> categories) {
    record Category(Long id, String name, long totalCount, long ownedCount, String iconKey) {
    }
}
