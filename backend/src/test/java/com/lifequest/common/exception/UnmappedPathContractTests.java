package com.lifequest.common.exception;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

/**
 * 아직 만들지 않은 경로가 무엇을 돌려주는지는 클라이언트와의 계약이다.
 *
 * <p>앱은 이 응답을 보고 "서버가 죽었다"와 "그 기능이 아직 없다"를 가른다. 후자는
 * 재시도해도 결과가 같아 오류 화면 대신 준비 중 안내를 띄우고, 개발 중에는 검토용
 * 표본으로 떨어진다. 실기기에서 확인해 보니 포괄 예외 핸들러가 스프링의
 * {@code NoResourceFoundException}까지 삼켜 <b>500</b>을 내보내고 있었고, 그래서
 * 앱의 준비 중 안내가 한 번도 뜨지 않고 40초 로딩 뒤 "서버 오류"만 보였다.
 * 같은 일이 되돌아오지 않도록 여기에 고정한다.
 */
@SpringBootTest
@ActiveProfiles("test")
@AutoConfigureMockMvc
class UnmappedPathContractTests {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void unmappedPathAnswersNotFoundWithEndpointCode() throws Exception {
        // 인증을 통과한 뒤에야 디스패처까지 도달하므로 토큰을 먼저 얻는다.
        String accessToken = signUpAndGetAccessToken("unmapped@lifequest.test", "길잃은모험가");

        mockMvc.perform(get("/api/lifedex/categories").header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("ENDPOINT_NOT_FOUND"));
    }

    @Test
    void unmappedPathIsNotReportedAsServerError() throws Exception {
        String accessToken = signUpAndGetAccessToken("unmapped2@lifequest.test", "두번째모험가");

        // 500으로 나가면 앱이 재시도를 돌리고(5xx는 재시도 대상) 장애 집계도 오염된다.
        mockMvc.perform(get("/api/definitely-not-here").header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("ENDPOINT_NOT_FOUND"));
    }

    @Test
    void mappedPathKeepsAnsweringNormally() throws Exception {
        // 대조군 — 살아 있는 경로까지 404로 바뀌지 않았는지 확인한다.
        String accessToken = signUpAndGetAccessToken("mapped@lifequest.test", "제자리모험가");

        mockMvc.perform(get("/api/users/me").header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));
    }

    private String signUpAndGetAccessToken(String email, String nickname) throws Exception {
        mockMvc.perform(post("/api/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "%s",
                                  "password": "password123",
                                  "nickname": "%s"
                                }
                                """.formatted(email, nickname)))
                .andExpect(status().isCreated());

        MvcResult login = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "%s",
                                  "password": "password123"
                                }
                                """.formatted(email)))
                .andExpect(status().isOk())
                .andReturn();

        return JsonPath.read(login.getResponse().getContentAsString(), "$.data.accessToken");
    }
}
