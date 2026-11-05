# Minimal Weather

A minimalist Android weather app (Flutter). Search a place, see its name, a
weather icon and the temperature. Light and dark mode (follows the phone, with
a toggle in the corner). Data comes from Open-Meteo: free, no API key.

## Get the APK

**Option A: on your computer** (Flutter stable + Android SDK installed)

    bash build_apk.sh

The APK appears at `build/app/outputs/flutter-apk/app-release.apk`.

**Option B: no setup, via GitHub**

1. Create an empty GitHub repo and push this folder to its `main` branch.
2. Open the repo's **Actions** tab, run **Build APK** (it also runs on push).
3. Download the `weather-apk` artifact and unzip it.

Copy the APK to your phone and open it (allow "install unknown apps" when asked).

## Layout

- `lib/main.dart`: UI, theming, search bar
- `lib/weather_service.dart`: place lookup + current weather
- `lib/weather_code.dart`: weather code to icon / label / colour
- `test/`: unit tests for the service and icon mapping
