# DeepFocus

<p align="center">
  <img src="android/app/src/main/deepfocus-playstore.png" width="160" alt="DeepFocus Logo">
</p>

DeepFocus is a privacy-first deep work assistant that leverages local usage patterns to recommend the most effective focus sessions. Unlike traditional productivity trackers, it uses a "cold-start" heuristic engine that evolves into a personalized coach without your data ever leaving the device.

---

## 🚀 Features (Technical Standpoint)

- **Layered Architecture**: Follows a strict `UI → State Management → Service` pattern to ensure separation of concerns and testability.
- **Local-First Recommendation Engine**: Implements a heuristic scoring system that analyzes time-of-day success probability, category momentum, and session duration preferences.
- **Structured Persistence**: Utilizes a SQLite schema optimized for time-series analysis, allowing for easy export of session data for external ML training.
- **ML Shadow Mode**: Features a background inference pipeline that runs experimental logistic regression models alongside the live heuristic engine to validate predictive accuracy.
- **Offline Text Analysis**: Locally processes post-session reflections to identify recurring productivity blockers and environmental factors.

---

## 🛠 Tech Stack

- **Framework:** Flutter (^3.10.8)
- **Language:** Dart
- **Database:** sqflite (SQLite) for structured local storage.
- **State Management:** Layered `ChangeNotifier` and Service providers.
- **Preferences:** `shared_preferences` for lightweight settings and profile metadata.

---

## 📱 UI Preview
| Main Screen | Personalized Coaching | Focus History & Insights |
| :---: | :---: | :---: |
| ![Main Screen](lib/ui/main.png) | ![Personalized Coaching](lib/ui/coach.png) | ![Focus History & Insights](lib/ui/history.png) |

---

## ⚙️ Getting Started

### Prerequisites
- Flutter SDK installed on your machine.
- An Android or iOS emulator/physical device.

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/GadielPugh/deep_work_app.git
   cd deep_work_app
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

---

## 🛡 Privacy & Data

DeepFocus is designed with a **Zero-Server architecture**.
- No accounts or cloud synchronization.
- All session data and reflections are stored in a local SQLite database.
- View the full Privacy Policy here.

---

## 📄 License

This project is licensed under the **GNU General Public License Version 3**:

> GNU GENERAL PUBLIC LICENSE  
> Version 3, 29 June 2007
>
> Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
> Everyone is permitted to copy and distribute verbatim copies of this license document, but changing it is not allowed.

---

**Author:** Gadiel Pugh