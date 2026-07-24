# LifeQuest API

Spring Boot API server for LifeQuest.

Run from this directory on Windows:

```powershell
.\gradlew.bat bootRun
```

The application automatically imports the repository root `.env` through Spring
Boot Config Data. It works when launched from either `backend/` or the repository
root. OS environment variables and command-line arguments take precedence.

See [`../docs/08-local-run-guide.md`](../docs/08-local-run-guide.md) for Docker
and locally installed MySQL setup, environment variables, and troubleshooting.

Public smoke endpoints:

- `GET /actuator/health`
- `GET /api/system/ping`
