import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/business_hub.dart';
import '../models/blacklisted_account.dart';
import '../services/business_hub_service.dart';

class AdminControlScreen extends StatefulWidget {
  final BusinessHub user;

  const AdminControlScreen({super.key, required this.user});

  @override
  State<AdminControlScreen> createState() => _AdminControlScreenState();
}

class _AdminControlScreenState extends State<AdminControlScreen> {
  final _businessHubService = BusinessHubService();
  List<BlacklistedAccount> _blacklistedAccounts = [];
  bool _isLoading = false;
  String? _errorMessage;
  final _dateFormat = DateFormat('MMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    _loadBlacklistedAccounts();
  }

  Future<void> _loadBlacklistedAccounts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final accounts = await _businessHubService.getBlacklistedAccounts();
      setState(() {
        _blacklistedAccounts = accounts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _approveReapplication(BlacklistedAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Reapplication'),
        content: Text(
          'Are you sure you want to allow ${account.entityName} to reapply?',
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
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        await _businessHubService.approveReapplication(account.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reapplication approved for ${account.entityName}'),
              backgroundColor: Colors.green,
            ),
          );
          _loadBlacklistedAccounts();
        }
      } catch (e) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter accounts by status
    final pendingReapplications = _blacklistedAccounts
        .where((account) => account.status == 'pending_reapplication')
        .toList();
    final blacklisted = _blacklistedAccounts
        .where((account) => account.status == 'blacklisted')
        .toList();
    final approved = _blacklistedAccounts
        .where((account) => account.status == 'approved')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Control'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadBlacklistedAccounts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.admin_panel_settings, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Blacklist Management',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Manage blacklisted accounts and approve reapplications for Loading Stations and Riders.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              if (_isLoading && _blacklistedAccounts.isEmpty)
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
              else ...[
                // Pending Reapplications
                if (pendingReapplications.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pending Reapplications',
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
                          '${pendingReapplications.length}',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...pendingReapplications.map((account) => _buildAccountCard(
                        account,
                        showApproveButton: true,
                      )),
                  const SizedBox(height: 24),
                ],
                
                // Blacklisted Accounts
                if (blacklisted.isNotEmpty) ...[
                  const Text(
                    'Blacklisted Accounts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...blacklisted.map((account) => _buildAccountCard(account)),
                  const SizedBox(height: 24),
                ],
                
                // Approved Reapplications
                if (approved.isNotEmpty) ...[
                  const Text(
                    'Approved Reapplications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...approved.map((account) => _buildAccountCard(account)),
                ],
                
                if (_blacklistedAccounts.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.check_circle, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No blacklisted accounts',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard(BlacklistedAccount account, {bool showApproveButton = false}) {
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
                  backgroundColor: _getStatusColor(account.status).withOpacity(0.2),
                  child: Icon(
                    _getStatusIcon(account.status),
                    color: _getStatusColor(account.status),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.entityName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        account.entityType.replaceAll('_', ' ').toUpperCase(),
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
                    color: _getStatusColor(account.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    account.status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(account.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            _buildInfoRow('Blacklisted On', _dateFormat.format(account.blacklistedAt)),
            _buildInfoRow('Reason', account.reason),
            if (account.reapplicationRequestedAt != null)
              _buildInfoRow(
                'Reapplication Requested',
                _dateFormat.format(account.reapplicationRequestedAt!),
              ),
            if (account.reapplicationApprovedAt != null)
              _buildInfoRow(
                'Reapplication Approved',
                _dateFormat.format(account.reapplicationApprovedAt!),
              ),
            if (showApproveButton) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _approveReapplication(account),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Approve Reapplication'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'blacklisted':
        return Colors.red;
      case 'pending_reapplication':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'blacklisted':
        return Icons.block;
      case 'pending_reapplication':
        return Icons.pending;
      case 'approved':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }
}

