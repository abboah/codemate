import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TwoColumnLayout extends StatelessWidget {
  final String pageTitle;
  final String pageDescription;
  final String buttonText;
  final VoidCallback? onButtonPressed;
  final Widget rightColumnContent;
  final bool isLoading;

  const TwoColumnLayout({
    super.key,
    required this.pageTitle,
    required this.pageDescription,
    required this.buttonText,
    required this.onButtonPressed,
    required this.rightColumnContent,
    this.isLoading = false,
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
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Center(
          heightFactor: 1,
          child: isLoading
              ? const SizedBox(
                  height: 28,
                  width: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_outline,
                        color: Colors.white, size: 28),
                    const SizedBox(width: 16),
                    Text(
                      buttonText,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
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
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
