# Medsafe – Intelligent Medication Safety & Adherence Monitoring System

Medsafe is a modern healthcare application built with Flutter that empowers users to manage medications safely and effectively. The platform combines intelligent medication reminders, adherence monitoring, drug interaction detection, and health analytics to improve treatment compliance and patient safety.

The application leverages Supabase for secure authentication and cloud storage while integrating OpenFDA and RxNorm APIs to provide reliable medication information and interaction checking. Through an intuitive interface, users can organize prescriptions, receive timely notifications, monitor medication adherence, and gain actionable insights into their treatment progress.

## 🚀 Key Features

- 💊 Prescription & Medication Management
- ⏰ Smart Medication Reminders
- 📊 Adherence Tracking & Analytics
- ⚠️ Drug Interaction Detection
- 🔐 Secure User Authentication
- ☁️ Cloud Data Synchronization
- 🌙 Dark Mode Support
- 📱 Cross-Platform Compatibility (Android, iOS, Web, Desktop)

## 🛠️ Tech Stack

### Frontend
- Flutter
- Dart

### Backend
- Supabase

### Database
- PostgreSQL

### Authentication
- Supabase Auth

### State Management
- Provider

### Charts & Analytics
- fl_chart

### Notifications
- flutter_local_notifications

### Medical APIs
- OpenFDA
- RxNorm

## 🎯 Goal

To improve medication safety, increase treatment adherence, and provide users with a reliable digital healthcare companion for managing daily medications and prescriptions.

---

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
   Replace credintials in lib/main.dart:

   ```bash
   await Supabase.initialize(
     url: 'https://...supabase.co',
     anonKey: 'sb_publishable_...',
   );
   ```

## How to Build the APK

To generate a production-ready Android application package (APK), run:

```bash
flutter build apk --release
```

The compiled APK will be available in `build/app/outputs/flutter-apk/app-release.apk`.
