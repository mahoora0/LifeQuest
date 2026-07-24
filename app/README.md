# LifeQuest App

Flutter mobile application for Android and iOS.

See [`../docs/08-local-run-guide.md`](../docs/08-local-run-guide.md) for the
complete Windows/Android setup and troubleshooting guide.

Set `GOOGLE_CLIENT_ID` in the repository root `.env`, then run from the
repository root:

```powershell
cd app
flutter pub get
cd ..
.\run-app.ps1
```

The default target is an Android emulator and uses `10.0.2.2`. For a physical
Android device connected over USB, the script configures `adb reverse`, so no
per-PC IP address is needed:

```powershell
.\run-app.ps1 -Target usb
```

For a device connected over Wi-Fi, set
`FLUTTER_API_BASE_URL=http://YOUR_PC_LAN_IP:8080/api` in the root `.env` and
run `.\run-app.ps1 -Target lan`.

The script passes only the public API URL and Google web client ID to Flutter.
Database passwords, JWT secrets, and OAuth client secrets are never bundled
into the app. See `../docs/07-auth-setup.md` for native OAuth setup.

The map screen is intentionally a placeholder. Choose a map SDK before adding
provider-specific packages, keys, or native configuration.
