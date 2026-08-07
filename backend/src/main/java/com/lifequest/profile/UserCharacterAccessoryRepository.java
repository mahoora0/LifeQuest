package com.lifequest.profile;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserCharacterAccessoryRepository
        extends JpaRepository<UserCharacterAccessory, Long> {

    @EntityGraph(attributePaths = {"character", "accessory"})
    List<UserCharacterAccessory> findAllByUserId(Long userId);

    @EntityGraph(attributePaths = "accessory")
    Optional<UserCharacterAccessory> findByUserIdAndCharacterId(
            Long userId, Long characterId);
}
