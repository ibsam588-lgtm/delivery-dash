# Delivery Dash: Paper Run

A top-down lane runner built with Flutter + Flame. Play as a delivery person racing down a neighbourhood street, throwing newspapers into mailboxes while dodging traffic, dogs, and road hazards.

## Gameplay

- **Swipe left / right** — change lanes
- **Tap** — throw a newspaper
- Hit **blue mailboxes** for +10 points (combo bonus for 3+ in a row)
- Hit **red mailboxes** for −5 points
- Dodge **cars, dogs, workers, cones, barriers, and potholes**
- Speed increases every 500 points — can you keep up?

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI / Game | Flutter 3.27 + Flame 1.18 |
| Audio | flame_audio |
| Persistence | shared_preferences |
| Fonts | google_fonts (Press Start 2P) |
| CI/CD | GitHub Actions → Google Play internal track |

## Project Structure

```
lib/
├── main.dart
├── game/
│   ├── delivery_dash_game.dart
│   ├── components/
│   │   ├── player.dart
│   │   ├── paper.dart
│   │   ├── obstacle.dart
│   │   ├── mailbox.dart
│   │   ├── house.dart
│   │   ├── hud.dart
│   │   ├── floating_text.dart
│   │   └── road_background.dart
│   └── systems/
│       ├── lane_manager.dart
│       └── spawner.dart
├── screens/
│   ├── main_menu_screen.dart
│   ├── game_screen.dart
│   └── game_over_screen.dart
└── services/
    ├── score_service.dart
    └── audio_service.dart
```

## Setup

```bash
flutter pub get
flutter run
```

## Release Build

Set up `android/key.properties` (gitignored) with your signing config:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=YOUR_KEY_ALIAS
storeFile=YOUR_KEYSTORE.jks
```

Then:

```bash
flutter build appbundle --release
```

## CI/CD Secrets Required

| Secret | Description |
|--------|-------------|
| `KEYSTORE_BASE64` | Base64-encoded `.jks` keystore |
| `KEY_ALIAS` | Key alias |
| `KEY_PASSWORD` | Key password |
| `STORE_PASSWORD` | Keystore password |
| `PLAY_SERVICE_ACCOUNT_JSON` | Google Play service account JSON (plaintext) |
