import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Represents the user's settings
class UserSettings {
  final String theme;
  final bool notificationsEnabled;

  UserSettings({required this.theme, required this.notificationsEnabled});
}

// Notifier to manage the state of user settings
class UserSettingsNotifier extends StateNotifier<AsyncValue<UserSettings>> {
  UserSettingsNotifier() : super(const AsyncValue.loading()) {
    _fetchSettings();
  }

  final _supabase = Supabase.instance.client;

  Future<void> _fetchSettings() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('user_settings')
          .select()
          .eq('user_id', userId)
          .single();

      state = AsyncValue.data(UserSettings(
        theme: response['theme'],
        notificationsEnabled: response['notifications_enabled'],
      ));
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> updateTheme(String newTheme) async {
    final userId = _supabase.auth.currentUser!.id;
    state.whenData((settings) async {
      state = AsyncValue.data(UserSettings(
        theme: newTheme,
        notificationsEnabled: settings.notificationsEnabled,
      ));
      await _supabase
          .from('user_settings')
          .update({'theme': newTheme}).eq('user_id', userId);
    });
  }

  Future<void> updateNotifications(bool isEnabled) async {
    final userId = _supabase.auth.currentUser!.id;
    state.whenData((settings) async {
      state = AsyncValue.data(UserSettings(
        theme: settings.theme,
        notificationsEnabled: isEnabled,
      ));
      await _supabase
          .from('user_settings')
          .update({'notifications_enabled': isEnabled}).eq('user_id', userId);
    });
  }
}

// The provider for user settings
final userSettingsProvider =
    StateNotifierProvider<UserSettingsNotifier, AsyncValue<UserSettings>>(
  (ref) => UserSettingsNotifier(),
);
