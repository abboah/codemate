import 'package:flutter_riverpod/flutter_riverpod.dart';

class LearningState {
  final String? selectedPath;
  final String? selectedLanguage;
  final int pageIndex; // 0 = hub, 1 = course detail
  final int selectedTab; // 0 = paths, 1 = languages
  final double currentPathProgress;

  LearningState({
    this.selectedPath,
    this.selectedLanguage,
    this.pageIndex = 0,
    this.selectedTab = 0,
    this.currentPathProgress = 0.0,
  });

  LearningState copyWith({
    String? selectedPath,
    String? selectedLanguage,
    int? pageIndex,
    int? selectedTab,
    double? currentPathProgress,
  }) {
    return LearningState(
      selectedPath: selectedPath ?? this.selectedPath,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      pageIndex: pageIndex ?? this.pageIndex,
      selectedTab: selectedTab ?? this.selectedTab,
      currentPathProgress: currentPathProgress ?? this.currentPathProgress,
    );
  }
}

class LearningStateNotifier extends StateNotifier<LearningState> {
  LearningStateNotifier() : super(LearningState());

  void selectPath(String path) {
    state = state.copyWith(
      selectedPath: path,
      selectedLanguage: null,
      pageIndex: 1,
      currentPathProgress:
          0.1 + 0.7 * (path.hashCode % 10) / 10, // demo progress
    );
  }

  void selectLanguage(String lang) {
    state = state.copyWith(
      selectedLanguage: lang,
      selectedPath: null,
      pageIndex: 1,
    );
  }

  void goToHub() {
    state = state.copyWith(pageIndex: 0);
  }

  void selectTab(int tab) {
    state = state.copyWith(selectedTab: tab);
  }
}

final learningStateProvider =
    StateNotifierProvider<LearningStateNotifier, LearningState>(
      (ref) => LearningStateNotifier(),
    );
