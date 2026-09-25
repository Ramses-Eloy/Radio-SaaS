# Radio White-Label Platform

A complete, highly customizable white-label internet radio platform built with Flutter and Firebase. This project includes both a cross-platform mobile/web application for listeners and a powerful web dashboard for station administrators and superadmins.

## 🚀 Overview

The Radio White-Label platform is designed to host multiple radio stations from a single codebase, dynamically adapting its UI, streams, and content based on the station's configuration in Firebase.

### 📱 The Listener App (Mobile & Web)
- **Audio Streaming:** High-quality background audio playback using `just_audio` and `audio_service`.
- **Dynamic Theming:** UI colors, logos, and typography adapt automatically to the specific radio station's brand.
- **Social & Interactive:** Integrated social network links, WhatsApp direct messaging, and share features.
- **Video & PIP:** Support for live video streams (e.g., YouTube) with Picture-in-Picture mode for seamless multitasking.
- **Telemetry:** Anonymous tracking of active listeners, session durations, and concurrent connections to provide real-time stats.

### 💻 The Web Dashboard
- **Superadmin Panel:** Manage multiple radio stations (brands), create station admin accounts, and oversee the entire platform.
- **Station Admin Panel:** 
  - Manage streaming URLs (Audio & Video).
  - Update branding (logos, primary/secondary colors).
  - Configure social media links and contact info.
  - View real-time and historical analytics (active listeners, peak times, connection duration) powered by Firestore and Cloud Functions.
  - Manage schedule, team members, and news/banners.

## 🛠 Tech Stack

- **Frontend:** [Flutter](https://flutter.dev/) (iOS, Android, Web, Desktop)
- **Audio/Video Processing:** `just_audio`, `just_audio_background`, `youtube_player_flutter`, `video_player`
- **Backend/BaaS:** [Firebase](https://firebase.google.com/)
  - **Firestore:** Real-time NoSQL database for app configuration, telemetry data, and user roles.
  - **Firebase Auth:** Secure login for Superadmins and Station Admins.
  - **Firebase Storage:** Hosting logos, banners, and other media assets.
  - **Cloud Functions:** Node.js functions to process telemetry, aggregate statistics, and clean up stale connections.
- **Analytics & Charts:** `fl_chart` for visualizing listener data in the dashboard.
- **Reports:** `pdf`, `printing`, and `csv` packages for exporting statistics.

## 📂 Project Structure

- `lib/`
  - `models/`: Data models (Station, AppInfo, Streaming, Telemetry).
  - `providers/`: State management (StationProvider, ThemeProvider).
  - `screens/`: Main listener app UI (PlayerScreen, SettingsScreen, etc.).
  - `services/`: Core logic (FirestoreService, TelemetryService, AudioService).
  - `widgets/`: Reusable UI components.
  - `dashboard_web/`: The administrative web dashboard (Superadmin & Admin views).
- `functions/`: Firebase Cloud Functions for aggregating analytics.
- `assets/`: Default local assets and launcher icons.
- `firebase/`: Firebase security rules (`firestore.rules`, `storage.rules`).

## ⚙️ Setup & Deployment

See [`DEPLOYMENT_GUIDELINES.md`](./DEPLOYMENT_GUIDELINES.md) for detailed instructions on configuring Firebase, setting up Cloud Functions, and deploying the Web Dashboard and Mobile Apps.

---
*Built with Flutter & Firebase.*
