# Financial Tracker

A Flutter application designed to read and display SMS messages with a focus on financial transactions. This app scans your messages, extracts financial amounts, and displays them in a user-friendly interface.

## Features

- Read and display SMS messages from your device
- Automatically detect and highlight financial amounts in messages
- Filter messages to show only those containing financial information
- Search through messages by sender or content
- Beautiful and intuitive UI

## Getting Started

### Prerequisites

- Flutter SDK
- Android Studio or VS Code
- A physical Android device (SMS reading may not work on emulators)

### Installation

1. Clone this repository
2. Run `flutter pub get` to install dependencies
3. Connect your Android device (ensure USB debugging is enabled)
4. Run `flutter run` to install and launch the app

### Permissions

When you first run the app, you'll need to grant SMS reading permissions. This is necessary for the app to function correctly.

## Project Structure

This project follows a modular structure to make it easy to understand and extend:

- **models/** - Contains data models
- **services/** - Contains services for SMS access
- **providers/** - Contains state management logic
- **screens/** - Contains screens/pages
- **widgets/** - Contains reusable UI components

## For Python Developers Learning Flutter

If you're coming from Python, here are some key concepts to understand:

- **Widgets** are like functions in Python - they compose together to build UIs
- **StatefulWidget** is like a class with mutable state
- **StatelessWidget** is like a pure function with no side effects
- **Provider** is similar to Python's context managers but for state
- **Future** is similar to Python's async/await pattern

## Next Steps

- Add analytics to categorize spending
- Create charts and visualizations of spending patterns
- Add export functionality for data analysis
- Integrate with banking APIs for more accurate data

## License

This project is for educational purposes.
