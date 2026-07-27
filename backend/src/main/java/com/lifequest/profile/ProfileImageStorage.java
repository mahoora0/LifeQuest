package com.lifequest.profile;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Map;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

@Service
public class ProfileImageStorage {

    private static final Map<String, String> EXTENSIONS = Map.of(
            "image/jpeg", ".jpg",
            "image/png", ".png",
            "image/webp", ".webp");

    private final Path profileDirectory;
    private final long maxBytes;

    public ProfileImageStorage(
            @Value("${app.upload.directory:uploads}") String uploadDirectory,
            @Value("${app.upload.max-profile-image-bytes:5242880}") long maxBytes) {
        this.profileDirectory = Path.of(uploadDirectory)
                .toAbsolutePath()
                .normalize()
                .resolve("profile");
        this.maxBytes = maxBytes;
    }

    public String store(MultipartFile file) {
        String extension = EXTENSIONS.get(file.getContentType());
        if (file.isEmpty() || file.getSize() > maxBytes || extension == null) {
            throw new BusinessException(ErrorCode.INVALID_PROFILE_IMAGE);
        }

        try {
            Files.createDirectories(profileDirectory);
            String fileName = UUID.randomUUID() + extension;
            Path destination = profileDirectory.resolve(fileName).normalize();
            if (!destination.getParent().equals(profileDirectory)) {
                throw new BusinessException(ErrorCode.INVALID_PROFILE_IMAGE);
            }
            Files.copy(file.getInputStream(), destination, StandardCopyOption.REPLACE_EXISTING);
            return "/uploads/profile/" + fileName;
        } catch (IOException exception) {
            throw new BusinessException(ErrorCode.PROFILE_IMAGE_UPLOAD_FAILED);
        }
    }

    public void delete(String imageUrl) {
        if (imageUrl == null || !imageUrl.startsWith("/uploads/profile/")) {
            return;
        }
        String fileName = imageUrl.substring("/uploads/profile/".length());
        Path target = profileDirectory.resolve(fileName).normalize();
        if (!target.getParent().equals(profileDirectory)) {
            return;
        }
        try {
            Files.deleteIfExists(target);
        } catch (IOException ignored) {
            // DB 상태 변경은 파일 정리 실패 때문에 막지 않는다.
        }
    }

    public Path uploadRoot() {
        return profileDirectory.getParent();
    }
}
