# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter application called "ojob" (Job Schedule Generator) - a cross-platform app for generating Job_Schedule.txt files. The app allows users to input job details (Article Code, Lot, Number of Pieces) and generates properly formatted text files. The project supports Android, iOS, web, and desktop platforms.

## Development Commands

### Core Flutter Commands
- `flutter run` - Run the app in debug mode (requires connected device/emulator)
- `flutter build apk` - Build Android APK
- `flutter build ios` - Build iOS app (requires macOS and Xcode)
- `flutter build web` - Build web version for deployment
- `flutter build windows` - Build Windows desktop app
- `flutter build macos` - Build macOS desktop app (requires macOS)
- `flutter build linux` - Build Linux desktop app
- `flutter clean` - Clean build artifacts and dependencies
- `flutter pub get` - Install/update dependencies from pubspec.yaml

### Testing and Quality
- `flutter test` - Run all unit and widget tests
- `flutter analyze` - Run static analysis and linter checks
- `flutter pub deps` - Show dependency tree
- `flutter doctor` - Check Flutter installation and dependencies

### Hot Reload Development
When running with `flutter run`, use:
- `r` - Hot reload (preserves app state)
- `R` - Hot restart (resets app state)
- `q` - Quit the running application

### Icon Generation (if needed)
- `flutter pub run flutter_launcher_icons:main` - Generate app icons for all platforms

### GitHub Actions (CI/CD)
- Automatic builds triggered on push to main, tags, and PRs
- Windows build: `build-windows.yml`
- Multi-platform build: `build-multi-platform.yml`
- Release creation: automatic on git tag `v*`

## Project Structure

### Key Directories
- `lib/` - Main Dart source code
  - `main.dart` - Complete application with JobScheduleApp and file generation logic
- `test/` - Widget and unit tests
- `assets/icons/` - App icon assets
- `android/`, `ios/`, `web/`, `windows/`, `linux/`, `macos/` - Platform-specific code and configurations

### Configuration Files
- `pubspec.yaml` - Dependencies, assets, and project metadata
- `analysis_options.yaml` - Dart analyzer and linter configuration (uses flutter_lints)

## Application Architecture

### Main Features
- **File Generation**: Creates Job_Schedule.txt files with format: `[ARTICLE_CODE] [LOT] [PIECES]`
- **File Picker Integration**: Allows users to select save location
- **History/Chronology**: Maintains a history of generated files using SharedPreferences
- **Input Validation**: Basic validation for required fields
- **Responsive Design**: Works on mobile, tablet, and desktop with scrollable layout

### UI Components
- **Material Design 3**: Modern design with custom gradient theme (#6366F1 to #8B5CF6)
- **Animated Components**: Smooth fade-in animations using animate_do
- **Modern Icons**: Phosphor Flutter icons for better visual appeal
- **Card-based Layout**: Gradient containers with rounded corners and shadows
- **ScrollView**: Prevents overflow on smaller screens
- **Enhanced Notifications**: Floating snackbars with emoji indicators
- **Modern Dialogs**: Custom-styled history dialog with improved UX

### Dependencies
- **Core**: Flutter SDK ^3.9.0
- **File Operations**: file_picker ^8.0.0+1, path_provider ^2.1.2
- **Data Persistence**: shared_preferences ^2.2.2
- **Icons**: cupertino_icons ^1.0.8, phosphor_flutter ^2.1.0
- **Animations**: animate_do ^3.3.4
- **Development**: flutter_test, flutter_lints ^5.0.0, flutter_launcher_icons ^0.13.1

## File Format Specification

Generated files follow this exact format:
```
[ARTICLE_CODE]	[LOT]	[PIECES]
```
Example: `PXO7471-250905	310	15`

**Important**: TAB characters between all fields (article code, lot, and pieces).

## Development Notes

- All text is in Italian for the user interface
- File names are always "Job_Schedule.txt"
- History is limited to 50 most recent entries
- App uses SingleChildScrollView to handle different screen sizes
- **Modern Design**: Purple gradient theme (#6366F1 to #8B5CF6) with Material Design 3
- **Enhanced File Picker**: Improved error handling and user feedback
- **Animations**: Smooth fade-in/fade-up animations on all UI elements
- **Custom Icons**: Professional Phosphor icons throughout the interface
- Input fields have proper keyboard types (text/number)
- Loading states and comprehensive error handling implemented
- **Custom App Icons**: SVG-based modern icon design with gradient branding

## Design Assets

- `assets/icons/app_icon_1024.svg` - Main app icon design
- `icon_generator.html` - Icon preview and branding guide
- Modern gradient color palette with professional styling