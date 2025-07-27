<div align="center">

# BLACK
### A Unified Academic Ecosystem

**A unified academic space for students. Built by students, for students.**

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Framework: Flutter](https://img.shields.io/badge/Framework-Flutter-02569B?logo=flutter)](https://flutter.dev)
[![Platform: Android](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://play.google.com/store/apps/details?id=com.loveucifer.black)
[![Open Source](https://badges.frapsoft.com/os/v2/open-source.svg?v=103)](https://github.com/heptagramorg/BLACK)

</div>

---

## About The Project

BLACK is a digital ecosystem designed to centralize and simplify academic life. Our mission is to provide an open-source, powerful, and intuitive platform that consolidates notes, tasks, and community interaction. By removing fragmentation, we empower students to focus on what matters most: learning and collaboration.

The application is built on the philosophy that essential academic tools should be accessible, transparent, and community-driven. We prioritize privacy, performance, and a user-centric design that adapts to the real-world needs of students.

### Get The App

Download the latest version of BLACK for Android directly from the Google Play Store.

<a href="https://play.google.com/store/apps/details?id=com.loveucifer.black" target="_blank">
  <img src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" alt="Download on Google Play" width="200">
</a>

---

## Core Features

* **Unified Uploads & Management**: Consolidate handwritten notes, PDFs, lecture slides, and images effortlessly. All your materials, in one place.
* **Intelligent Cross-Platform Search**: Instantly find notes by subject, tags, or user across all uploaded content. Never lose track of a single piece of information.
* **Integrated Task & Schedule Management**: Organize your academic life with a built-in to-do list and calendar to manage tasks, assignments, and deadlines seamlessly.
* **Collaborative & Community Forum**: A dedicated space to ask questions, request notes from peers, share knowledge, and connect with other students from your university and beyond.
* **Social Connectivity**: Follow classmates and friends to stay updated with their public posts and shared notes, fostering a collaborative learning environment.
* **Privacy-Focused**: You have full control over what you share. Keep notes private, or make them public to help others. Your data is yours.

---

## For Developers: Technical Deep Dive

This section provides the necessary information to get the project running locally and to start contributing.

### Technology Stack

BLACK is built with a modern, scalable, and cross-platform technology stack, chosen for performance and developer experience.

* **Framework**: Flutter & Dart
* **Architecture**: Clean Architecture Principles
* **Primary Backend (BaaS)**: Supabase (Authentication, PostgreSQL Database, Storage)
* **Secondary Backend (BaaS)**: Firebase (Cloud Messaging for Push Notifications, Google Sign-In)
* **State Management**: Provider
* **Containerization**: Docker

### Prerequisites

Ensure you have the following installed on your local development machine:

* Flutter SDK (version 3.0.0 or higher)
* Git
* Docker Desktop (for containerized deployment)
* An IDE such as Visual Studio Code or Android Studio

### 1. Installation & Setup

First, clone the official repository to your local machine and install the required Dart packages:

```bash
git clone [https://github.com/heptagramorg/BLACK.git](https://github.com/heptagramorg/BLACK.git)
cd BLACK
flutter pub get
```

### 2. Backend Configuration

BLACK utilizes both Supabase and Firebase for its backend services. Configuration for both is mandatory for full application functionality.

#### Supabase Setup

1.  Navigate to [Supabase](https://app.supabase.com) and create a new project.
2.  Within your Supabase project, go to the **SQL Editor**. Run the necessary migration scripts located in the `/supabase/migrations` directory of this repository to set up the database schema (`profiles`, `notes`, `followers`, etc.).
3.  Navigate to **Project Settings > API** to find your project URL and `anon` key. These will be used as environment variables.

#### Firebase Setup

1.  Navigate to the [Firebase Console](https://console.firebase.google.com/) and create a new project.
2.  **Enable Authentication**: In the console, go to **Authentication > Sign-in method** and enable the required providers (e.g., Google, Email/Password).
3.  **Register Your App**: Register a new Android application. Follow the on-screen instructions to download the configuration file:
    * **Android**: `google-services.json` (place this file in the `android/app/` directory).
4.  **Configure FlutterFire**: Use the FlutterFire CLI to configure your local project, which connects your Flutter app to Firebase.
    ```bash
    flutterfire configure
    ```
    This command will generate the `lib/firebase_options.dart` file automatically.

### 3. Environment Variables

Create a file named `.env` in the root of the project directory. This file is ignored by Git and is used to store your secret keys and credentials. Populate it with your Supabase credentials.

```
# Supabase Credentials
SUPABASE_URL=YOUR_SUPABASE_URL
SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

### 4. Running the Application

You can run the application directly on a connected device/emulator or build a Docker container.

* **Run in Development Mode:**
    ```bash
    flutter run
    ```
* **Build and Run with Docker:**
    ```bash
    # Build the Docker image
    docker build -t black-app .

    # Run the container
    docker run -p 8080:80 black-app
    ```

---

## Contributing

BLACK is a community-driven, open-source project. We welcome contributions from developers, designers, and students. Whether it's fixing a bug, proposing a new feature, or improving documentation, your help is valued.

1.  Fork the repository.
2.  Create your feature branch (`git checkout -b feature/YourAmazingFeature`).
3.  Commit your changes with a descriptive message (`git commit -m "feat: Implement YourAmazingFeature"`).
4.  Push your changes to the branch (`git push origin feature/YourAmazingFeature`).
5.  Open a pull request for review.

Please open an issue to discuss major architectural changes or feature proposals before beginning work.

## License

This project is licensed under the **Apache License 2.0**. See the [LICENSE](http://www.apache.org/licenses/LICENSE-2.0) file for the full text.

## Connect With Us

* [**Official Website**](https://www.ultimatelyitsblack.com/)
* [**GitHub Repository**](https://github.com/heptagramorg/BLACK)
* [**Report an Issue**](https://github.com/heptagramorg/BLACK/issues)

