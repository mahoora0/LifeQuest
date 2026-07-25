package com.lifequest.profile;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AvatarCharacterRepository extends JpaRepository<AvatarCharacter, Long> {
    List<AvatarCharacter> findAllByActiveTrueOrderById();
}
