import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/business_hub.dart';
import '../models/loading_station.dart';
import '../services/business_hub_service.dart';
import '../theme/app_colors.dart';

class HierarchyManagementScreen extends StatefulWidget {
  final BusinessHub user;

  const HierarchyManagementScreen({super.key, required this.user});

  @override
  State<HierarchyManagementScreen> createState() => _HierarchyManagementScreenState();
}

class _HierarchyManagementScreenState extends State<HierarchyManagementScreen> {
  final _businessHubService = BusinessHubService();
  List<LoadingStation> _loadingStations = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLoadingStations();
  }

  Future<void> _loadLoadingStations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final stations = await _businessHubService.getLoadingStations();
      setState(() {
        _loadingStations = stations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hierarchy Management'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadLoadingStations,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BHCODE Display Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.qr_code, color: AppColors.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'Business Hub Code',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your BHCODE is automatically generated and assigned by the admin during registration. Use it to manage all Loading Stations within your area.',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.user.bhCode,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () => _copyToClipboard(widget.user.bhCode),
                              tooltip: 'Copy BHCODE',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Loading Stations List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Loading Stations',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _loadLoadingStations,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              if (_isLoading && _loadingStations.isEmpty)
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
              else if (_loadingStations.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No Loading Stations found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Loading Stations will appear here once they are registered under your BHCODE.',
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
                )
              else
                ..._loadingStations.map((station) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: station.status == 'active'
                              ? AppColors.success.withOpacity(0.2)
                              : AppColors.error.withOpacity(0.2),
                          child: Icon(
                            station.status == 'active'
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: station.status == 'active' ? AppColors.success : AppColors.error,
                          ),
                        ),
                        title: Text(
                          station.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('LS Code: ${station.lsCode}'),
                            Text('Balance: ₱${station.balance.toStringAsFixed(2)}'),
                          ],
                        ),
                        trailing: Text(
                          station.status.toUpperCase(),
                          style: TextStyle(
                            color: station.status == 'active' ? AppColors.success : AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}
