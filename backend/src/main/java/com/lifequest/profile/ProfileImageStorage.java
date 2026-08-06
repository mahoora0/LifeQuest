package com.lifequest.profile;

import com.lifequest.common.exception.ErrorCode;
import com.lifequest.common.storage.ImageStorage;
import java.nio.file.Path;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

/** 프로필 이미지 저장. 검증과 경로 처리는 {@link ImageStorage}가 맡는다. */
@Service
public class ProfileImageStorage {

    private final ImageStorage storage;

    public ProfileImageStorage(
            @Value("${app.upload.directory:uploads}") String uploadDirectory,
            @Value("${app.upload.max-profile-image-bytes:5242880}") long maxBytes) {
        this.storage = new ImageStorage(
                uploadDirectory,
                "profile",
                maxBytes,
                ErrorCode.INVALID_PROFILE_IMAGE,
                ErrorCode.PROFILE_IMAGE_UPLOAD_FAILED);
    }

    public String store(MultipartFile file) {
        return storage.store(file);
    }

    public void delete(String imageUrl) {
        storage.delete(imageUrl);
    }

    public Path uploadRoot() {
        return storage.uploadRoot();
    }
}
