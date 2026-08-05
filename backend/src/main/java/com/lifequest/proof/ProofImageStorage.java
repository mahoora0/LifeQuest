package com.lifequest.proof;

import com.lifequest.common.exception.ErrorCode;
import com.lifequest.common.storage.ImageStorage;
import java.util.ArrayList;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

/**
 * 인증 사진 저장. 게시물 한 건이 여러 장을 올리므로 {@link ImageStorage}와 달리 묶음 단위
 * 실패 처리를 얹는다 — 다섯 장 중 네 번째에서 실패하면 앞의 세 장이 참조하는 게시물 없이
 * 디스크에 남는다. 트랜잭션이 롤백해도 파일은 되돌아오지 않으므로 여기서 직접 지운다.
 */
@Service
public class ProofImageStorage {

    private final ImageStorage storage;

    public ProofImageStorage(
            @Value("${app.upload.directory:uploads}") String uploadDirectory,
            @Value("${app.upload.max-proof-image-bytes:5242880}") long maxBytes) {
        this.storage = new ImageStorage(
                uploadDirectory,
                "proof",
                maxBytes,
                ErrorCode.INVALID_PROOF_IMAGE,
                ErrorCode.PROOF_IMAGE_UPLOAD_FAILED);
    }

    public List<String> storeAll(List<MultipartFile> files) {
        List<String> stored = new ArrayList<>(files.size());
        try {
            for (MultipartFile file : files) {
                stored.add(storage.store(file));
            }
        } catch (RuntimeException exception) {
            stored.forEach(storage::delete);
            throw exception;
        }
        return stored;
    }

    public void deleteAll(List<String> imageUrls) {
        imageUrls.forEach(storage::delete);
    }
}
