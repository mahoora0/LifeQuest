# LifeQuest API

Spring Boot API server for LifeQuest.

Run from this directory:

```bash
# Windows
.\gradlew.bat bootRun

# macOS
./gradlew bootRun
```

The application automatically imports the repository root `.env` through Spring
Boot Config Data. It works when launched from either `backend/` or the repository
root. OS environment variables and command-line arguments take precedence.

See [`../docs/08-local-run-guide.md`](../docs/08-local-run-guide.md) for Docker
and locally installed MySQL setup, environment variables, and troubleshooting.

Public smoke endpoints:

- `GET /actuator/health`
- `GET /api/system/ping`

## Production deployment

The backend includes a production Docker image and Railway deployment settings.
Set the service root directory to `backend` and provide these variables in the
deployment platform instead of committing a `.env` file:

- `DB_URL` (for example, `jdbc:mysql://mysql.railway.internal:3306/railway?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC`)
- `DB_USERNAME`
- `DB_PASSWORD`
- `JWT_SECRET` (at least 32 random bytes)
- `CORS_ALLOWED_ORIGINS`

Optional variables include `GOOGLE_CLIENT_ID`, `OPENAI_API_KEY`, `GEMINI_API_KEY`,
and `UPLOAD_DIRECTORY`. The container enables the `production` profile and reads
the platform-provided `PORT` automatically. Use `/actuator/health` for health
checks. If uploaded images must survive redeployments, mount a persistent volume
at `/app/uploads` or configure external object storage before production use.
