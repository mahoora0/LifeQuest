package com.lifequest.profile;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TitleRepository extends JpaRepository<Title, Long> {
    Optional<Title> findByCode(String code);

    List<Title> findAllByAcquireTypeOrderById(String acquireType);

    boolean existsByIdAndAcquireType(Long id, String acquireType);
}
