package com.lifequest.group;

import jakarta.persistence.LockModeType;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface GroupRepository extends JpaRepository<Group, Long> {
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select g from Group g where g.id = :id")
    Optional<Group> findByIdForUpdate(@Param("id") Long id);

    @Query("""
            select g from Group g
            where g.visibility = com.lifequest.group.GroupVisibility.PUBLIC
              and g.status = com.lifequest.group.GroupStatus.ACTIVE
              and (lower(g.name) like lower(concat('%', :query, '%'))
                   or lower(g.description) like lower(concat('%', :query, '%')))
            order by g.id desc
            """)
    Page<Group> searchPublic(@Param("query") String query, Pageable pageable);
}
