import 'package:supabase_flutter/supabase_flutter.dart';
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
    
    var queryBuilder = supabase
        .from('topup_requests')
        .select('''
          *,
          loading_stations!inner(name, ls_code)
        ''')
        .eq('business_hub_id', bhId);
    
    if (status != null) {
      queryBuilder = queryBuilder.filter('status', 'eq', status);
    }
    
    final response = await queryBuilder.order('created_at', ascending: false);
    
    return (response as List).map((json) {
      final data = Map<String, dynamic>.from(json);
      // Map nested loading station data
      if (data['loading_stations'] != null) {
        final ls = data['loading_stations'] as Map<String, dynamic>;
        data['loading_station_name'] = ls['name'];
        data['loading_station_code'] = ls['ls_code'];
      }
      // Map topup_requests table fields to TopUpRequest model
      if (data['requested_at'] == null && data['created_at'] != null) {
        data['requested_at'] = data['created_at'];
      }
      if (data['amount'] == null && data['requested_amount'] != null) {
        data['amount'] = data['requested_amount'];
      }
      if (data['approved_at'] == null && data['processed_at'] != null && data['status'] == 'approved') {
        data['approved_at'] = data['processed_at'];
      }
      if (data['rejected_at'] == null && data['processed_at'] != null && data['status'] == 'rejected') {
        data['rejected_at'] = data['processed_at'];
      }
      return TopUpRequest.fromJson(data);
    }).toList();
  }

  Future<void> approveTopUpRequest(String requestId) async {
    final bhId = await _getCurrentBhId();
    
    // Start a transaction (Supabase supports transactions via RPC)
    await supabase.rpc('approve_topup_request', params: {
      'request_id': requestId,
      'bh_id': bhId,
    });
  }

  Future<void> rejectTopUpRequest(String requestId, String reason) async {
    final bhId = await _getCurrentBhId();
    
    await supabase
        .from('topup_requests')
        .update({
          'status': 'rejected',
          'rejection_reason': reason,
          'rejected_at': DateTime.now().toIso8601String(),
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
    
    // Filter for BH requests only (where loading_station_id is null)
    // and map topup_requests fields to BhTopUpRequest model
    return (response as List)
        .where((json) => json['loading_station_id'] == null) // Only BH requests
        .map((json) {
          final mappedData = Map<String, dynamic>.from(json as Map<String, dynamic>);
          mappedData['requested_at'] = mappedData['created_at'];
          mappedData['approved_at'] = mappedData['processed_at'];
          mappedData['rejected_at'] = mappedData['status'] == 'rejected' ? mappedData['processed_at'] : null;
          mappedData['approved_by'] = mappedData['processed_by'];
          return BhTopUpRequest.fromJson(mappedData);
        })
        .toList();
  }
}
