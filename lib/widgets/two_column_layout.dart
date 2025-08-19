import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:codemate/widgets/fancy_loader.dart';
import 'package:codemate/themes/colors.dart';

class TwoColumnLayout extends StatelessWidget {
  final String pageTitle;
  final String pageDescription;
  final String buttonText;
  final VoidCallback? onButtonPressed;
  final Widget rightColumnContent;
  final bool isLoading;
  final Future<void> Function(BuildContext)? onBack;

  const TwoColumnLayout({
    super.key,
    required this.pageTitle,
    required this.pageDescription,
    required this.buttonText,
    required this.onButtonPressed,
    required this.rightColumnContent,
    this.isLoading = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: Row(
                children: [
                  // Left Half
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(48.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            pageTitle,
                            style: GoogleFonts.poppins(
                              fontSize: 64,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            pageDescription,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: Colors.white.withOpacity(0.7),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 40),
                          _buildNewItemCard(),
                        ],
                      ),
                    ),
                  ),
                  // Right Half
                  Expanded(
                    flex: 1,
                    child: Container(
                      margin: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: rightColumnContent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewItemCard() {
    return InkWell(
      onTap: isLoading ? null : onButtonPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.6),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.03),
              Colors.white.withOpacity(0.01),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          heightFactor: 1,
          child: isLoading
              ? const MiniWave(size: 24)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, color: AppColors.accent, size: 28),
                    const SizedBox(width: 16),
                    Text(
                      buttonText,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              if (onBack != null) {
                await onBack!(context);
                return;
              }
              // Default behavior: try to pop the current route
              await Navigator.of(context).maybePop();
            },
          ),
        ],
      ),
    );
  }
}
