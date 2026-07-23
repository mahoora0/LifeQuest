# LifeQuest API

Spring Boot API server for LifeQuest.

Run from this directory:

```bash
./gradlew bootRun
```

The application reads database and JWT settings from the root `.env` values.
Spring Boot does not load `.env` automatically, so export them in your shell or
use the documented defaults for local development.

Public smoke endpoints:

- `GET /actuator/health`
- `GET /api/system/ping`
