import 'package:flutter_dotenv/flutter_dotenv.dart';

// Public (non-secret) base URL of the Supabase project. Fallback to the one
// used in main.dart if SUPABASE_URL isn't present in .env.
const String _fallbackSupabaseUrl = 'https://owvskpwnidkngogfsmby.supabase.co';

String getSupabaseUrl() {
  final envUrl = dotenv.env['SUPABASE_URL'];
  return (envUrl != null && envUrl.isNotEmpty) ? envUrl : _fallbackSupabaseUrl;
}

String getFunctionsOrigin() {
  final url = getSupabaseUrl();
  final uri = Uri.parse(url);
  final host = uri.host.replaceFirst('.supabase.co', '.functions.supabase.co');
  return '${uri.scheme}://$host';
}
