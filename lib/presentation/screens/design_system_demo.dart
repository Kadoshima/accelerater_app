import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_text_field.dart';

/// Demo screen to showcase the design system components
class DesignSystemDemo extends StatefulWidget {
  const DesignSystemDemo({Key? key}) : super(key: key);

  @override
  State<DesignSystemDemo> createState() => _DesignSystemDemoState();
}

class _DesignSystemDemoState extends State<DesignSystemDemo> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Design System Demo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTypographySection(),
            const SizedBox(height: AppSpacing.sectionSpacing),
            _buildCardSection(),
            const SizedBox(height: AppSpacing.sectionSpacing),
            _buildButtonSection(),
            const SizedBox(height: AppSpacing.sectionSpacing),
            _buildTextFieldSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypographySection() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Typography',
          style: AppTypography.headlineLarge,
        ),
        SizedBox(height: AppSpacing.lg),
        Text(
          'Display Large',
          style: AppTypography.displayLarge,
        ),
        SizedBox(height: AppSpacing.md),
        Text(
          'Headline Medium',
          style: AppTypography.headlineMedium,
        ),
        SizedBox(height: AppSpacing.md),
        Text(
          'Title Large',
          style: AppTypography.titleLarge,
        ),
        SizedBox(height: AppSpacing.md),
        Text(
          'Body Medium - This is regular body text that would be used for paragraphs and general content throughout the application.',
          style: AppTypography.bodyMedium,
        ),
        SizedBox(height: AppSpacing.md),
        Text(
          'Caption - Small text for less important information',
          style: AppTypography.caption,
        ),
      ],
    );
  }

  Widget _buildCardSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cards',
          style: AppTypography.headlineLarge,
        ),
        const SizedBox(height: AppSpacing.lg),
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Standard Card',
                style: AppTypography.titleMedium,
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                'This is a standard card with rounded corners and subtle background.',
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Card tapped!')),
            );
          },
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Interactive Card',
                    style: AppTypography.titleMedium,
                  ),
                  Icon(Icons.arrow_forward, color: AppColors.textSecondary),
                ],
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                'Tap this card to see the interaction.',
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const AppOutlinedCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Outlined Card',
                style: AppTypography.titleMedium,
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                'A card with only a border and no background fill.',
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const AppGradientCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gradient Card',
                style: AppTypography.titleMedium,
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                'A card with a beautiful gradient background.',
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildButtonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Buttons',
          style: AppTypography.headlineLarge,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            AppButton(
              text: 'Primary',
              onPressed: () {},
            ),
            const SizedBox(width: AppSpacing.md),
            AppButton(
              text: 'Disabled',
              isDisabled: true,
              onPressed: () {},
            ),
            const SizedBox(width: AppSpacing.md),
            const AppButton(
              text: 'Loading',
              isLoading: true,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            AppButton(
              text: 'With Icon',
              icon: Icons.add,
              onPressed: () {},
            ),
            const SizedBox(width: AppSpacing.md),
            AppButton(
              text: 'Small',
              size: ButtonSize.small,
              onPressed: () {},
            ),
            const SizedBox(width: AppSpacing.md),
            AppButton(
              text: 'Large',
              size: ButtonSize.large,
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            AppOutlinedButton(
              text: 'Outlined',
              onPressed: () {},
            ),
            const SizedBox(width: AppSpacing.md),
            AppOutlinedButton(
              text: 'With Icon',
              icon: Icons.download,
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            AppTextButton(
              text: 'Text Button',
              onPressed: () {},
            ),
            const SizedBox(width: AppSpacing.md),
            AppTextButton(
              text: 'Learn More',
              icon: Icons.info_outline,
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            AppIconButton(
              icon: Icons.favorite,
              onPressed: () {},
              tooltip: 'Like',
            ),
            const SizedBox(width: AppSpacing.md),
            AppIconButton(
              icon: Icons.share,
              onPressed: () {},
              backgroundColor: AppColors.surfaceVariant,
              tooltip: 'Share',
            ),
            const SizedBox(width: AppSpacing.md),
            AppIconButton(
              icon: Icons.more_vert,
              size: ButtonSize.small,
              onPressed: () {},
              tooltip: 'More options',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextFieldSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Text Fields',
          style: AppTypography.headlineLarge,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Email',
          hint: 'Enter your email address',
          controller: _textController,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        AppPasswordField(
          label: 'Password',
          hint: 'Enter your password',
          controller: _passwordController,
        ),
        const SizedBox(height: AppSpacing.md),
        AppSearchField(
          hint: 'Search for items...',
          controller: _searchController,
          onChanged: (value) {
            print('Search: $value');
          },
        ),
        const SizedBox(height: AppSpacing.md),
        const AppTextField(
          label: 'Disabled Field',
          hint: 'This field is disabled',
          enabled: false,
        ),
        const SizedBox(height: AppSpacing.md),
        const AppTextField(
          label: 'Error Field',
          hint: 'This field has an error',
          errorText: 'Please enter a valid value',
        ),
        const SizedBox(height: AppSpacing.md),
        const AppTextArea(
          label: 'Comments',
          hint: 'Enter your comments here...',
          maxLines: 4,
          minLines: 3,
        ),
      ],
    );
  }
}
