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
