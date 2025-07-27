# BLACK

Welcome to the official open-source repository for BLACK — the unified academic space for students. Built by students, for students, BLACK is designed to centralize notes, tasks, and community interaction into one seamless platform.

Visit the website: [https://www.ultimatelyitsblack.com](https://www.ultimatelyitsblack.com)

## Features

**Unified Document Library**  
Upload, view, and organize all your academic materials — handwritten notes, PDFs, lecture slides, and images — in one centralized library.

**Smart Search**  
Quickly find documents by subject, tags, or uploader using intelligent search.

**Productivity Tools**  
Track your academic tasks and events with a built-in to-do list and calendar.

**Collaborative Forum**  
Ask questions, request notes, share insights, and work through academic challenges with your peers.

**Community Hub**  
Follow classmates and contributors. Stay updated with new uploads and trending academic content across your university and beyond.

**Customizable Themes**  
Personalize the app with light and dark mode options.

## Tech Stack

- **Framework**: Flutter  
- **Backend & Database**: Supabase  

## Getting Started

### Prerequisites

Make sure you have the following installed:

- Flutter SDK (version 2.19.0 or higher)
- Git
- An IDE like VS Code or Android Studio

### Installation

Clone the repository:

```bash
git clone https://github.com/your-username/black.git
cd black
```

Install dependencies:

```bash
flutter pub get
```

### Supabase Setup

1. Go to [Supabase](https://app.supabase.com) and create a new project.
2. Navigate to `Project Settings > API` to get your API credentials.
3. Create a `.env` file in the root of your project and add the following:

```
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_anon_key
```

4. Run the app:

```bash
flutter run
```

## Contributing

We welcome contributions from the community.

### How to Contribute

1. Fork the repository
2. Create your feature branch:
   ```bash
   git checkout -b feature/YourFeature
   ```
3. Commit your changes:
   ```bash
   git commit -m "Add YourFeature"
   ```
4. Push to your branch:
   ```bash
   git push origin feature/YourFeature
   ```
5. Open a pull request

Please open an issue first to discuss major feature proposals or architectural changes.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
