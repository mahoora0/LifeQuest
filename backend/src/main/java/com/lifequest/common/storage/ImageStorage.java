package com.lifequest.common.storage;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Map;
import java.util.UUID;
import org.springframework.web.multipart.MultipartFile;

/**
 * {@code uploads/} 아래 한 하위 디렉터리에 이미지를 저장한다. 프로필 사진과 인증 사진이
 * 같은 검증을 쓴다.
 *
 * <p>공통으로 뺀 것은 편의 때문이 아니라 <b>경로 이탈 검증</b> 때문이다. 저장 위치를 늘릴
 * 때마다 이 검증을 복사하면 어느 한 곳에서 빠뜨렸을 때 파일명에 담긴 {@code ../}가 업로드
 * 디렉터리 밖에 파일을 쓰게 된다. 검증이 한 군데에만 있으면 빠뜨릴 자리가 없다.
 *
 * <p>확장자는 요청이 알려온 content type에서만 정하고 원본 파일명은 쓰지 않는다. 저장 이름은
 * 항상 새 UUID다.
 */
public class ImageStorage {

    private static final Map<String, String> EXTENSIONS = Map.of(
            "image/jpeg", ".jpg",
            "image/png", ".png",
            "image/webp", ".webp");

    private final Path directory;
    private final String urlPrefix;
    private final long maxBytes;
    private final ErrorCode invalidImage;
    private final ErrorCode uploadFailed;

    public ImageStorage(
            String uploadDirectory,
            String subdirectory,
            long maxBytes,
            ErrorCode invalidImage,
            ErrorCode uploadFailed) {

        this.directory = Path.of(uploadDirectory)
                .toAbsolutePath()
                .normalize()
                .resolve(subdirectory);
        this.urlPrefix = "/uploads/" + subdirectory + "/";
        this.maxBytes = maxBytes;
        this.invalidImage = invalidImage;
        this.uploadFailed = uploadFailed;
    }

    public String store(MultipartFile file) {
        String extension = EXTENSIONS.get(file.getContentType());
        if (file.isEmpty() || file.getSize() > maxBytes || extension == null) {
            throw new BusinessException(invalidImage);
        }

        try {
            Files.createDirectories(directory);
            String fileName = UUID.randomUUID() + extension;
            Path destination = directory.resolve(fileName).normalize();
            if (!destination.getParent().equals(directory)) {
                throw new BusinessException(invalidImage);
            }
            Files.copy(file.getInputStream(), destination, StandardCopyOption.REPLACE_EXISTING);
            return urlPrefix + fileName;
        } catch (IOException exception) {
            throw new BusinessException(uploadFailed);
        }
    }

    public void delete(String imageUrl) {
        if (imageUrl == null || !imageUrl.startsWith(urlPrefix)) {
            return;
        }
        String fileName = imageUrl.substring(urlPrefix.length());
        Path target = directory.resolve(fileName).normalize();
        if (!target.getParent().equals(directory)) {
            return;
        }
        try {
            Files.deleteIfExists(target);
        } catch (IOException ignored) {
            // DB 상태 변경은 파일 정리 실패 때문에 막지 않는다.
        }
    }

    public Path uploadRoot() {
        return directory.getParent();
    }
}
