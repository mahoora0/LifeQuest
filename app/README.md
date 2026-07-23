# LifeQuest App

Flutter mobile application for Android and iOS.

Run against a locally running backend:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8080/api
```

For the Android emulator, use `http://10.0.2.2:8080/api`. A real device needs
the development machine's LAN address.

The map screen is intentionally a placeholder. Choose a map SDK before adding
provider-specific packages, keys, or native configuration.
