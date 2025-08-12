// lib/widgets/binding_requests_tab.dart
// 用途：绑定请求管理标签页

import 'package:flutter/material.dart';
import '../services/coach_service.dart';
import '../models/models.dart';
import '../widgets/request_card.dart';
import '../utils/snackbar_utils.dart';

class BindingRequestsTab extends StatelessWidget {
  final VoidCallback onRefreshStatistics;
  final bool? highlightNew; // ← 添加

  const BindingRequestsTab({
    Key? key,
    required this.onRefreshStatistics,
    this.highlightNew, // ← 添加
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BindingRequest>>(
      stream: CoachService.getBindingRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading binding requests...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                const Text(
                  'Error loading requests:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade600),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: onRefreshStatistics,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return _buildEmptyRequestsState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(30),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            return RequestCard(
              request: requests[index],
              onApprove: () => _handleRequest(context, requests[index].id, 'approve'),
              onReject: () => _handleRequest(context, requests[index].id, 'reject'),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyRequestsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          const Text(
            'No Pending Requests',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'New coach binding requests will appear here.\nCoaches can send requests through the mobile app.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRequest(BuildContext context, String requestId, String action) async {
    if (action == 'reject') {
      // Show reason dialog for rejection
      final reason = await _showRejectReasonDialog(context);
      if (reason != null) {
        final success = await CoachService.handleBindingRequest(
          requestId: requestId,
          action: action,
          rejectReason: reason,
        );

        if (context.mounted) {
          if (success) {
            SnackbarUtils.showSuccess(context, 'Request rejected successfully');
            onRefreshStatistics();
          } else {
            SnackbarUtils.showError(context, 'Failed to reject request');
          }
        }
      }
    } else {
      final success = await CoachService.handleBindingRequest(
        requestId: requestId,
        action: action,
      );

      if (context.mounted) {
        if (success) {
          SnackbarUtils.showSuccess(context, 'Request approved successfully');
          onRefreshStatistics();
        } else {
          SnackbarUtils.showError(context, 'Failed to approve request');
        }
      }
    }
  }

  Future<String?> _showRejectReasonDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejecting this request:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}