import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final diffOverlayProvider = ChangeNotifierProvider<DiffOverlayProvider>((ref) => DiffOverlayProvider());

class DiffOverlayProvider extends ChangeNotifier {
  String? _path;
  String _oldContent = '';
  String _newContent = '';

  String? get path => _path;
  String get oldContent => _oldContent;
  String get newContent => _newContent;

  void showOverlay({required String path, required String oldContent, required String newContent}) {
    _path = path;
    _oldContent = oldContent;
    _newContent = newContent;
    notifyListeners();
  }

  void clear() {
    _path = null;
    _oldContent = '';
    _newContent = '';
    notifyListeners();
  }
} 