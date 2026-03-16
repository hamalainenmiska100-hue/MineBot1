# MineBot iOS source

Flat-file SwiftUI source for the MineBot iOS app.

## Files
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

## How to use
1. Create a new **iOS App** project in Xcode.
2. Delete the default Swift files.
3. Drag all `.swift` files from this zip into your Xcode project target.
4. Build and run.

## Notes
- API base URL is set in `API.swift`.
- Token is stored in Keychain.
- Saved servers are stored in `UserDefaults`.
- The app is English-only.
- Designed to fit small displays like iPhone SE 3 by using `ScrollView`, `List`, and flexible layouts.

## Current backend endpoints used
- `POST /auth/redeem`
- `GET /auth/me`
- `GET /accounts`
- `POST /accounts/link/start`
- `GET /accounts/link/status`
- `POST /accounts/unlink`
- `POST /bots/start`
- `POST /bots/stop`
- `POST /bots/reconnect`
- `GET /bots`
- `GET /health`
