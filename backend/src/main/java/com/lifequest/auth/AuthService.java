package com.lifequest.auth;

import com.lifequest.auth.GoogleTokenVerifier.GoogleIdentity;
import com.lifequest.auth.dto.AuthTokenResponse;
import com.lifequest.auth.dto.GoogleLoginRequest;
import com.lifequest.auth.dto.LoginRequest;
import com.lifequest.auth.dto.ReissueRequest;
import com.lifequest.auth.dto.SignupRequest;
import com.lifequest.auth.dto.SignupResponse;
import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import com.lifequest.social.SocialAccount;
import com.lifequest.social.SocialAccountRepository;
import com.lifequest.social.SocialProvider;
import com.lifequest.user.User;
import com.lifequest.user.UserRepository;
import java.time.Instant;
import java.util.Locale;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final SocialAccountRepository socialAccountRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenService jwtTokenService;
    private final GoogleTokenVerifier googleTokenVerifier;

    public AuthService(
            UserRepository userRepository,
            SocialAccountRepository socialAccountRepository,
            RefreshTokenRepository refreshTokenRepository,
            PasswordEncoder passwordEncoder,
            JwtTokenService jwtTokenService,
            GoogleTokenVerifier googleTokenVerifier) {
        this.userRepository = userRepository;
        this.socialAccountRepository = socialAccountRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtTokenService = jwtTokenService;
        this.googleTokenVerifier = googleTokenVerifier;
    }

    @Transactional
    public SignupResponse signup(SignupRequest request) {
        String email = normalizeEmail(request.email());
        if (userRepository.existsByEmailIgnoreCase(email)) {
            throw new BusinessException(ErrorCode.DUPLICATE_EMAIL);
        }
        if (userRepository.existsByNickname(request.nickname())) {
            throw new BusinessException(ErrorCode.DUPLICATE_NICKNAME);
        }

        User user = userRepository.save(User.local(
                email,
                passwordEncoder.encode(request.password()),
                request.nickname()));
        return SignupResponse.from(user);
    }

    @Transactional
    public AuthTokenResponse login(LoginRequest request) {
        User user = userRepository.findByEmailIgnoreCase(normalizeEmail(request.email()))
                .orElseThrow(() -> new BusinessException(ErrorCode.INVALID_CREDENTIALS));
        if (user.getPasswordHash() == null
                || !passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw new BusinessException(ErrorCode.INVALID_CREDENTIALS);
        }
        return jwtTokenService.issue(user);
    }

    @Transactional
    public AuthTokenResponse googleLogin(GoogleLoginRequest request) {
        GoogleIdentity identity = googleTokenVerifier.verify(request.idToken());

        User user = socialAccountRepository
                .findByProviderAndProviderUserId(SocialProvider.GOOGLE, identity.subject())
                .map(SocialAccount::getUser)
                .orElseGet(() -> createOrLinkGoogleUser(identity));

        return jwtTokenService.issue(user);
    }

    @Transactional
    public AuthTokenResponse reissue(ReissueRequest request) {
        RefreshToken token = refreshTokenRepository
                .findByTokenHashForUpdate(JwtTokenService.hash(request.refreshToken()))
                .orElseThrow(() -> new BusinessException(ErrorCode.TOKEN_EXPIRED));
        Instant now = Instant.now();
        if (!token.isActive(now)) {
            throw new BusinessException(ErrorCode.TOKEN_EXPIRED);
        }

        token.revoke(now);
        return jwtTokenService.issue(token.getUser());
    }

    @Transactional
    public void logout(ReissueRequest request) {
        refreshTokenRepository
                .findByTokenHashForUpdate(JwtTokenService.hash(request.refreshToken()))
                .filter(token -> token.isActive(Instant.now()))
                .ifPresent(token -> token.revoke(Instant.now()));
    }

    private User createOrLinkGoogleUser(GoogleIdentity identity) {
        String email = normalizeEmail(identity.email());
        User user = userRepository.findByEmailIgnoreCase(email)
                .orElseGet(() -> userRepository.save(User.google(
                        email,
                        uniqueNickname(identity.name(), email),
                        identity.pictureUrl())));

        if (!socialAccountRepository.existsByUserIdAndProvider(user.getId(), SocialProvider.GOOGLE)) {
            socialAccountRepository.save(new SocialAccount(
                    user,
                    SocialProvider.GOOGLE,
                    identity.subject()));
        }
        return user;
    }

    private String uniqueNickname(String name, String email) {
        String source = name == null || name.isBlank()
                ? email.substring(0, email.indexOf('@'))
                : name;
        String cleaned = source.replaceAll("[^가-힣a-zA-Z0-9_]", "");
        if (cleaned.length() < 2) {
            cleaned = "모험가";
        }
        String base = cleaned.substring(0, Math.min(cleaned.length(), 16));
        String candidate = base;
        int suffix = 1;
        while (userRepository.existsByNickname(candidate)) {
            candidate = base + suffix++;
        }
        return candidate;
    }

    private String normalizeEmail(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }
}
