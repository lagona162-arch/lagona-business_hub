import 'package:shared_preferences/shared_preferences.dart';
import '../models/business_hub.dart';
import 'supabase_service.dart';

class AuthService {
  static const String _userIdKey = 'user_id';
  static const String _hasSeenBhCodeKey = 'has_seen_bhcode';
  final supabase = SupabaseService.client;

  // Step 1: Verify login credentials (without fetching business hub data)
  Future<Map<String, dynamic>> verifyLogin(String email, String password) async {
    try {
      // Verify login credentials in users table
      final userResponse = await supabase
          .from('users')
          .select()
          .eq('email', email)
          .eq('role', 'business_hub')
          .eq('is_active', true)
          .eq('access_status', 'approved')
          .maybeSingle();

      if (userResponse == null) {
        throw Exception('Invalid email or password');
      }

      // Verify password (comparing plain text as per your schema)
      // Note: In production, passwords should be hashed and compared using bcrypt or similar
      if (userResponse['password'] != password) {
        throw Exception('Invalid email or password');
      }

      // Return user info (without business hub data yet)
      return userResponse;
    } on Exception catch (e) {
      // Re-throw existing exceptions as-is
      rethrow;
    } catch (e) {
      // Handle network/connection errors
      if (e.toString().contains('socket') || e.toString().contains('host lookup') || e.toString().contains('Failed host lookup')) {
        throw Exception('Network error: Unable to connect to server. Please check your internet connection.');
      }
      throw Exception('Login error: ${e.toString()}');
    }
  }

  // Step 2: Get business hub data after BHCODE verification
  Future<BusinessHub> getBusinessHubAfterLogin(String userId) async {
    try {
      // Get business hub data using the same id (always fetch fresh from database)
      final bhData = await supabase
          .from('business_hubs')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (bhData == null) {
        throw Exception('Business Hub account not found');
      }

      final userData = Map<String, dynamic>.from(bhData);
      userData['id'] = userId;
      
      // Only save userId for session management
      try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, userId);
      } catch (_) {
        // Ignore errors saving userId - not critical
      }
      
      return BusinessHub.fromJson(userData);
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Error fetching business hub: ${e.toString()}');
    }
  }

  // Verify BHCODE on first login
  Future<BusinessHub> verifyBhCode(String userId, String enteredBhCode) async {
    try {
      // Get business hub data for this user
      final bhData = await supabase
          .from('business_hubs')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (bhData == null) {
        throw Exception('Business Hub account not found');
      }

      // Get the actual BHCODE from database
      final actualBhCode = (bhData['bh_code'] as String?)?.trim().toUpperCase() ?? '';

      if (actualBhCode.isEmpty) {
        throw Exception('BHCODE not assigned. Please contact admin.');
      }

      // Verify entered BHCODE matches the one in database
      if (enteredBhCode.trim().toUpperCase() != actualBhCode) {
        throw Exception('Invalid BHCODE. Please enter the correct code.');
      }

      // BHCODE is correct, return business hub data (always fetch fresh from database)
      final userData = Map<String, dynamic>.from(bhData);
      userData['id'] = userId;
      
      // Only save userId for session management
      try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, userId);
      } catch (_) {
        // Ignore errors saving userId - not critical
      }
      
      return BusinessHub.fromJson(userData);
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Verification error: ${e.toString()}');
    }
  }

  Future<void> markBhCodeAsSeen(String userId) async {
    // Store in local storage that user has seen BHCODE
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_hasSeenBhCodeKey$userId', true);
  }

  Future<bool> hasSeenBhCode(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_hasSeenBhCodeKey$userId') ?? false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey);
    await prefs.remove(_userIdKey);
    if (userId != null) {
      await prefs.remove('$_hasSeenBhCodeKey$userId');
    }
  }

  Future<String?> getToken() async {
    // Since we're using custom auth, we can use the user ID as a token
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  Future<BusinessHub?> getCurrentUser() async {
    try {
      // Always fetch fresh data from database (real-time)
      final userId = await getToken();
      if (userId != null && userId.isNotEmpty) {
        final bhData = await supabase
            .from('business_hubs')
            .select()
            .eq('id', userId)
            .maybeSingle();
      
        if (bhData != null) {
          final userData = Map<String, dynamic>.from(bhData);
          userData['id'] = userId;
      return BusinessHub.fromJson(userData);
        }
      }

      return null;
    } catch (e) {
      // Return null if error - no fallback to cached data
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey);
    return userId != null && userId.isNotEmpty;
  }
}
