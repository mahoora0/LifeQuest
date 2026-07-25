package com.lifequest.profile;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "avatar_characters")
public class AvatarCharacter {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 50)
    private String code;

    @Column(nullable = false, length = 50)
    private String name;

    @Column(name = "asset_key", nullable = false, length = 100)
    private String assetKey;

    @Column(name = "is_active", nullable = false)
    private boolean active;

    protected AvatarCharacter() {
    }

    public Long getId() {
        return id;
    }

    public String getCode() {
        return code;
    }

    public String getName() {
        return name;
    }

    public String getAssetKey() {
        return assetKey;
    }

    public boolean isActive() {
        return active;
    }
}
