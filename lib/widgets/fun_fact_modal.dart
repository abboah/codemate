import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:codemate/providers/learn_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class FunFactModal extends ConsumerStatefulWidget {
  final Topic topic;

  const FunFactModal({super.key, required this.topic});

  @override
  ConsumerState<FunFactModal> createState() => _FunFactModalState();
}

class _FunFactModalState extends ConsumerState<FunFactModal> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final factsAsyncValue = ref.watch(topicFactsProvider(widget.topic));

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.white.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        child: SizedBox(
          width: 500,
          height: 350,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Did you know? 💡',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          const Shadow(
                            blurRadius: 10.0,
                            color: Colors.blueAccent,
                            offset: Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: factsAsyncValue.when(
                        data: (facts) {
                          if (facts.isEmpty) {
                            return Center(
                              child: Text(
                                'No facts available for this topic yet.',
                                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
                              ),
                            );
                          }
                          return PageView.builder(
                            controller: _pageController,
                            itemCount: facts.length,
                            itemBuilder: (context, index) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                  child: Text(
                                    facts[index].factText,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        color: Colors.white.withOpacity(0.85),
                                        height: 1.6,
                                        fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Center(
                          child: Text(
                            'Oops! Could not load facts.\n${err.toString()}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(color: Colors.redAccent),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    factsAsyncValue.maybeWhen(
                      data: (facts) => facts.isNotEmpty
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
                                  onPressed: () {
                                    _pageController.previousPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.arrow_forward_ios, color: Colors.white70),
                                  onPressed: () {
                                    _pageController.nextPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
