import 'package:flutter_riverpod/flutter_riverpod.dart';

/// This provider holds the ID of the currently active chat session.
/// It will be null if no chat is selected.
final activeChatProvider = StateProvider<String?>((ref) => null);
