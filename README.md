# Delivery Dash: Paper Run

A top-down Paperboy-inspired lane runner built with Flutter + Flame. Play as a delivery rider racing through a neighbourhood route, throwing newspapers into subscriber mailboxes while dodging traffic, dogs, workers, construction hazards, puddles, and street obstacles.

## Gameplay

- **Drag** — move the rider horizontally across the road and sidewalks
- **Tap** — throw a newspaper
- Hit **blue mailboxes** for delivery points and combo bonuses
- Avoid wasting papers on non-delivery targets
- Dodge **cars, dogs, workers, cones, barriers, potholes, hydrants, trash bins, kid bikes, and manholes**
- Pick up **paper packs** to refill newspapers during the route
- Complete each day/level by riding the required route distance
- Speed increases during each day and resets higher on the next day

## Classic Paperboy Direction

The core loop is designed around accurate deliveries, route survival, and escalating street chaos:

1. Ride forward automatically through the neighbourhood.
2. Move left/right to line up with houses and avoid hazards.
3. Throw papers at subscriber mailboxes and delivery targets.
4. Build combos from accurate deliveries.
5. Survive to the next day as route speed and spawn pressure increase.

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI / Game | Flutter 3.27 + Flame 1.18 |
| Audio | flame_audio |
| Persistence | shared_preferences |
| Fonts | google_fonts |
| Ads | google_mobile_ads |
| CI/CD | GitHub Actions → Google Play internal track |

## Project Structure

```text
lib/
├── main.dart
├── game/
│   ├── delivery_dash_game.dart
│   ├── difficulty.dart
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
│   ├── game_over_screen.dart
│   └── store_screen.dart
└── services/
    ├── score_service.dart
    ├── store_service.dart
    ├── ad_service.dart
    └── audio_service.dart
```

## Spawn and Level Distance

`DeliveryDashGame` tracks two route distances:

| Field | Purpose |
|-------|---------|
| `distanceMeters` | Current day/level progress; resets when the level advances |
| `totalDistanceMeters` | Full run distance; never resets during a run and drives distance-based spawns |

This keeps paper packs, lamps, parked cars, intersections, construction zones, and cats spawning consistently after each day/level transition.

## Setup

```bash
flutter pub get
flutter run
```

## Test

```bash
flutter analyze --no-fatal-infos
flutter test
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
| `PLAY_SERVICE_ACCOUNT_JSON` | Google Play service account JSON plaintext |

## CI/CD Flow

GitHub Actions runs analyze and tests on pushes and pull requests. Pushes to `main` build a release Android App Bundle and upload it to the Google Play internal track.
