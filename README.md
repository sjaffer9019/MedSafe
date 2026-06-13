# Medsafe – Intelligent Medication Safety & Adherence Monitoring System

This project contains the complete source code for Medsafe.

## Project Structure
The code is structured cleanly under `lib/`:
- `core/`: Themes, constants, and color definitions.
- `models/`: Data classes (`Medicine`, `Adherence`, `Alert`).
- `providers/`: State management via Provider.
- `screens/`: Application UI screens.
- `services/`: SQLite (`database_service`), Local Notifications, and Logic.
- `widgets/`: Reusable components.

## How to Run the Project

1. **Install Flutter**: Make sure you have the latest stable Flutter SDK installed and added to your system `PATH`.
2. **Create the Project Shell**: Since the `android`/`ios` platform folders were not built by `flutter create` directly (due to SDK availability in this terminal), you can generate them by running:
   ```bash
   flutter create .
   ```
   *Run this command inside this project directory (`c:/Users/Dell/Music/Medicare`). It will preserve the `lib/` and `pubspec.yaml` we created but generate the necessary platform runners.*
3. **Download Dependencies**:
   ```bash
   flutter pub get
   ```
4. **Run the App**:
   Connect an emulator or a physical device and execute:
   ```bash
   flutter run
   ```

## How to Build the APK
To generate a production-ready Android application package (APK), run:

```bash
flutter build apk --release
```
The compiled APK will be available in `build/app/outputs/flutter-apk/app-release.apk`.
