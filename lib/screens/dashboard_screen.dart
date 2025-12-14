import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/business_hub.dart';
import '../services/auth_service.dart';
import '../services/business_hub_service.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';
import 'hierarchy_management_screen.dart';
import 'financial_management_screen.dart';
import 'admin_control_screen.dart';

class DashboardScreen extends StatefulWidget {
  final BusinessHub user;

  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _authService = AuthService();
  final _businessHubService = BusinessHubService();
  final _currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
  double _bonusRate = 0.0;
  bool _isLoadingRate = true;
  double _balance = 0.0;
  bool _isLoadingBalance = true;

  @override
  void initState() {
    super.initState();
    // Initialize with the balance from widget.user (fallback)
    _balance = widget.user.balance;
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoadingRate = true;
      _isLoadingBalance = true;
    });
    
    try {
      // Load commission rate
      final commissionRate = await _businessHubService.getBusinessHubCommissionRate();
      
      // Load fresh balance from database
      final balanceData = await _businessHubService.getBalanceAndCashFlow();
      final currentBalance = balanceData['current_balance'] ?? 0.0;
      
      setState(() {
        _bonusRate = commissionRate;
        _balance = currentBalance is double ? currentBalance : (double.tryParse(currentBalance.toString()) ?? 0.0);
        _isLoadingRate = false;
        _isLoadingBalance = false;
      });
    } catch (e) {
      setState(() {
        _bonusRate = 0.0;
        // Keep current balance if loading fails
        _isLoadingRate = false;
        _isLoadingBalance = false;
      });
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Hub Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, ${widget.user.name}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'BH Code: ${widget.user.bhCode}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Balance Cards
              Row(
                children: [
                  Expanded(
                    child: Card(
                      color: AppColors.primaryLight.withOpacity(0.3),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Balance',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isLoadingBalance 
                                ? '...' 
                                : _currencyFormat.format(_balance),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
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
                      color: AppColors.success.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bonus Rate',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isLoadingRate 
                                ? '...' 
                                : '${(_bonusRate * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
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
              
              // Feature Cards
              const Text(
                'Features',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              _FeatureCard(
                title: 'Hierarchy Management',
                description: 'View BHCODE and manage Loading Stations',
                icon: Icons.account_tree,
                color: AppColors.primary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HierarchyManagementScreen(user: widget.user),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              
              _FeatureCard(
                title: 'Financial Management',
                description: 'Request top-ups, approve requests, view commissions, and monitor transactions',
                icon: Icons.account_balance_wallet,
                color: AppColors.primary,
                onTap: () async {
                  // Navigate to Financial Management and refresh dashboard when returning
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FinancialManagementScreen(user: widget.user),
                    ),
                  );
                  // Refresh dashboard data when returning from Financial Management
                  _loadDashboardData();
                },
              ),
              const SizedBox(height: 12),
              
              _FeatureCard(
                title: 'Admin Control',
                description: 'Manage blacklisted account reapplications',
                icon: Icons.admin_panel_settings,
                color: AppColors.secondary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminControlScreen(user: widget.user),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

