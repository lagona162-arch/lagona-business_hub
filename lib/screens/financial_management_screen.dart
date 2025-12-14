import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/business_hub.dart';
import '../models/bh_topup_request.dart';
import '../models/topup_request.dart';
import '../models/commission.dart';
import '../models/transaction.dart';
import '../services/business_hub_service.dart';

class FinancialManagementScreen extends StatefulWidget {
  final BusinessHub user;

  const FinancialManagementScreen({super.key, required this.user});

  @override
  State<FinancialManagementScreen> createState() => _FinancialManagementScreenState();
}

class _FinancialManagementScreenState extends State<FinancialManagementScreen> with SingleTickerProviderStateMixin {
  final _businessHubService = BusinessHubService();
  late TabController _tabController;
  
  // Balance state
  double _currentBalance = 0.0;
  bool _isLoadingBalance = false;
  
  // Request Top-Up from Admin data
  List<BhTopUpRequest> _bhTopUpRequests = [];
  bool _isLoadingBhRequests = false;
  String? _errorMessageBhRequests;
  double _commissionRate = 0.0;
  bool _isLoadingCommissionRate = false;
  
  // Approve Top-Up Requests data
  List<TopUpRequest> _topUpRequests = [];
  bool _isLoadingTopUpRequests = false;
  String? _errorMessageTopUpRequests;
  double _lsCommissionRate = 0.0;
  bool _isLoadingLsCommissionRate = false;
  
  // Commission data
  List<Commission> _commissions = [];
  bool _isLoadingCommissions = false;
  String? _errorMessageCommissions;
  
  // Monitoring data
  List<Transaction> _transactions = [];
  Map<String, dynamic> _balanceAndCashFlow = {};
  bool _isLoadingMonitoring = false;
  String? _errorMessageMonitoring;
  
  final _currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
  final _dateFormat = DateFormat('MMM dd, yyyy HH:mm');
  final _dateOnlyFormat = DateFormat('MMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    _currentBalance = widget.user.balance; // Initialize with passed balance
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 0) {
        _loadBhTopUpRequests();
      } else if (_tabController.index == 1) {
        _loadTopUpRequests();
        _loadCommissions(); // Load commissions when viewing top-up requests
      } else if (_tabController.index == 2) {
        _loadMonitoringData();
      }
    });
    _loadBalance(); // Load fresh balance on init
    _loadBhTopUpRequests();
  }
  
  // Load fresh balance from database
  Future<void> _loadBalance() async {
    setState(() {
      _isLoadingBalance = true;
    });
    
    try {
      final balanceData = await _businessHubService.getBalanceAndCashFlow();
      final currentBalance = balanceData['current_balance'] ?? widget.user.balance;
      setState(() {
        _currentBalance = currentBalance is double 
            ? currentBalance 
            : (double.tryParse(currentBalance.toString()) ?? widget.user.balance);
        _isLoadingBalance = false;
      });
    } catch (e) {
      // If loading fails, keep current balance
      setState(() {
        _isLoadingBalance = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ========== Request Top-Up from Admin Methods ==========
  Future<void> _loadBhTopUpRequests() async {
    setState(() {
      _isLoadingBhRequests = true;
      _errorMessageBhRequests = null;
    });

    try {
      final requests = await _businessHubService.getBhTopUpRequests();
      // Also load commission rate for computation display
      if (!_isLoadingCommissionRate && _commissionRate == 0.0) {
        try {
          final rate = await _businessHubService.getBusinessHubCommissionRate();
          setState(() {
            _commissionRate = rate;
          });
        } catch (_) {
          // Ignore errors loading commission rate
        }
      }
      setState(() {
        _bhTopUpRequests = requests;
        _isLoadingBhRequests = false;
      });
    } catch (e) {
      setState(() {
        _errorMessageBhRequests = e.toString().replaceAll('Exception: ', '');
        _isLoadingBhRequests = false;
      });
    }
  }

  Future<void> _showRequestDialog() async {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Top-Up from Admin'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the amount you want to request. Admin will review and approve/reject your request.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Requested Amount (₱)',
                  prefixText: '₱',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., 5000',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  if (amount < 100) {
                    return 'Minimum request is ₱100';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final amount = double.parse(amountController.text);
                Navigator.pop(context);
                await _requestTopUp(amount);
              }
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestTopUp(double amount) async {
    setState(() {
      _isLoadingBhRequests = true;
      _errorMessageBhRequests = null;
    });

    try {
      await _businessHubService.requestTopUpFromAdmin(amount);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Top-up request submitted: ${_currencyFormat.format(amount)}. Waiting for admin approval.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        _loadBhTopUpRequests();
      }
    } catch (e) {
      setState(() {
        _errorMessageBhRequests = e.toString().replaceAll('Exception: ', '');
        _isLoadingBhRequests = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ========== Approve Top-Up Requests Methods ==========
  Future<void> _loadTopUpRequests() async {
    setState(() {
      _isLoadingTopUpRequests = true;
      _errorMessageTopUpRequests = null;
    });

    try {
      // Always load Loading Station commission rate for computation display
      // Load it in parallel with requests to avoid blocking
      final requestsFuture = _businessHubService.getTopUpRequests();
      final rateFuture = _businessHubService.getLoadingStationCommissionRate();
      
      final results = await Future.wait([requestsFuture, rateFuture]);
      final requests = results[0] as List<TopUpRequest>;
      final rate = results[1] as double;
      
      setState(() {
        _topUpRequests = requests;
        _lsCommissionRate = rate; // Update rate even if it was loaded before
        _isLoadingTopUpRequests = false;
        // Clear any previous errors if we successfully loaded (even if empty)
        if (requests.isNotEmpty || _errorMessageTopUpRequests != null) {
          _errorMessageTopUpRequests = null;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessageTopUpRequests = 'Error loading requests: ${e.toString().replaceAll('Exception: ', '')}';
        _isLoadingTopUpRequests = false;
      });
    }
  }

  Future<void> _loadTopUpRequestsAndCommissions() async {
    await Future.wait([
      _loadTopUpRequests(),
      _loadCommissions(),
    ]);
  }

  Future<void> _approveRequest(TopUpRequest request) async {
    // Get Loading Station commission rate for computation
    double lsCommissionRate = 0.0;
    try {
      lsCommissionRate = await _businessHubService.getLoadingStationCommissionRate();
    } catch (e) {
      lsCommissionRate = 0.0;
    }
    
    final bonusAmount = request.amount * lsCommissionRate;
    final totalCredited = request.amount + bonusAmount;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Top-Up Request'),
        content: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Loading Station: ${request.loadingStationName}'),
            Text('Code: ${request.loadingStationCode}'),
              const SizedBox(height: 16),
              
              // Computation Breakdown
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Credit Computation:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Commission Rate (set by admin)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Commission Rate (LS):',
                          style: TextStyle(fontSize: 13),
                        ),
                        Text(
                          '${(lsCommissionRate * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '(Set by Admin)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    
                    // Request Amount
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Request Amount:',
                          style: TextStyle(fontSize: 13),
                        ),
                        Text(
                          _currencyFormat.format(request.amount),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    
            const SizedBox(height: 8),
                    
                    // Bonus
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
            Text(
                          'Bonus (${(lsCommissionRate * 100).toStringAsFixed(1)}%):',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          _currencyFormat.format(bonusAmount),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.green.shade700,
                          ),
            ),
                      ],
                    ),
                    
            const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    
                    // Total Credited
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Credited to LS:',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
            Text(
                          _currencyFormat.format(totalCredited),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Balance Impact Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Balance Impact:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Deducted from your balance: ${_currencyFormat.format(totalCredited)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Credited to Loading Station: ${_currencyFormat.format(totalCredited)}',
                      style: const TextStyle(fontSize: 12),
            ),
          ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoadingTopUpRequests = true;
        _errorMessageTopUpRequests = null;
      });

      try {
        await _businessHubService.approveTopUpRequest(request.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Top-up request approved for ${request.loadingStationName}'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh balance and requests after approval
          await Future.wait([
            _loadBalance(),
            _loadTopUpRequests(),
          ]);
        }
      } catch (e) {
        setState(() {
          _errorMessageTopUpRequests = e.toString().replaceAll('Exception: ', '');
          _isLoadingTopUpRequests = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _rejectRequest(TopUpRequest request) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Top-Up Request'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Loading Station: ${request.loadingStationName}'),
              Text('Amount: ${_currencyFormat.format(request.amount)}'),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason',
                  hintText: 'Enter reason for rejection',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide a reason';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.isNotEmpty) {
      setState(() {
        _isLoadingTopUpRequests = true;
        _errorMessageTopUpRequests = null;
      });

      try {
        await _businessHubService.rejectTopUpRequest(request.id, reasonController.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Top-up request rejected for ${request.loadingStationName}'),
              backgroundColor: Colors.orange,
            ),
          );
          _loadTopUpRequests();
        }
      } catch (e) {
        setState(() {
          _errorMessageTopUpRequests = e.toString().replaceAll('Exception: ', '');
          _isLoadingTopUpRequests = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ========== Commission Methods ==========
  Future<void> _loadCommissions() async {
    setState(() {
      _isLoadingCommissions = true;
      _errorMessageCommissions = null;
    });

    try {
      final commissions = await _businessHubService.getCommissions();
      setState(() {
        _commissions = commissions;
        _isLoadingCommissions = false;
      });
    } catch (e) {
      setState(() {
        _errorMessageCommissions = e.toString().replaceAll('Exception: ', '');
        _isLoadingCommissions = false;
      });
    }
  }

  // ========== Monitoring Methods ==========
  Future<void> _loadMonitoringData() async {
    setState(() {
      _isLoadingMonitoring = true;
      _errorMessageMonitoring = null;
    });

    try {
      final transactions = await _businessHubService.getTopUpTransactions();
      final balanceCashFlow = await _businessHubService.getBalanceAndCashFlow();

      setState(() {
        _transactions = transactions;
        _balanceAndCashFlow = balanceCashFlow;
        _isLoadingMonitoring = false;
      });
    } catch (e) {
      setState(() {
        _errorMessageMonitoring = e.toString().replaceAll('Exception: ', '');
        _isLoadingMonitoring = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Management'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 11,
          ),
          tabs: const [
            Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.request_quote, size: 16),
                  SizedBox(height: 2),
                  Flexible(
                    child: Text(
                      'Request Top-Up',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
            Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet, size: 16),
                  SizedBox(height: 2),
                  Flexible(
                    child: Text(
                      'Top-Up & Commissions',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
            Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics, size: 16),
                  SizedBox(height: 2),
                  Flexible(
                    child: Text(
                      'Monitoring',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestTopUpTab(),
          _buildTopUpAndCommissionsTab(),
          _buildMonitoringTab(),
        ],
      ),
    );
  }

  // ========== Tab Builders ==========
  Widget _buildRequestTopUpTab() {
    final pendingRequests = _bhTopUpRequests.where((r) => r.status == 'pending').toList();
    final approvedRequests = _bhTopUpRequests.where((r) => r.status == 'approved').toList();
    final rejectedRequests = _bhTopUpRequests.where((r) => r.status == 'rejected').toList();

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _loadBalance(),
          _loadBhTopUpRequests(),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.account_balance_wallet, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Current Balance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _isLoadingBalance
                        ? const CircularProgressIndicator()
                        : Text(
                            _currencyFormat.format(_currentBalance),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Request top-up from admin to increase your balance',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Request Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoadingBhRequests ? null : _showRequestDialog,
                icon: const Icon(Icons.add_circle),
                label: const Text('Request Top-Up from Admin'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (_errorMessageBhRequests != null)
              Card(
                color: Colors.red.shade50,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _errorMessageBhRequests!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),

            // Pending Requests
            if (pendingRequests.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pending Requests',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${pendingRequests.length}',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...pendingRequests.map((request) => _buildBhRequestCard(request)),
              const SizedBox(height: 24),
            ],

            // Approved Requests (Grouped by Date)
            if (approvedRequests.isNotEmpty) ...[
              Card(
                child: ExpansionTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Approved Requests',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${approvedRequests.length}',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  initiallyExpanded: false,
                  children: [
                    ..._buildGroupedBhRequestsByDate(approvedRequests),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Rejected Requests
            if (rejectedRequests.isNotEmpty) ...[
              const Text(
                'Rejected Requests',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...rejectedRequests.map((request) => _buildBhRequestCard(request)),
            ],

            if (_isLoadingBhRequests && _bhTopUpRequests.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_bhTopUpRequests.isEmpty && !_isLoadingBhRequests)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No top-up requests yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Request a top-up from admin to increase your balance',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopUpAndCommissionsTab() {
    // Calculate total commissions
    final totalCommissions = _commissions.fold<double>(
      0,
      (sum, commission) => sum + commission.commissionAmount,
    );
    final totalBonuses = _commissions.fold<double>(
      0,
      (sum, commission) => sum + commission.bonusAmount,
    );
    final pendingRequests = _topUpRequests.where((r) => r.status == 'pending').toList();
    final approvedRequests = _topUpRequests.where((r) => r.status == 'approved').toList();
    final rejectedRequests = _topUpRequests.where((r) => r.status == 'rejected').toList();

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _loadBalance(),
          _loadTopUpRequestsAndCommissions(),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.account_balance_wallet, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Current Balance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _currencyFormat.format(_currentBalance),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Commission Summary Cards
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Commission',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currencyFormat.format(totalCommissions),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Bonuses',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currencyFormat.format(totalBonuses),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Pending Requests
            if (pendingRequests.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pending Requests',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${pendingRequests.length}',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...pendingRequests.map((request) => _buildTopUpRequestCard(request, showActions: true)),
              const SizedBox(height: 24),
            ],

            // Approved Requests with Commission History (Grouped by Date)
            if (approvedRequests.isNotEmpty) ...[
              Card(
                child: ExpansionTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Approved Requests',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${approvedRequests.length}',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  initiallyExpanded: false,
                  children: [
                    ..._buildGroupedTopUpRequestsByDate(approvedRequests),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Commission History Section
            if (_commissions.isNotEmpty) ...[
              const Text(
                'Commission History',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ..._commissions.map((commission) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: const Icon(Icons.trending_up, color: Colors.blue),
                      ),
                      title: Text(
                        'Commission from ${commission.sourceType}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rate: ${(commission.commissionRate * 100).toStringAsFixed(2)}%'),
                          Text('Date: ${DateFormat('MMM dd, yyyy').format(commission.createdAt)}'),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _currencyFormat.format(commission.commissionAmount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (commission.bonusAmount > 0)
                            Text(
                              '+${_currencyFormat.format(commission.bonusAmount)} bonus',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  )),
            ],

            // Rejected Requests
            if (rejectedRequests.isNotEmpty) ...[
              const Text(
                'Rejected Requests',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...rejectedRequests.map((request) => _buildTopUpRequestCard(request)),
            ],

            if (_isLoadingTopUpRequests && _topUpRequests.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessageTopUpRequests != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _errorMessageTopUpRequests!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            else if (_topUpRequests.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No top-up requests',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitoringTab() {
    return RefreshIndicator(
      onRefresh: _loadMonitoringData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance and Cash Flow Summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.analytics, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Balance & Cash Flow',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_balanceAndCashFlow.isNotEmpty) ...[
                      _buildStatRow(
                        'Total Loading Balance',
                        _currencyFormat.format(_balanceAndCashFlow['total_loading_balance'] ?? 0.0),
                        Colors.blue,
                      ),
                      const Divider(),
                      _buildStatRow(
                        'Total Cash Flow (This Month)',
                        _currencyFormat.format(_balanceAndCashFlow['monthly_cashflow'] ?? 0.0),
                        Colors.green,
                      ),
                      const Divider(),
                      _buildStatRow(
                        'Total Transactions',
                        (_balanceAndCashFlow['total_transactions'] ?? 0).toString(),
                        Colors.purple,
                      ),
                    ] else
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Top-Up Transactions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Top-Up Transactions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _loadMonitoringData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            if (_isLoadingMonitoring && _transactions.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessageMonitoring != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _errorMessageMonitoring!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            else if (_transactions.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ..._transactions.map((transaction) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getTransactionColor(transaction.type).withOpacity(0.2),
                        child: Icon(
                          _getTransactionIcon(transaction.type),
                          color: _getTransactionColor(transaction.type),
                        ),
                      ),
                      title: Text(
                        _getTransactionTitle(transaction),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (transaction.fromEntityName != null)
                            Text('From: ${transaction.fromEntityName}'),
                          Text('Date: ${_dateFormat.format(transaction.createdAt)}'),
                          Text(
                            'Status: ${transaction.status.toUpperCase()}',
                            style: TextStyle(
                              color: transaction.status == 'completed'
                                  ? Colors.green
                                  : transaction.status == 'pending'
                                      ? Colors.orange
                                      : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _currencyFormat.format(transaction.amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (transaction.bonusAmount > 0)
                            Text(
                              '+${_currencyFormat.format(transaction.bonusAmount)} bonus',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  // ========== Helper Functions ==========
  // Group approved requests by date
  Map<String, List<BhTopUpRequest>> _groupBhRequestsByDate(List<BhTopUpRequest> requests) {
    final Map<String, List<BhTopUpRequest>> grouped = {};
    
    for (final request in requests) {
      if (request.approvedAt != null) {
        final dateKey = _dateOnlyFormat.format(request.approvedAt!);
        grouped.putIfAbsent(dateKey, () => []).add(request);
      }
    }
    
    // Sort requests within each date group by approvedAt (newest first)
    grouped.forEach((key, value) {
      value.sort((a, b) {
        if (a.approvedAt == null || b.approvedAt == null) return 0;
        return b.approvedAt!.compareTo(a.approvedAt!);
      });
    });
    
    return grouped;
  }
  
  // Group approved top-up requests by date
  Map<String, List<TopUpRequest>> _groupTopUpRequestsByDate(List<TopUpRequest> requests) {
    final Map<String, List<TopUpRequest>> grouped = {};
    
    for (final request in requests) {
      if (request.approvedAt != null) {
        final dateKey = _dateOnlyFormat.format(request.approvedAt!);
        grouped.putIfAbsent(dateKey, () => []).add(request);
      }
    }
    
    // Sort requests within each date group by approvedAt (newest first)
    grouped.forEach((key, value) {
      value.sort((a, b) {
        if (a.approvedAt == null || b.approvedAt == null) return 0;
        return b.approvedAt!.compareTo(a.approvedAt!);
      });
    });
    
    return grouped;
  }
  
  // Build grouped BH requests by date as ExpansionTiles
  List<Widget> _buildGroupedBhRequestsByDate(List<BhTopUpRequest> requests) {
    final grouped = _groupBhRequestsByDate(requests);
    final sortedDates = grouped.keys.toList()..sort((a, b) {
      // Sort dates in descending order (newest first)
      try {
        final dateA = _dateOnlyFormat.parse(a);
        final dateB = _dateOnlyFormat.parse(b);
        return dateB.compareTo(dateA);
      } catch (e) {
        return b.compareTo(a);
      }
    });
    
    return sortedDates.map((dateKey) {
      final dateRequests = grouped[dateKey]!;
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ExpansionTile(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateKey,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${dateRequests.length}',
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          initiallyExpanded: false,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                children: dateRequests.map((request) => _buildBhRequestCard(request)).toList(),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
  
  // Build grouped TopUp requests by date as ExpansionTiles
  List<Widget> _buildGroupedTopUpRequestsByDate(List<TopUpRequest> requests) {
    final grouped = _groupTopUpRequestsByDate(requests);
    final sortedDates = grouped.keys.toList()..sort((a, b) {
      // Sort dates in descending order (newest first)
      try {
        final dateA = _dateOnlyFormat.parse(a);
        final dateB = _dateOnlyFormat.parse(b);
        return dateB.compareTo(dateA);
      } catch (e) {
        return b.compareTo(a);
      }
    });
    
    return sortedDates.map((dateKey) {
      final dateRequests = grouped[dateKey]!;
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ExpansionTile(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateKey,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${dateRequests.length}',
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          initiallyExpanded: false,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                children: dateRequests.map((request) => _buildTopUpRequestCard(request)).toList(),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // ========== Helper Widgets ==========
  Widget _buildBhRequestCard(BhTopUpRequest request) {
    final statusColor = request.status == 'approved'
        ? Colors.green
        : request.status == 'rejected'
            ? Colors.red
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.2),
                  child: Icon(
                    request.status == 'approved'
                        ? Icons.check_circle
                        : request.status == 'rejected'
                            ? Icons.cancel
                            : Icons.pending,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currencyFormat.format(request.requestedAmount),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Requested: ${_dateFormat.format(request.requestedAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (request.status == 'approved') ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              
              // Approval Info
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Approved',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          request.approvedAt != null
                              ? 'Approved on ${_dateFormat.format(request.approvedAt!)}'
                              : 'Approved',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (request.approvedBy != null)
                          Text(
                            'By: ${request.approvedBy}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            if (request.status == 'rejected' && request.rejectionReason != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rejection Reason:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            request.rejectionReason!,
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (request.rejectedAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Rejected on ${_dateFormat.format(request.rejectedAt!)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopUpRequestCard(TopUpRequest request, {bool showActions = false}) {
    final statusColor = request.status == 'approved'
        ? Colors.green
        : request.status == 'rejected'
            ? Colors.red
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.2),
                  child: Icon(
                    request.status == 'approved'
                        ? Icons.check_circle
                        : request.status == 'rejected'
                            ? Icons.cancel
                            : Icons.pending,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.loadingStationName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'LS Code: ${request.loadingStationCode}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Amount',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(request.amount),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Requested',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      _dateFormat.format(request.requestedAt),
                      style: const TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            // Show commission breakdown for pending requests (preview) and approved requests
            if (request.status == 'pending' || request.status == 'approved') ...[
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  // Calculate commission rate to use (for pending: use loaded rate, for approved: use stored rate or loaded rate)
                  final commissionRate = request.status == 'approved' 
                      ? (request.bonusRate ?? _lsCommissionRate)
                      : _lsCommissionRate;
                  
                  // Calculate bonus amount
                  final bonusAmount = request.status == 'approved'
                      ? (request.bonusAmount ?? (request.amount * commissionRate))
                      : (request.amount * commissionRate);
                  
                  // Calculate total credited
                  final totalCredited = request.status == 'approved'
                      ? (request.totalCredited ?? (request.amount + bonusAmount))
                      : (request.amount + bonusAmount);
                  
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.status == 'pending' ? 'Credit Computation Preview:' : 'Commission Breakdown:',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Commission Rate (set by admin)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Commission Rate (LS):',
                              style: TextStyle(fontSize: 13),
                            ),
                            Text(
                              '${(commissionRate * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '(Set by Admin)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        
                        // Request Amount
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Request Amount:',
                              style: TextStyle(fontSize: 13),
                            ),
                            Text(
                              _currencyFormat.format(request.amount),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Bonus calculation
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Bonus (${(commissionRate * 100).toStringAsFixed(1)}%):',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              _currencyFormat.format(bonusAmount),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        
                        // Total Credited to Loading Station
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              request.status == 'pending' ? 'Total to Credit to LS:' : 'Total Credited:',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _currencyFormat.format(totalCredited),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            
            if (request.status == 'approved') ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              
              // Approval Info
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Approved',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          request.approvedAt != null
                              ? 'Approved on ${_dateFormat.format(request.approvedAt!)}'
                              : 'Approved',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            if (request.rejectionReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rejection Reason:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            request.rejectionReason!,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (showActions) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoadingTopUpRequests ? null : () => _rejectRequest(request),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoadingTopUpRequests ? null : () => _approveRequest(request),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getTransactionTitle(Transaction transaction) {
    switch (transaction.type) {
      case 'topup':
        return 'Top-Up Transaction';
      case 'commission':
        return 'Commission';
      case 'bonus':
        return 'Bonus Credit';
      default:
        return 'Transaction';
    }
  }

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'topup':
        return Icons.account_balance_wallet;
      case 'commission':
        return Icons.trending_up;
      case 'bonus':
        return Icons.card_giftcard;
      default:
        return Icons.receipt;
    }
  }

  Color _getTransactionColor(String type) {
    switch (type) {
      case 'topup':
        return Colors.blue;
      case 'commission':
        return Colors.green;
      case 'bonus':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

