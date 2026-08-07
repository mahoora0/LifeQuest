package com.lifequest.profile;

import com.lifequest.user.User;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "user_character_accessories")
public class UserCharacterAccessory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "character_id", nullable = false)
    private AvatarCharacter character;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "profile_item_id", nullable = false)
    private ProfileItem accessory;

    protected UserCharacterAccessory() {
    }

    public UserCharacterAccessory(
            User user, AvatarCharacter character, ProfileItem accessory) {
        this.user = user;
        this.character = character;
        this.accessory = accessory;
    }

    public void changeAccessory(ProfileItem accessory) {
        this.accessory = accessory;
    }

    public AvatarCharacter getCharacter() {
        return character;
    }

    public ProfileItem getAccessory() {
        return accessory;
    }
}
