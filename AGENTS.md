# Agent Guidelines for CodeMate Flutter Project

## Build/Lint/Test Commands

### Build & Run
- **Build web app**: `flutter build web --release`
- **Run development**: `flutter run -d chrome`
- **Install dependencies**: `flutter pub get`

### Code Quality
- **Lint/Analyze**: `flutter analyze`
- **Format code**: `flutter format lib/`
- **Test all**: `flutter test`
- **Test single file**: `flutter test test/widget_test.dart`

### Database & Backend
- **Push DB migrations**: `supabase db push`
- **Deploy functions**: `supabase functions deploy [function-name]`

## Code Style Guidelines

### Imports
- Group imports: `dart:` → `package:` → `relative imports`
- Use relative imports for project files
- Example:
```dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
```

### Naming Conventions
- **Classes**: PascalCase (e.g., `AuthProvider`, `IdePage`)
- **Variables/Methods**: camelCase (e.g., `projectId`, `loadProjectName`)
- **Constants**: camelCase with lowercase prefix (e.g., `kDefaultPadding`)
- **Files**: snake_case (e.g., `auth_provider.dart`, `ide_page.dart`)

### Widget Patterns
- Use `ConsumerStatefulWidget` for Riverpod state management
- Use `super.key` in constructors
- Use `const` constructors where possible
- Example:
```dart
class MyWidget extends ConsumerStatefulWidget {
  const MyWidget({super.key, required this.param});
  // ...
}
```

### State Management
- Use Riverpod providers for state management
- Prefer `Provider` for services, `StateNotifierProvider` for mutable state
- Use `Consumer` widgets to watch providers

### Error Handling
- Use try-catch blocks for async operations
- Check `mounted` before calling `setState`
- Handle null values with null-aware operators (`?.`, `??`)

### Code Organization
- Keep widgets focused and single-responsibility
- Extract reusable components to separate files
- Use meaningful variable names over abbreviations
- Add comments for complex business logic

## Project Structure
- `lib/screens/`: Page-level widgets
- `lib/components/`: Reusable UI components
- `lib/providers/`: Riverpod state providers
- `lib/services/`: Business logic and API calls
- `lib/models/`: Data models
- `lib/themes/`: App theming and colors