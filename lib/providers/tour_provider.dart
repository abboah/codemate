import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TourProvider extends ChangeNotifier {
  // Home
  final GlobalKey homeSidebarKey = GlobalKey();
  final GlobalKey homeBuildCtaKey = GlobalKey();
  final GlobalKey homeLearnCtaKey = GlobalKey();
  final GlobalKey homePlaygroundCtaKey = GlobalKey();

  // Playground
  final GlobalKey inputKey = GlobalKey();
  final GlobalKey artifactsKey = GlobalKey();
  final GlobalKey canvasKey = GlobalKey();
  final GlobalKey canvasTabsKey = GlobalKey();
  final GlobalKey newChatKey = GlobalKey();

  // Build
  final GlobalKey buildBrainstormKey = GlobalKey();
  final GlobalKey buildDescribeKey = GlobalKey();
  final GlobalKey buildIdeKey = GlobalKey();
  final GlobalKey buildTerminalKey = GlobalKey();
  final GlobalKey buildExplorerKey = GlobalKey();
  final GlobalKey buildAgentKey = GlobalKey();

  // Learn
  final GlobalKey learnCourseListKey = GlobalKey();
  final GlobalKey learnEnrolledKey = GlobalKey();
  final GlobalKey learnProgressKey = GlobalKey();

  // Sidebar
  final GlobalKey sidebarNavKey = GlobalKey();
  final GlobalKey sidebarSettingsKey = GlobalKey();
  final GlobalKey sidebarProfileKey = GlobalKey();

  // Track which tours have been completed (could persist this)
  Map<String, bool> completedTours = {};

  void markTourComplete(String tour) {
    completedTours[tour] = true;
    notifyListeners();
  }

  void resetTour(String tour) {
    completedTours[tour] = false;
    notifyListeners();
  }
}

final tourProvider = Provider<TourProvider>((ref) => TourProvider());
