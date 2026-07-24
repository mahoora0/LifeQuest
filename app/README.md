# LifeQuest App

Flutter mobile application for Android and iOS.

See [`../docs/08-local-run-guide.md`](../docs/08-local-run-guide.md) for the
complete Windows/macOS and Android/iOS setup and troubleshooting guide.

Set `GOOGLE_CLIENT_ID` in the repository root `.env`, then run from the
repository root:

In IntelliJ IDEA or Android Studio, select the shared `LifeQuest Flutter` run
configuration and click Run. The same launcher can be used from a terminal:

```bash
cd app
flutter pub get
cd ..
dart run tool/run_app.dart
```

The runner selects the only connected Android/iOS mobile device. Use a target
filter when more than one device is available:

```bash
dart run tool/run_app.dart --target emulator
dart run tool/run_app.dart --target usb
dart run tool/run_app.dart --target ios
```

For a device connected over Wi-Fi or a physical iOS device, set
`FLUTTER_API_BASE_URL=http://YOUR_PC_LAN_IP:8080/api` in the root `.env` and
run `dart run tool/run_app.dart --lan`.

The runner checks Flutter 3.44.8 and passes only the public API URL and Google
web client ID to Flutter.
Database passwords, JWT secrets, and OAuth client secrets are never bundled
into the app. See `../docs/07-auth-setup.md` for native OAuth setup.

The map screen is intentionally a placeholder. Choose a map SDK before adding
provider-specific packages, keys, or native configuration.
