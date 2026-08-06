FROM eclipse-temurin:17-jdk-jammy AS builder

WORKDIR /workspace

COPY gradle gradle
COPY gradlew settings.gradle build.gradle ./
RUN chmod +x gradlew && ./gradlew --no-daemon dependencies

COPY src src
RUN ./gradlew --no-daemon clean bootJar

FROM eclipse-temurin:17-jre-jammy

WORKDIR /app

RUN groupadd --system lifequest \
    && useradd --system --gid lifequest --home-dir /app lifequest \
    && mkdir -p /app/uploads \
    && chown -R lifequest:lifequest /app

COPY --from=builder --chown=lifequest:lifequest /workspace/build/libs/*.jar app.jar

USER lifequest

ENV PORT=8080 \
    SPRING_PROFILES_ACTIVE=production \
    UPLOAD_DIRECTORY=/app/uploads

EXPOSE 8080

ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-Djava.security.egd=file:/dev/./urandom", "-jar", "/app/app.jar"]
