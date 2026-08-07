package com.lifequest.collection;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class LifedexService implements CollectionService {

    private final LifedexCategoryRepository categoryRepository;
    private final LifedexItemRepository itemRepository;
    private final UserLifedexRepository userLifedexRepository;

    LifedexService(
            LifedexCategoryRepository categoryRepository,
            LifedexItemRepository itemRepository,
            UserLifedexRepository userLifedexRepository) {
        this.categoryRepository = categoryRepository;
        this.itemRepository = itemRepository;
        this.userLifedexRepository = userLifedexRepository;
    }

    @Transactional(readOnly = true)
    LifedexCategoryResponse categories(Long userId) {
        Set<Long> ownedIds = ownedIds(userId);
        List<LifedexCategoryResponse.Category> categories = categoryRepository
                .findAllByOrderByDisplayOrderAsc().stream()
                .map(category -> {
                    List<LifedexItem> items = itemRepository
                            .findByCategoryIdOrderByDisplayOrderAsc(category.getId());
                    long ownedCount = items.stream()
                            .filter(item -> ownedIds.contains(item.getId()))
                            .count();
                    return new LifedexCategoryResponse.Category(
                            category.getId(), category.getName(), items.size(), ownedCount);
                })
                .toList();
        return new LifedexCategoryResponse(categories);
    }

    @Transactional(readOnly = true)
    LifedexResponse items(Long userId, Long categoryId) {
        Set<Long> ownedIds = ownedIds(userId);
        List<LifedexItem> items = categoryId == null
                ? itemRepository.findAllByOrderByCategoryIdAscDisplayOrderAsc()
                : itemRepository.findByCategoryIdOrderByDisplayOrderAsc(categoryId);
        return new LifedexResponse(items.stream()
                .map(item -> new LifedexResponse.Item(
                        item.getId(), item.getName(), item.getCategoryId(),
                        ownedIds.contains(item.getId()), item.getDescription()))
                .toList());
    }

    @Override
    @Transactional
    public CollectionOutcome evaluateOnQuestCompletion(
            Long userId, Long questId, Long lifedexItemId, Long questCompletionId) {
        if (lifedexItemId == null) {
            return CollectionOutcome.none();
        }

        return itemRepository.findById(lifedexItemId)
                .map(item -> {
                    if (userLifedexRepository.insertIfAbsent(userId, lifedexItemId) == 0) {
                        return CollectionOutcome.none();
                    }
                    CollectionOutcome.Entry entry = new CollectionOutcome.Entry(
                            item.getId(), item.getName(), false, null);
                    return new CollectionOutcome(List.of(entry), List.of());
                })
                .orElseGet(CollectionOutcome::none);
    }

    private Set<Long> ownedIds(Long userId) {
        return userLifedexRepository.findByUserId(userId).stream()
                .map(UserLifedex::getLifedexItemId)
                .collect(Collectors.toSet());
    }

    @Transactional(readOnly = true)
    public LifedexProgress progress(Long userId) {
        return new LifedexProgress(
                userLifedexRepository.countByUserId(userId),
                itemRepository.count(),
                Set.copyOf(userLifedexRepository.findCompletedCategoryIds(userId)));
    }

    public record LifedexProgress(
            long collectedCount,
            long totalCount,
            Set<Long> completedCategoryIds) {
    }
}
