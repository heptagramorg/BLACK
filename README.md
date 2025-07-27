# BLACK

Welcome to the official open-source repository for BLACK — the unified academic space for students. This document provides a comprehensive guide for developers looking to contribute to the project or understand its technical foundations.

## Architectural Overview

BLACK is a cross-platform mobile application built with Flutter and Dart. The project strictly follows the principles of **Clean Architecture** to ensure the codebase is maintainable, scalable, and testable. The architecture is decoupled into three distinct layers:

1.  **Presentation (UI) Layer**: Located in `lib/screens/` and `lib/widgets/`, this layer is responsible for displaying data and capturing user input. It contains no business logic.
2.  **Application (Business Logic) Layer**: Implemented within `lib/providers/` and service classes, this layer contains the application-specific business rules and orchestrates the flow of data between the UI and Data layers.
3.  **Data (Data Access) Layer**: Located in `lib/services/`, this layer is responsible for all communication with external data sources, primarily the Supabase and Firebase backends. It abstracts the data sources from the rest of the application.

## Features

* **Unified Document Library**: Upload, view, and organize academic materials—handwritten notes, PDFs, lecture slides, and images.
* **Smart Search**: Find documents by subject, tags, or uploader using intelligent search.
* **Productivity Tools**: Track academic tasks and events with a built-in to-do list and calendar.
* **Collaborative Forum**: Ask questions, request notes, and share insights with peers.
* **Community Hub**: Follow classmates and contributors to stay updated with new content.
* **Customizable Themes**: Personalize the app with light and dark mode options.

## Tech Stack

* **Framework**: Flutter & Dart
* **Backend-as-a-Service**:
    * **Supabase**: PostgreSQL Database, Authentication, and Storage.
    * **Firebase**: Authentication (Google Sign-In, etc.) and Cloud Messaging (Push Notifications).
* **Containerization**: Docker

## Getting Started

Follow these instructions to set up the project for local development.

### Prerequisites

Ensure you have the following installed on your local machine:

* Flutter SDK (version 3.0.0 or higher)
* Git
* Docker Desktop
* An IDE like VS Code or Android Studio

### 1. Installation

First, clone the repository to your local machine and install the required packages:

```bash
git clone [https://github.com/your-username/black.git](https://github.com/your-username/black.git)
cd black
flutter pub get
```

### 2. Backend Configuration

BLACK uses both Supabase and Firebase. You must configure both.

#### Supabase Setup

1.  Navigate to [Supabase](https://app.supabase.com) and create a new project.
2.  In your Supabase project, go to the **SQL Editor** and run the necessary migration scripts to set up the database schema (`profiles`, `notes`, `followers`, etc.).
    * *(Note: Migration scripts should be located in a `/supabase/migrations` directory in the repository).*
3.  Navigate to **Project Settings > API** to find your project URL and `anon` key.

#### Firebase Setup

1.  Navigate to the [Firebase Console](https://console.firebase.google.com/) and create a new project.
2.  **Enable Authentication**:
    * In the Firebase console, go to **Authentication > Sign-in method**.
    * Enable the required providers, such as **Google**, **Email/Password**, etc.
3.  **Register Your App**:
    * Register a new Android and/or iOS app within your Firebase project.
    * Follow the on-screen instructions to download the configuration file:
        * For Android: `google-services.json` (place it in `android/app/`).
        * For iOS: `GoogleService-Info.plist` (place it in `ios/Runner/`).
4.  **FlutterFire CLI**: Ensure your local project is configured by running:
    ```bash
    flutterfire configure
    ```
    This will generate the `lib/firebase_options.dart` file required for initialization.

### 3. Environment Variables

Create a `.env` file in the root of the project directory. This file will store your secret keys and is ignored by Git. Populate it with your credentials from the previous steps.

```
# Supabase Credentials
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key

# Note: Firebase keys are handled by google-services.json and firebase_options.dart,
# so they do not need to be in the .env file.
```

### 4. Running the Application

You can run the application directly using the Flutter CLI or with Docker.

#### Local Development

```bash
flutter run
```

#### Using Docker (Recommended for a consistent environment)

Build and run the Docker image:

```bash
docker build -t black-app .
docker run -p 8080:80 black-app
```
*(Note: A `Dockerfile` must be present in the project root for this to work.)*

## Contributing

We welcome contributions from the community to help improve BLACK. To contribute, please follow these steps:

1.  Fork the repository.
2.  Create a new feature branch for your work.
3.  Make your changes and commit them with a clear, descriptive message.
4.  Push your branch to your forked repository.
5.  Open a pull request against the `main` branch of the original repository.

```bash
# Example contribution workflow
git checkout -b feature/YourAmazingFeature
# ... make your changes ...
git commit -m "feat: Implement YourAmazingFeature"
git push origin feature/YourAmazingFeature
```

Please open an issue to discuss major architectural changes or feature proposals before starting work.

## License

This project is licensed under the **Apache License 2.0**. See the [LICENSE](http://www.apache.org/licenses/LICENSE-2.0) file for full details.
