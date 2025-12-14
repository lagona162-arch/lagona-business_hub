import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/loading_station.dart';
import '../models/transaction.dart';
import '../models/commission.dart';
import '../models/blacklisted_account.dart';
import '../models/topup_request.dart';
import '../models/bh_topup_request.dart';
import 'supabase_service.dart';
import 'auth_service.dart';

class BusinessHubService {
  final supabase = SupabaseService.client;
  final AuthService _authService = AuthService();
  String? _currentBhId;

  Future<String> _getCurrentBhId() async {
    if (_currentBhId == null) {
      final user = await _authService.getCurrentUser();
      _currentBhId = user?.id;
    }
    return _currentBhId ?? '';
  }

  // Get all Loading Stations under this Business Hub
  Future<List<LoadingStation>> getLoadingStations() async {
    final bhId = await _getCurrentBhId();
    
    final response = await supabase
        .from('loading_stations')
        .select()
        .eq('business_hub_id', bhId)
        .order('created_at', ascending: false);
    
    return (response as List)
        .map((json) => LoadingStation.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // Top-Up Requests Management (Loading Station → Business Hub)
  Future<List<TopUpRequest>> getTopUpRequests({String? status}) async {
    final bhId = await _getCurrentBhId();
    
    if (bhId.isEmpty) {
      throw Exception('Business Hub ID is empty. Please log in again.');
    }
    
    try {
      // Get all top-up requests for this business hub from the 'topup_requests' table
      // Filter for Loading Station requests (where loading_station_id is NOT null)
    var queryBuilder = supabase
        .from('topup_requests')
          .select('*')
          .eq('business_hub_id', bhId)
          .filter('loading_station_id', 'not.is', null); // Only get LS requests
    
    if (status != null) {
      queryBuilder = queryBuilder.filter('status', 'eq', status);
    }
    
    final response = await queryBuilder.order('created_at', ascending: false);
    
      // Check if response is valid
      if (response == null) {
        return [];
      }
      
      final responseList = response as List;
      
      // All results are LS requests since we filtered in the query
      final lsRequests = responseList;
    
    // Optimize: Fetch all unique loading station IDs first, then batch fetch their details
    final uniqueLsIds = lsRequests
        .map((json) => (json as Map<String, dynamic>)['loading_station_id'] as String?)
        .whereType<String>()  // This filters out nulls and ensures non-nullable String type
        .toSet()
        .toList();
    
    // Fetch loading stations individually (simple and reliable approach)
    Map<String, Map<String, dynamic>> lsDataMap = {};
    for (final lsId in uniqueLsIds) {
      try {
        final lsData = await supabase
            .from('loading_stations')
            .select('id, name, ls_code')
            .eq('id', lsId)
            .maybeSingle();
        
        if (lsData != null) {
          lsDataMap[lsId] = lsData as Map<String, dynamic>;
        }
      } catch (e) {
        // Skip if fetch fails - will use 'Unknown' as fallback
      }
    }
    
    // Fetch Loading Station commission rate once (for calculating bonus on pending requests)
    double lsCommissionRate = 0.0;
    try {
      lsCommissionRate = await getLoadingStationCommissionRate();
    } catch (e) {
      // If we can't get commission rate, will use 0.0 for calculations
    }
    
    // First, collect requests that need bonus calculation and update database
    final updatePromises = <Future>[];
    for (var json in lsRequests) {
      final data = Map<String, dynamic>.from(json);
      final requestStatus = (data['status'] ?? 'pending').toString().toLowerCase();
      final requestId = data['id'] as String?;
      
      if (requestStatus == 'pending' && requestId != null) {
        // For pending requests, only set bonus_rate (not bonus_amount or total_credited)
        // The admin will set these values when approving
        if (data['bonus_rate'] == null) {
          // Update the database so admin panel sees the expected bonus rate
          // Round bonus_rate to 4 decimal places to avoid excessive trailing zeros
          updatePromises.add(
            supabase
                .from('topup_requests')
                .update({
                  'bonus_rate': double.parse(lsCommissionRate.toStringAsFixed(4)),
                })
                .eq('id', requestId)
                .then((_) => null)
                .catchError((_) => null) // Ignore errors
          );
        }
      }
    }
    
    // Trigger updates without waiting (fire and forget)
    Future.wait(updatePromises).catchError((_) => null);
    
    // Map the responses using the cached loading station data
    final mappedRequests = lsRequests.map((json) {
      final data = Map<String, dynamic>.from(json);
      
      // Get loading station details from the cached map
      final loadingStationId = data['loading_station_id'] as String?;
      if (loadingStationId != null && lsDataMap.containsKey(loadingStationId)) {
        final lsData = lsDataMap[loadingStationId]!;
        data['loading_station_name'] = lsData['name'] ?? 'Unknown';
        data['loading_station_code'] = lsData['ls_code'] ?? '';
      } else {
        // Fallback if not found in cache
        data['loading_station_name'] = 'Unknown';
        data['loading_station_code'] = '';
      }
      
      // Ensure loading_station_id is properly set
      if (data['loading_station_id'] == null) {
        // Skip if still null after filtering
        return null;
      }
      
      // Map topup_requests table fields to TopUpRequest model
      // The 'topup_requests' table uses 'created_at' for request time
      if (data['requested_at'] == null && data['created_at'] != null) {
        data['requested_at'] = data['created_at'];
      }
      // The 'topup_requests' table uses 'requested_amount' field (map to 'amount' for model)
      if (data['amount'] == null && data['requested_amount'] != null) {
        data['amount'] = data['requested_amount'];
      }
      
      // The 'topup_requests' table has 'processed_at' for approval/rejection timestamp
      if (data['approved_at'] == null && data['processed_at'] != null && data['status'] == 'approved') {
        data['approved_at'] = data['processed_at'];
      }
      if (data['rejected_at'] == null && data['processed_at'] != null && data['status'] == 'rejected') {
        data['rejected_at'] = data['processed_at'];
      }
      
      // Ensure required fields exist for TopUpRequest model
      if (data['loading_station_name'] == null || data['loading_station_name'].toString().isEmpty) {
        data['loading_station_name'] = 'Unknown Loading Station';
      }
      if (data['loading_station_code'] == null || data['loading_station_code'].toString().isEmpty) {
        data['loading_station_code'] = 'N/A';
      }
      
      // For pending requests, calculate bonus if not already set (for display)
      final requestStatus = (data['status'] ?? 'pending').toString().toLowerCase();
      if (requestStatus == 'pending') {
        final requestAmount = double.tryParse((data['amount'] ?? data['requested_amount'] ?? 0).toString()) ?? 0.0;
        
        // If bonus_rate, bonus_amount, or total_credited are not set, calculate them for display
        if (data['bonus_rate'] == null || data['bonus_amount'] == null || data['total_credited'] == null) {
          final calculatedBonusAmount = requestAmount * lsCommissionRate;
          final calculatedTotalCredited = requestAmount + calculatedBonusAmount;
          
          // Set calculated values for display
          data['bonus_rate'] = lsCommissionRate;
          data['bonus_amount'] = calculatedBonusAmount;
          data['total_credited'] = calculatedTotalCredited;
        }
      }
      
      // bonus_rate, bonus_amount, and total_credited are now set (either from DB or calculated)
      try {
      return TopUpRequest.fromJson(data);
      } catch (e) {
        // If parsing fails, skip this request
        return null;
      }
    }).whereType<TopUpRequest>().toList();
    
    return mappedRequests;
    } catch (e) {
      // Re-throw with more context
      final errorMsg = e.toString();
      if (errorMsg.contains('PGRST') || errorMsg.contains('JWT') || errorMsg.contains('permission')) {
        throw Exception('Database access error. Please check your connection and permissions.');
      }
      throw Exception('Error fetching top-up requests: $errorMsg');
    }
  }

  Future<void> approveTopUpRequest(String requestId) async {
    final bhId = await _getCurrentBhId();
    
    // Get the top-up request details from 'topup_requests' table
    final requestData = await supabase
        .from('topup_requests')
        .select('requested_amount, loading_station_id')
        .eq('id', requestId)
        .eq('business_hub_id', bhId)
        .eq('status', 'pending')
        .single();
    
    // Get request amount from 'requested_amount' field
    final requestAmount = double.tryParse(
      (requestData['requested_amount'] ?? '0').toString()
    ) ?? 0.0;
    
    final loadingStationId = requestData['loading_station_id'] as String?;
    
    if (loadingStationId == null) {
      throw Exception('Loading Station ID not found');
    }
    
    if (requestAmount <= 0) {
      throw Exception('Invalid request amount: ${requestAmount.toStringAsFixed(2)}');
    }
    
    // Get Loading Station commission rate
    final lsCommissionRate = await getLoadingStationCommissionRate();
    
    // Calculate bonus and total credited
    final bonusAmount = requestAmount * lsCommissionRate;
    final totalCredited = requestAmount + bonusAmount;
    
    // Get current Business Hub balance
    final bhData = await supabase
        .from('business_hubs')
        .select('balance')
        .eq('id', bhId)
        .single();
    
    final currentBhBalance = double.tryParse(bhData['balance']?.toString() ?? '0') ?? 0.0;
    
    // Check if Business Hub has sufficient balance for the total amount (request + bonus)
    // The Business Hub must have enough to cover both the request amount and the bonus
    if (currentBhBalance < totalCredited) {
      throw Exception('Insufficient balance. Required: ${totalCredited.toStringAsFixed(2)} (Request: ${requestAmount.toStringAsFixed(2)} + Bonus: ${bonusAmount.toStringAsFixed(2)}), Available: ${currentBhBalance.toStringAsFixed(2)}');
    }
    
    // Get current Loading Station balance
    final lsData = await supabase
        .from('loading_stations')
        .select('balance')
        .eq('id', loadingStationId)
        .single();
    
    final currentLsBalance = double.tryParse(lsData['balance']?.toString() ?? '0') ?? 0.0;
    
    // Update balances and request status
    // Note: Supabase doesn't support true transactions, so we do sequential updates
    // In production, this should be handled by a database function/trigger
    
    // 1. Deduct the total amount (request amount + bonus) from Business Hub balance
    // Since the Loading Station receives both the request amount and bonus, 
    // the Business Hub must pay for both
    await supabase
        .from('business_hubs')
        .update({
          'balance': currentBhBalance - totalCredited, // Deduct total (request + bonus)
        })
        .eq('id', bhId);
    
    // 2. Credit total (request amount + bonus) to Loading Station
    await supabase
        .from('loading_stations')
        .update({
          'balance': currentLsBalance + totalCredited, // Credit includes bonus
        })
        .eq('id', loadingStationId);
    
    // 3. Update request status with computation details in 'topup_requests' table
    // Round values to avoid excessive trailing zeros
    await supabase
        .from('topup_requests')
        .update({
          'status': 'approved',
          'processed_at': DateTime.now().toIso8601String(),
          'bonus_rate': double.parse(lsCommissionRate.toStringAsFixed(4)), // Store as decimal (e.g., 0.10 for 10%)
          'bonus_amount': double.parse(bonusAmount.toStringAsFixed(2)), // Round currency to 2 decimal places
          'total_credited': double.parse(totalCredited.toStringAsFixed(2)), // Round currency to 2 decimal places
        })
        .eq('id', requestId);
  }

  Future<void> rejectTopUpRequest(String requestId, String reason) async {
    final bhId = await _getCurrentBhId();
    
    await supabase
        .from('topup_requests')
        .update({
          'status': 'rejected',
          'processed_at': DateTime.now().toIso8601String(),
          'rejection_reason': reason,
        })
        .eq('id', requestId)
        .eq('business_hub_id', bhId);
  }

  // Commissions
  Future<List<Commission>> getCommissions({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final bhId = await _getCurrentBhId();
    
    try {
      var queryBuilder = supabase
          .from('commissions')
          .select()
          .eq('business_hub_id', bhId);
      
      if (startDate != null) {
        queryBuilder = queryBuilder.filter('created_at', 'gte', startDate.toIso8601String());
      }
      if (endDate != null) {
        queryBuilder = queryBuilder.filter('created_at', 'lte', endDate.toIso8601String());
      }
      
      final response = await queryBuilder.order('created_at', ascending: false);
      
      return (response as List)
          .map((json) => Commission.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Handle case where commissions table doesn't exist yet
      final errorString = e.toString();
      if (errorString.contains('PGRST205') || 
          errorString.contains('Could not find the table') ||
          errorString.contains('commissions')) {
        // Table doesn't exist - return empty list gracefully
        // This allows the app to work even if the table hasn't been created yet
        return [];
      }
      // Re-throw other errors
      rethrow;
    }
  }

  // Monitoring & Oversight
  // Reusing topups table for top-up transactions
  Future<List<Transaction>> getTopUpTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? loadingStationId,
  }) async {
    final bhId = await _getCurrentBhId();
    
    var queryBuilder = supabase
        .from('topups')
        .select('''
          *,
          loading_stations(name, ls_code)
        ''')
        .eq('business_hub_id', bhId);
    
    if (startDate != null) {
      queryBuilder = queryBuilder.filter('created_at', 'gte', startDate.toIso8601String());
    }
    if (endDate != null) {
      queryBuilder = queryBuilder.filter('created_at', 'lte', endDate.toIso8601String());
    }
    if (loadingStationId != null) {
      queryBuilder = queryBuilder.filter('loading_station_id', 'eq', loadingStationId);
    }
    
    final response = await queryBuilder.order('created_at', ascending: false);
    
    return (response as List).map((json) {
      final data = Map<String, dynamic>.from(json);
      // Map topups table fields to Transaction model
      data['type'] = 'topup';
      data['from_entity_id'] = data['loading_station_id'];
      data['from_entity_type'] = 'loading_station';
      
      // Map status field - check for various possible status field names
      if (data['status'] == null) {
        // If status is not directly available, check if transaction is completed
        // Completed transactions typically have processed_at or completed_at set
        if (data['processed_at'] != null || data['completed_at'] != null) {
          data['status'] = 'completed';
        } else {
          data['status'] = 'pending';
        }
      }
      
      // Ensure status is lowercase to match expected values
      if (data['status'] != null) {
        final statusStr = data['status'].toString().toLowerCase();
        if (statusStr == 'approved' || statusStr == 'processed' || statusStr == 'success') {
          data['status'] = 'completed';
        } else if (statusStr == 'failed' || statusStr == 'error') {
          data['status'] = 'failed';
        } else {
          data['status'] = statusStr; // Keep as is (pending, completed, failed)
        }
      }
      
      // Map nested loading station data
      if (data['loading_stations'] != null) {
        final ls = data['loading_stations'] as Map<String, dynamic>;
        data['from_entity_name'] = ls['name'];
      }
      return Transaction.fromJson(data);
    }).toList();
  }

  Future<Map<String, dynamic>> getBalanceAndCashFlow() async {
    final bhId = await _getCurrentBhId();
    
    // Get current balance from business_hubs table
    final bhData = await supabase
        .from('business_hubs')
        .select('balance, bonus_rate')
        .eq('id', bhId)
        .single();
    
    // Calculate total loading balance (sum of all LS balances under this BH)
    final lsBalances = await supabase
        .from('loading_stations')
        .select('balance')
        .eq('business_hub_id', bhId);
    
    final totalLoadingBalance = (lsBalances as List)
        .fold<double>(0, (sum, item) => sum + (item['balance'] ?? 0.0));
    
    // Get monthly cashflow (topups this month)
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    
    final monthlyTopups = await supabase
        .from('topups')
        .select('amount')
        .eq('business_hub_id', bhId)
        .gte('created_at', startOfMonth.toIso8601String());
    
    final monthlyCashflow = (monthlyTopups as List)
        .fold<double>(0, (sum, t) => sum + (double.tryParse(t['amount']?.toString() ?? '0') ?? 0.0));
    
    // Count total topup transactions
    final totalTransactionsResponse = await supabase
        .from('topups')
        .select('id')
        .eq('business_hub_id', bhId);
    
    return {
      'total_loading_balance': totalLoadingBalance,
      'monthly_cashflow': monthlyCashflow,
      'total_transactions': (totalTransactionsResponse as List).length,
      'current_balance': double.tryParse(bhData['balance']?.toString() ?? '0') ?? 0.0,
      'bonus_rate': double.tryParse(bhData['bonus_rate']?.toString() ?? '0') ?? 0.0,
    };
  }

  // Admin Control - Blacklist Reapplication
  Future<List<BlacklistedAccount>> getBlacklistedAccounts() async {
    final bhId = await _getCurrentBhId();
    
    // Get blacklisted accounts
    final response = await supabase
        .from('blacklisted_accounts')
        .select()
        .eq('business_hub_id', bhId)
        .order('blacklisted_at', ascending: false);
    
    // Fetch entity names separately since we can't use automatic joins
    // (entity_id can reference different tables based on entity_type)
    final List<Map<String, dynamic>> accountsWithNames = [];
    
    for (var account in response as List) {
      final data = Map<String, dynamic>.from(account as Map<String, dynamic>);
      final entityType = data['entity_type'] as String?;
      final entityId = data['entity_id'] as String?;
      
      String entityName = '';
      
      if (entityType == 'loading_station' && entityId != null) {
        // Fetch loading station name
        try {
          final lsData = await supabase
              .from('loading_stations')
              .select('name')
              .eq('id', entityId)
              .maybeSingle();
          
          if (lsData != null) {
            entityName = lsData['name'] ?? '';
          }
        } catch (e) {
          // If loading station not found, leave name empty
        }
      } else if (entityType == 'rider' && entityId != null) {
        // Fetch rider name from users table (riders.id references users.id)
        try {
          final riderData = await supabase
              .from('users')
              .select('full_name')
              .eq('id', entityId)
              .maybeSingle();
          
          if (riderData != null) {
            entityName = riderData['full_name'] ?? '';
          }
        } catch (e) {
          // If rider not found, leave name empty
        }
      }
      
      data['entity_name'] = entityName;
      accountsWithNames.add(data);
    }
    
    return accountsWithNames.map((data) => BlacklistedAccount.fromJson(data)).toList();
  }

  Future<void> approveReapplication(String blacklistedAccountId) async {
    final bhId = await _getCurrentBhId();
    
    await supabase
        .from('blacklisted_accounts')
        .update({
          'status': 'approved',
          'reapplication_approved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', blacklistedAccountId)
        .eq('business_hub_id', bhId);
  }

  // Business Hub Top-Up Requests to Admin
  // Reusing topup_requests table where business_hub_id is not null and loading_station_id is null
  Future<BhTopUpRequest> requestTopUpFromAdmin(double amount) async {
    final bhId = await _getCurrentBhId();
    final userId = await _authService.getToken();
    
    final response = await supabase
        .from('topup_requests')
        .insert({
          'business_hub_id': bhId,
          'loading_station_id': null, // Null to indicate this is a BH request
          'requested_by': userId,
          'requested_amount': amount,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    
    // Map topup_requests fields to BhTopUpRequest model
    final mappedData = Map<String, dynamic>.from(response as Map<String, dynamic>);
    mappedData['requested_at'] = mappedData['created_at'];
    mappedData['approved_at'] = mappedData['processed_at'];
    mappedData['rejected_at'] = mappedData['status'] == 'rejected' ? mappedData['processed_at'] : null;
    mappedData['approved_by'] = mappedData['processed_by'];
    
    return BhTopUpRequest.fromJson(mappedData);
  }

  Future<List<BhTopUpRequest>> getBhTopUpRequests({String? status}) async {
    final bhId = await _getCurrentBhId();
    
    var queryBuilder = supabase
        .from('topup_requests')
        .select()
        .eq('business_hub_id', bhId);
    
    if (status != null) {
      queryBuilder = queryBuilder.filter('status', 'eq', status);
    }
    
    final response = await queryBuilder.order('created_at', ascending: false);
    
    // Fetch Business Hub commission rate (for calculating bonus on pending requests)
    double bhCommissionRate = 0.0;
    try {
      bhCommissionRate = await getBusinessHubCommissionRate();
    } catch (e) {
      // If we can't get commission rate, will use 0.0 for calculations
    }
    
    // Filter for BH requests only (where loading_station_id is null)
    // and map topup_requests fields to BhTopUpRequest model
    final bhRequestsList = (response as List)
        .where((json) => json['loading_station_id'] == null) // Only BH requests
        .toList();
    
    // Update bonus for pending requests that don't have it calculated yet
    final updatePromises = <Future>[];
    for (var json in bhRequestsList) {
      final data = json as Map<String, dynamic>;
      final requestStatus = (data['status'] ?? 'pending').toString().toLowerCase();
      final requestId = data['id'] as String?;
      
      if (requestStatus == 'pending' && requestId != null) {
        // For pending requests, only set bonus_rate (not bonus_amount or total_credited)
        // The admin will set these values when approving
        if (data['bonus_rate'] == null) {
          // Update the database so admin panel sees the expected bonus rate
          // Round bonus_rate to 4 decimal places to avoid excessive trailing zeros
          updatePromises.add(
            supabase
                .from('topup_requests')
                .update({
                  'bonus_rate': double.parse(bhCommissionRate.toStringAsFixed(4)),
                })
                .eq('id', requestId)
                .then((_) => null)
                .catchError((_) => null) // Ignore errors
          );
        }
      }
    }
    
    // Don't wait for updates - just trigger them
    Future.wait(updatePromises).catchError((_) => null);
    
    // Map to BhTopUpRequest objects
    return bhRequestsList.map((json) {
          final mappedData = Map<String, dynamic>.from(json as Map<String, dynamic>);
          mappedData['requested_at'] = mappedData['created_at'];
          mappedData['approved_at'] = mappedData['processed_at'];
          mappedData['rejected_at'] = mappedData['status'] == 'rejected' ? mappedData['processed_at'] : null;
          mappedData['approved_by'] = mappedData['processed_by'];
          return BhTopUpRequest.fromJson(mappedData);
    }).toList();
  }

  // Get Loading Station commission rate from commission settings
  Future<double> getLoadingStationCommissionRate() async {
    try {
      // Get commission rate from commission_settings table for loading_station role
      // The role column is an enum type (role_type), so we fetch all and filter client-side
      final response = await supabase
          .from('commission_settings')
          .select('role, percentage');
      
      if (response != null && response is List) {
        for (final setting in response) {
          if (setting is! Map) continue;
          
          final role = setting['role']?.toString().toLowerCase() ?? '';
          final percentage = setting['percentage'];
          
          // Check if this is a loading_station setting
          if (role == 'loading_station') {
            if (percentage != null) {
              final percentageValue = double.tryParse(percentage.toString()) ?? 0.0;
              // Convert percentage (e.g., 10.0) to decimal (0.10)
              return percentageValue / 100;
            }
          }
        }
      }
      
      return 0.0;
    } catch (e) {
      debugPrint('Error getting loading station commission rate: $e');
      return 0.0;
    }
  }

  // Get Business Hub commission rate from commission settings
  Future<double> getBusinessHubCommissionRate() async {
    try {
      // The commission_settings table has:
      // - role: enum field (role_type) with value 'business_hub'
      // - percentage: numeric field (0-100) storing the percentage value
      
      // The role column is an enum type (role_type), so we fetch all and filter client-side
      final response = await supabase
          .from('commission_settings')
          .select('role, percentage');
      
      if (response != null && response is List) {
        for (final setting in response) {
          if (setting is! Map) continue;
          
          final role = setting['role']?.toString().toLowerCase() ?? '';
          final percentage = setting['percentage'];
          
          // Check if this is a business_hub setting
          if (role == 'business_hub') {
            if (percentage != null) {
              final percentageValue = double.tryParse(percentage.toString()) ?? 0.0;
              // Convert percentage (e.g., 30.0) to decimal (0.30)
              return percentageValue / 100;
            }
          }
        }
      }
      
      return 0.0;
    } catch (e) {
      debugPrint('Error getting business hub commission rate: $e');
      return 0.0;
    }
  }
}
