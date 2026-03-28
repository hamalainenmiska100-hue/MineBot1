# MineBot source

Flat-file source for the MineBot clients.

## iOS files
- `MineBotApp.swift`
- `Models.swift`
- `API.swift`
- `AppModel.swift`
- `Keychain.swift`
- `Haptics.swift`
- `ServerStore.swift`
- `Snackbar.swift`
- `CommonViews.swift`
- `TutorialView.swift`
- `LoginView.swift`
- `BotView.swift`
- `StatusView.swift`
- `SettingsView.swift`
- `AddServerView.swift`

## Android app
An Android app with the same feature set is included under `android/`.

### Android features implemented
- Tutorial/onboarding flow.
- Access-code login/logout.
- Bot tab: server selection, connection mode, offline username, Microsoft linking flow, start/stop/reconnect actions.
- Status tab: session snapshot, uptime, last-connected time, health metrics.
- Settings tab: add/select/remove servers, Discord link, sign-out.
- Remote bootstrap support for maintenance and announcements.

### Build Android app
1. Open the `android/` folder in Android Studio (JDK 17).
2. Let Gradle sync.
3. Run the `app` configuration on a device/emulator.

## Current backend endpoints used
- `POST /auth/redeem`
- `POST /auth/logout`
- `GET /accounts`
- `POST /accounts/link/start`
- `GET /accounts/link/status`
- `POST /accounts/unlink`
- `POST /bots/start`
- `POST /bots/stop`
- `POST /bots/reconnect`
- `GET /bots`
- `GET /health`
- `GET /api/bootstrap` (announcement service)

## Flutter Web app
A Flutter Web implementation with the same core feature set as iOS/Android is included under `flutter_web/`.

### Flutter Web features implemented
- Tutorial/onboarding flow.
- Access-code login/logout.
- Bot tab: server selection, connection mode, offline username, Microsoft linking flow, start/stop/reconnect actions.
- Status tab: session snapshot, uptime, last-connected time, health metrics.
- Settings tab: add/select/remove servers, Discord link, sign-out.
- Remote bootstrap support for maintenance and announcements.

### Run locally (web)
1. Install Flutter stable and run `flutter config --enable-web`.
2. `cd flutter_web`
3. `flutter pub get`
4. `flutter run -d chrome`

### GitHub Pages deployment
A workflow is configured at `.github/workflows/flutter-web-pages.yml`.

Required one-time repo settings:
1. In GitHub repository settings, go to **Pages** and set source to **GitHub Actions**.
2. Keep the default branch trigger (`main`) or edit the workflow as needed.

Then push changes to `main`; the workflow builds `flutter_web` and deploys to Pages.

### Flutter Android build from `flutter_web/`
A workflow is configured at `.github/workflows/flutter-android-build.yml`.

Android behavior:
- The Flutter app runs the full MineBot client on web.
- On Android builds, it acts as a lightweight WebView wrapper for: `https://hamalainenmiska100-hue.github.io/MineBot1/`.

What it does:
1. Installs Java 17 + Flutter.
2. Runs `flutter pub get` in `flutter_web/`.
3. Generates Android platform files with `flutter create --platforms=android .`.
4. Builds a release APK (`flutter build apk --release`).
5. Uploads the APK as a workflow artifact (`minebot-web-android-apk`).
