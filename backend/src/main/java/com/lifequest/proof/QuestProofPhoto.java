package com.lifequest.proof;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

/**
 * 게시물에 붙은 인증 사진 한 장. {@code sortOrder}는 사용자가 고른 순서이며
 * {@code UNIQUE(post_id, sort_order)}로 중복이 막혀 있어 캐러셀 순서가 흔들리지 않는다.
 */
@Entity
@Table(name = "quest_proof_photos")
public class QuestProofPhoto {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "post_id", nullable = false)
    private QuestProofPost post;

    @Column(name = "image_url", nullable = false, length = 500)
    private String imageUrl;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    protected QuestProofPhoto() {
    }

    QuestProofPhoto(QuestProofPost post, String imageUrl, int sortOrder) {
        this.post = post;
        this.imageUrl = imageUrl;
        this.sortOrder = sortOrder;
    }

    public Long getId() {
        return id;
    }

    /** 지연 로딩 프록시의 식별자만 읽으므로 게시물 초기화를 유발하지 않는다. */
    public Long getPostId() {
        return post.getId();
    }

    public String getImageUrl() {
        return imageUrl;
    }

    public int getSortOrder() {
        return sortOrder;
    }
}
