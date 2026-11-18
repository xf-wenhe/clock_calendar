# Repository Guidelines

## Project Structure & Module Organization

A Flutter desktop application for clock and calendar with Chinese holidays.

```
lib/
├── main.dart                    # App entry point and home screen
├── utils/
│   └── chinese_holidays.dart    # Holiday/solar term data utilities
└── widgets/
    ├── clock_widget.dart        # Analog clock implementation
    └── calendar_widget.dart     # Calendar with holiday highlights

test/
└── widget_test.dart             # Widget tests

windows/                         # Windows platform configuration
```

## Build, Test, and Development Commands

| Command | Description |
|---------|-------------|
| `flutter pub get` | Install dependencies |
| `flutter run -d windows` | Run app on Windows |
| `flutter analyze` | Run static analysis/linting |
| `flutter test` | Run unit and widget tests |
| `flutter build windows --release` | Build release executable |

## Coding Style & Naming Conventions

- **Language**: Dart with Flutter framework
- **Linting**: Uses `flutter_lints` package (configured in `analysis_options.yaml`)
- **Indentation**: 2 spaces (Dart standard)
- **Naming**:
  - `PascalCase` for classes, widgets, and enums
  - `camelCase` for variables, methods, and functions
  - `snake_case` for file names
- **Imports**: Package imports first, then relative imports
- **Widgets**: Use `const` constructors where possible

## Testing Guidelines

- Test file location: `test/` directory
- Test file naming: `*_test.dart` suffix
- Framework: `flutter_test` package
- Run all tests: `flutter test`
- Run with coverage: `flutter test --coverage`

## Commit & Pull Request Guidelines

- Write clear, descriptive commit messages
- Reference issues when applicable
- Ensure `flutter analyze` passes before committing
- Run tests before submitting PRs
- For UI changes, include screenshots in PR description

## Architecture Overview

- **main.dart**: App initialization and home layout
- **widgets/**: Reusable UI components (clock, calendar)
- **utils/**: Data utilities and business logic (holiday calculations)
- Uses StatefulWidget for time updates and interactive calendar
- Custom painters for analog clock rendering

## Platform Support

Currently optimized for **Windows desktop**. Platform-specific code is in `windows/`.
