# Clock & Calendar App

最新中文功能、数据来源、运行限制和操作说明见 [Windows 使用说明](USAGE.zh-CN.md)。

A Flutter desktop application displaying an analog clock and interactive calendar view with Chinese holidays and solar terms.

## Features

- **Analog Clock**: Real-time analog clock with hour, minute, and second hands
- **Calendar View**: Interactive month calendar with date selection
- **Chinese Holidays**: Display of Chinese festivals, holidays and solar terms
  - 🔴 **Holidays (放假)**: National holidays with vacation days (Spring Festival, National Day, etc.)
  - 🟠 **Festivals (节日)**: Important festivals and celebrations
  - 🟢 **Solar Terms (节气)**: Traditional Chinese solar terms
- **Desktop Support**: Optimized for Windows desktop platform

## Project Structure

```
lib/
├── main.dart                      # Main application file
├── utils/
│   └── chinese_holidays.dart     # Chinese holidays data and utilities
└── widgets/
    ├── clock_widget.dart         # Analog clock implementation
    └── calendar_widget.dart      # Calendar widget with holiday support
```

## Getting Started

### Prerequisites

- Flutter SDK compatible with Dart 3.3 (see [Windows 使用说明](USAGE.zh-CN.md))
- Windows platform support enabled in Flutter

### Installation

1. Navigate to the project directory:
```bash
cd clock_calendar_app
```

2. Get dependencies:
```bash
flutter pub get
```

### Running the Application

To run the application on Windows:

```bash
flutter run -d windows
```

The app will launch and display:
- An analog clock on the left showing the current time
- An interactive calendar on the right with Chinese holidays highlighted

## Calendar Features

### Holiday Color Coding

- **休 / 班 markers**: Official rest days and make-up workdays from holiday-cn.

- **Orange Border/Background**: 节日 (Festivals)
  - Special celebrations and festivals

- **Green Border/Background**: 节气 (Solar Terms)
  - Traditional Chinese 24 solar terms
  - Examples: 立春 (Start of Spring), 清明 (Pure Brightness), 冬至 (Winter Solstice), etc.

### Interactive Features

- **Navigate Months**: Use arrow buttons (◀ ▶) to browse through months
- **Select Dates**: Click on any date to select it
- **Holiday Details**: Selected date shows complete holiday/solar term information
- **Current Date**: Today's date is highlighted with blue border
- **Date Summary**: Displays full date information and holiday details

## Controls

- **Previous/Next Month**: Click arrow buttons in the calendar header
- **Select Date**: Click on any date in the calendar
- **Hot Reload**: Press 'r' in the terminal to reload changes
- **Hot Restart**: Press 'R' for full restart
- **Quit**: Press 'q' in the terminal to exit the application

## Building for Release

To build a release version:

```bash
flutter build windows --release
```

The executable will be located at:
```
build\windows\x64\runner\Release\clock_calendar_app.exe
```

## Development

This project demonstrates:
- Custom paint implementation for the analog clock
- StatefulWidget usage for dynamic time updates
- GridView for calendar layout with custom cell decoration
- Flutter's Material Design components
- Date/Time manipulation in Dart
- Holiday and solar term data management
- Color-coded UI for better information hierarchy

## License

Third-party licenses and source mappings are listed in [OPEN_SOURCE.md](OPEN_SOURCE.md). The project license is not specified here.

