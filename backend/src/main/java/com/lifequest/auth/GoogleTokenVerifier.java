package com.lifequest.auth;

import com.lifequest.common.exception.BusinessException;
import com.lifequest.common.exception.ErrorCode;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.security.oauth2.jwt.JwtTimestampValidator;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.stereotype.Component;

@Component
public class GoogleTokenVerifier {

    private static final String GOOGLE_ISSUER = "https://accounts.google.com";
    private static final String GOOGLE_JWK_SET_URI = "https://www.googleapis.com/oauth2/v3/certs";

    private final String clientId;
    private volatile JwtDecoder decoder;

    public GoogleTokenVerifier(@Value("${app.google.client-id:}") String clientId) {
        this.clientId = clientId.trim();
    }

    public GoogleIdentity verify(String idToken) {
        if (clientId.isBlank()) {
            throw new BusinessException(ErrorCode.AUTH_PROVIDER_NOT_CONFIGURED);
        }

        try {
            Jwt jwt = decoder().decode(idToken);
            String email = jwt.getClaimAsString("email");
            Boolean emailVerified = jwt.getClaim("email_verified");
            if (jwt.getSubject() == null
                    || jwt.getSubject().isBlank()
                    || email == null
                    || !Boolean.TRUE.equals(emailVerified)) {
                throw new BusinessException(ErrorCode.INVALID_GOOGLE_TOKEN);
            }
            return new GoogleIdentity(
                    jwt.getSubject(),
                    email,
                    jwt.getClaimAsString("name"),
                    jwt.getClaimAsString("picture"));
        } catch (JwtException exception) {
            throw new BusinessException(ErrorCode.INVALID_GOOGLE_TOKEN);
        }
    }

    private JwtDecoder decoder() {
        JwtDecoder current = decoder;
        if (current != null) {
            return current;
        }
        synchronized (this) {
            if (decoder == null) {
                NimbusJwtDecoder nimbus = NimbusJwtDecoder.withJwkSetUri(GOOGLE_JWK_SET_URI).build();
                OAuth2TokenValidator<Jwt> audience = token -> {
                    List<String> audiences = token.getAudience();
                    if (audiences.contains(clientId)) {
                        return OAuth2TokenValidatorResult.success();
                    }
                    return OAuth2TokenValidatorResult.failure(new OAuth2Error(
                            "invalid_token",
                            "Google token audience does not match",
                            null));
                };
                OAuth2TokenValidator<Jwt> issuer = token -> {
                    String value = token.getIssuer() == null
                            ? ""
                            : token.getIssuer().toString();
                    if (value.equals(GOOGLE_ISSUER) || value.equals("accounts.google.com")) {
                        return OAuth2TokenValidatorResult.success();
                    }
                    return OAuth2TokenValidatorResult.failure(new OAuth2Error(
                            "invalid_token",
                            "Google token issuer does not match",
                            null));
                };
                nimbus.setJwtValidator(new DelegatingOAuth2TokenValidator<>(
                        new JwtTimestampValidator(),
                        issuer,
                        audience));
                decoder = nimbus;
            }
            return decoder;
        }
    }

    public record GoogleIdentity(String subject, String email, String name, String pictureUrl) {
    }
}
