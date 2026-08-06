package com.lifequest.profile;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface ProfileItemRepository extends JpaRepository<ProfileItem, Long> {
    List<ProfileItem> findAllByItemTypeOrderById(ProfileItem.ItemType itemType);
}
