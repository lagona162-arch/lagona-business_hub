import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/business_hub.dart';
import '../models/transaction.dart';
import '../services/business_hub_service.dart';

class MonitoringScreen extends StatefulWidget {
  final BusinessHub user;

  const MonitoringScreen({super.key, required this.user});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  final _businessHubService = BusinessHubService();
  List<Transaction> _transactions = [];
  Map<String, dynamic> _balanceAndCashFlow = {};
  bool _isLoading = false;
  String? _errorMessage;
  final _currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
  final _dateFormat = DateFormat('MMM dd, yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final transactions = await _businessHubService.getTopUpTransactions();
      final balanceCashFlow = await _businessHubService.getBalanceAndCashFlow();

      setState(() {
        _transactions = transactions;
        _balanceAndCashFlow = balanceCashFlow;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring & Oversight'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
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
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              if (_isLoading && _transactions.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_errorMessage != null)
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _errorMessage!,
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

