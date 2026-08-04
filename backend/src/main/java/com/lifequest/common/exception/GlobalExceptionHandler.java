package com.lifequest.common.exception;

import com.lifequest.common.response.ApiResponse;
import jakarta.validation.ConstraintViolationException;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.resource.NoResourceFoundException;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiResponse<Void>> handleBusinessException(BusinessException exception) {
        ErrorCode errorCode = exception.errorCode();
        // 예외가 들고 온 메시지를 쓴다. 기본 생성자는 여기에 errorCode.message() 를
        // 넣으므로 기존 동작은 그대로고, 상황값을 실은 경우에만 달라진다.
        String message = exception.getMessage() != null
                ? exception.getMessage()
                : errorCode.message();
        return ResponseEntity.status(errorCode.status())
                .body(ApiResponse.failure(errorCode.code(), message));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiResponse<Void>> handleValidationException(
            MethodArgumentNotValidException exception) {
        String message = exception.getBindingResult().getFieldErrors().stream()
                .findFirst()
                .map(error -> error.getDefaultMessage())
                .orElse(ErrorCode.INVALID_REQUEST.message());

        return ResponseEntity.badRequest()
                .body(ApiResponse.failure(ErrorCode.VALIDATION_FAILED.code(), message));
    }

    @ExceptionHandler({ConstraintViolationException.class, HttpMessageNotReadableException.class})
    public ResponseEntity<ApiResponse<Void>> handleInvalidRequest(Exception exception) {
        ErrorCode errorCode = ErrorCode.VALIDATION_FAILED;
        return ResponseEntity.badRequest()
                .body(ApiResponse.failure(errorCode.code(), errorCode.message()));
    }

    /**
     * 매핑된 컨트롤러가 없는 경로.
     *
     * <p>이 핸들러가 없으면 아래 {@code Exception} 포괄 핸들러가 스프링의
     * {@link NoResourceFoundException}까지 삼켜 <b>500</b>으로 내보낸다. 그러면
     * 클라이언트는 "서버가 죽었다"와 "그 기능이 아직 없다"를 구분할 수 없다.
     * 실제로 앱이 아직 열리지 않은 구간(도감·업적·퀘스트)에서 준비 중 안내 대신
     * 서버 오류를 띄웠고, 5xx는 재시도 대상이라 40초 가까이 로딩만 돌았다.
     * 없는 경로가 5xx로 집계되면 장애 모니터링도 함께 오염된다.
     *
     * @param exception 스프링이 미매핑 경로에서 던진 예외
     * @return 404 {@code ENDPOINT_NOT_FOUND}
     */
    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ApiResponse<Void>> handleNoResourceFound(
            NoResourceFoundException exception) {
        ErrorCode errorCode = ErrorCode.ENDPOINT_NOT_FOUND;
        return ResponseEntity.status(errorCode.status())
                .body(ApiResponse.failure(errorCode.code(), errorCode.message()));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleUnexpectedException(Exception exception) {
        ErrorCode errorCode = ErrorCode.INTERNAL_SERVER_ERROR;
        return ResponseEntity.status(errorCode.status())
                .body(ApiResponse.failure(errorCode.code(), errorCode.message()));
    }
}
