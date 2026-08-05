package com.lifequest.admin.dto;

import com.lifequest.profile.ProfileItem;
import com.lifequest.profile.Title;
import java.util.List;

public record RewardCatalogResponse(
        List<TitleOption> titles,
        List<ProfileItemOption> profileItems) {
    public record TitleOption(Long id, String code, String name) {
        public static TitleOption from(Title title) {
            return new TitleOption(title.getId(), title.getCode(), title.getName());
        }
    }

    public record ProfileItemOption(
            Long id, String code, String name, ProfileItem.ItemType itemType) {
        public static ProfileItemOption from(ProfileItem item) {
            return new ProfileItemOption(
                    item.getId(), item.getCode(), item.getName(), item.getItemType());
        }
    }
}
