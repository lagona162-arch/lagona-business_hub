/// Supabase Configuration
/// 
/// Update these values with your Supabase project credentials
class SupabaseConfig {
  // Your Supabase project URL
  static const String supabaseUrl = 'https://lpcjaxssqvgvgtvwabkv.supabase.co';
  
  // Your Supabase anonymous/public key
  static const String supabaseAnonKey = 'sb_publishable_AYbnhnTL-BmzanL9Stzzsw_VxrXQr2-';
  
  /// Initialize Supabase with your credentials
  /// Call this in main() before runApp()
  static Future<void> initialize() async {
    // SupabaseService.initialize() will be called in main.dart
  }
}

