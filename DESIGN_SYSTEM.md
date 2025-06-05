# Design System Documentation

This Flutter app uses a comprehensive design system with a modern, minimalist aesthetic focused on dark mode with high contrast.

## Core Design Principles

- **Primary Background**: Pure black (#000000)
- **Text**: White text for maximum contrast
- **Minimal Borders**: Subtle borders only where necessary
- **Rounded Corners**: Consistent use of rounded corners for a modern look
- **Typography**: Clean, hierarchical text system

## File Structure

```
lib/
├── core/
│   └── theme/
│       ├── app_theme.dart      # Main theme configuration
│       ├── app_colors.dart     # Color palette
│       ├── app_typography.dart # Typography system
│       └── app_spacing.dart    # Spacing constants
└── presentation/
    └── widgets/
        └── common/
            ├── app_card.dart       # Card components
            ├── app_button.dart     # Button components
            └── app_text_field.dart # Input components
```

## Usage

### 1. Apply Theme

The theme is already applied in `main.dart`:

```dart
MaterialApp(
  theme: AppTheme.darkTheme,
  // ...
)
```

### 2. Using Colors

```dart
import 'package:your_app/core/theme/app_colors.dart';

Container(
  color: AppColors.surface,
  child: Text(
    'Hello',
    style: TextStyle(color: AppColors.textPrimary),
  ),
)
```

### 3. Using Typography

```dart
import 'package:your_app/core/theme/app_typography.dart';

Text(
  'Headline',
  style: AppTypography.headlineLarge,
)
```

### 4. Using Spacing

```dart
import 'package:your_app/core/theme/app_spacing.dart';

Padding(
  padding: EdgeInsets.all(AppSpacing.md),
  child: Container(
    margin: EdgeInsets.only(bottom: AppSpacing.lg),
  ),
)
```

### 5. Using Components

#### Cards
```dart
// Standard card
AppCard(
  child: Text('Content'),
)

// Outlined card
AppOutlinedCard(
  child: Text('Content'),
)

// Interactive card
AppCard(
  onTap: () {},
  child: Text('Tap me'),
)
```

#### Buttons
```dart
// Primary button
AppButton(
  text: 'Click Me',
  onPressed: () {},
)

// Outlined button
AppOutlinedButton(
  text: 'Click Me',
  onPressed: () {},
)

// Text button
AppTextButton(
  text: 'Learn More',
  onPressed: () {},
)

// Icon button
AppIconButton(
  icon: Icons.favorite,
  onPressed: () {},
)
```

#### Text Fields
```dart
// Standard text field
AppTextField(
  label: 'Email',
  hint: 'Enter your email',
  controller: emailController,
)

// Password field
AppPasswordField(
  controller: passwordController,
)

// Search field
AppSearchField(
  onChanged: (value) {},
)

// Text area
AppTextArea(
  label: 'Comments',
  controller: commentsController,
)
```

## Color Palette

- **Background**: `#000000` (Pure black)
- **Surface**: `#121212` (Elevated surface)
- **Card Background**: `#1E1E1E` (Surface variant)
- **Primary Text**: `#FFFFFF` (White)
- **Secondary Text**: `#B3B3B3` (Light gray)
- **Accent**: `#2196F3` (Blue)
- **Success**: `#4CAF50` (Green)
- **Error**: `#EF5350` (Red)
- **Border Light**: `#2A2A2A`

## Spacing Scale

- `xxs`: 4px
- `xs`: 8px
- `sm`: 12px
- `md`: 16px
- `lg`: 24px
- `xl`: 32px
- `xxl`: 40px

## Border Radius

- Small: 8px
- Medium: 12px
- Large: 16px
- Extra Large: 24px

## Demo Screen

To see all components in action, run the demo screen:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const DesignSystemDemo(),
  ),
);
```

## Best Practices

1. **Always use theme colors** - Never hardcode colors
2. **Use semantic spacing** - Use `AppSpacing` constants instead of magic numbers
3. **Maintain consistency** - Use the provided components instead of creating custom ones
4. **Follow the type scale** - Use `AppTypography` for all text styles
5. **Respect the dark theme** - Ensure sufficient contrast for readability

## Customization

To customize the design system:

1. Modify color values in `app_colors.dart`
2. Adjust typography in `app_typography.dart`
3. Change spacing values in `app_spacing.dart`
4. Update component defaults in their respective files

The design system is built to be easily maintainable and extensible while ensuring consistency across the entire application.