package com.lifequest.auth;

import com.lifequest.auth.dto.AuthTokenResponse;
import com.lifequest.auth.dto.GoogleLoginRequest;
import com.lifequest.auth.dto.LoginRequest;
import com.lifequest.auth.dto.ReissueRequest;
import com.lifequest.auth.dto.SignupRequest;
import com.lifequest.auth.dto.SignupResponse;
import com.lifequest.common.response.ApiResponse;
import jakarta.validation.Valid;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/signup")
    public ResponseEntity<ApiResponse<SignupResponse>> signup(
            @Valid @RequestBody SignupRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(authService.signup(request)));
    }

    @PostMapping("/login")
    public ApiResponse<AuthTokenResponse> login(@Valid @RequestBody LoginRequest request) {
        return ApiResponse.success(authService.login(request));
    }

    @PostMapping("/google")
    public ApiResponse<AuthTokenResponse> googleLogin(
            @Valid @RequestBody GoogleLoginRequest request) {
        return ApiResponse.success(authService.googleLogin(request));
    }

    @PostMapping("/reissue")
    public ApiResponse<AuthTokenResponse> reissue(@Valid @RequestBody ReissueRequest request) {
        return ApiResponse.success(authService.reissue(request));
    }

    @PostMapping("/logout")
    public ApiResponse<Map<String, Boolean>> logout(@Valid @RequestBody ReissueRequest request) {
        authService.logout(request);
        return ApiResponse.success(Map.of("loggedOut", true));
    }
}
