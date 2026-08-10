package com.lifequest.user;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;
import com.lifequest.profile.AvatarCharacter;
import com.lifequest.profile.ProfileItem;
import com.lifequest.profile.Title;

@Entity
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 255)
    private String email;

    @Column(name = "password_hash", length = 255)
    private String passwordHash;

    @Column(nullable = false, unique = true, length = 50)
    private String nickname;

    @Column(name = "friend_code", unique = true, length = 16)
    private String friendCode;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private UserRole role = UserRole.USER;

    @Column(name = "profile_image_url", length = 500)
    private String profileImageUrl;

    @Column(name = "total_exp", nullable = false)
    private int totalExp;

    @Column(nullable = false)
    private int level = 1;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "selected_character_id")
    private AvatarCharacter selectedCharacter;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "representative_title_id")
    private Title representativeTitle;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "selected_accessory_id")
    private ProfileItem selectedAccessory;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected User() {
    }

    private User(String email, String passwordHash, String nickname, String profileImageUrl) {
        this.email = email;
        this.passwordHash = passwordHash;
        this.nickname = nickname;
        this.profileImageUrl = profileImageUrl;
    }

    public static User local(String email, String passwordHash, String nickname) {
        return new User(email, passwordHash, nickname, null);
    }

    public static User google(String email, String nickname, String profileImageUrl) {
        return new User(email, null, nickname, profileImageUrl);
    }

    @PrePersist
    void prePersist() {
        Instant now = Instant.now();
        createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    void preUpdate() {
        updatedAt = Instant.now();
    }

    public void updateProfile(String nickname, String profileImageUrl) {
        this.nickname = nickname;
        this.profileImageUrl = profileImageUrl;
    }

    public void updateProfileImage(String profileImageUrl) {
        this.profileImageUrl = profileImageUrl;
    }

    public void selectCharacter(AvatarCharacter character) {
        this.selectedCharacter = character;
    }

    public void selectRepresentativeTitle(Title title) {
        this.representativeTitle = title;
    }

    public void selectAccessory(ProfileItem accessory) {
        this.selectedAccessory = accessory;
    }

    public void addExp(int amount, int newLevel) {
        this.totalExp += amount;
        this.level = newLevel;
    }

    public Long getId() {
        return id;
    }

    public String getEmail() {
        return email;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public String getNickname() {
        return nickname;
    }

    public String getFriendCode() {
        return friendCode;
    }

    public void assignFriendCode(String friendCode) {
        if (this.friendCode == null) {
            this.friendCode = friendCode;
        }
    }

    public UserRole getRole() {
        return role;
    }

    public String getProfileImageUrl() {
        return profileImageUrl;
    }

    public int getTotalExp() {
        return totalExp;
    }

    public int getLevel() {
        return level;
    }

    public AvatarCharacter getSelectedCharacter() {
        return selectedCharacter;
    }

    public Title getRepresentativeTitle() {
        return representativeTitle;
    }

    public ProfileItem getSelectedAccessory() {
        return selectedAccessory;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
