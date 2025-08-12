// lib/dialogs/coach_details_dialog.dart
// 用途：教练详情对话框

import 'package:flutter/material.dart';
import '../services/coach_service.dart';
import '../models/models.dart';
import '../utils/snackbar_utils.dart';

class CoachDetailsDialog extends StatefulWidget {
  final Coach coach;
  final VoidCallback onCoachUpdated;

  const CoachDetailsDialog({
    Key? key,
    required this.coach,
    required this.onCoachUpdated,
  }) : super(key: key);

  @override
  State<CoachDetailsDialog> createState() => _CoachDetailsDialogState();
}

class _CoachDetailsDialogState extends State<CoachDetailsDialog> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.purple.shade100,
            child: Text(
              widget.coach.name.isNotEmpty ? widget.coach.name[0].toUpperCase() : 'C',
              style: TextStyle(
                color: Colors.purple.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('Coach: ${widget.coach.name}'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Email', widget.coach.email),
            _buildDetailRow('Status', widget.coach.statusDisplayText),
            _buildDetailRow('Bound Gyms', '${widget.coach.boundGymCount} gym${widget.coach.boundGymCount != 1 ? 's' : ''}'),
            if (widget.coach.joinedAt != null)
              _buildDetailRow('Joined', _formatDate(widget.coach.joinedAt!)),
            const SizedBox(height: 16),
            const Text(
              'Change Status:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: widget.coach.status,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'break', child: Text('On Break')),
                      DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                    ],
                    onChanged: _isUpdating ? null : _updateCoachStatus,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: _isUpdating ? null : () => _removeCoach(context),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Remove Coach'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _updateCoachStatus(String? status) async {
    if (status == null || status == widget.coach.status) return;

    setState(() => _isUpdating = true);

    try {
      final success = await CoachService.updateCoachStatus(widget.coach.id, status);

      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
          SnackbarUtils.showSuccess(context, 'Coach status updated successfully');
          widget.onCoachUpdated();
        } else {
          SnackbarUtils.showError(context, 'Failed to update coach status');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _removeCoach(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Coach'),
        content: Text('Are you sure you want to remove ${widget.coach.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isUpdating = true);

      try {
        final success = await CoachService.removeCoach(widget.coach.id);

        if (mounted) {
          Navigator.of(context).pop(); // Close coach details dialog

          if (success) {
            SnackbarUtils.showSuccess(context, 'Coach removed successfully');
            widget.onCoachUpdated();
          } else {
            SnackbarUtils.showError(context, 'Failed to remove coach');
          }
        }
      } catch (e) {
        if (mounted) {
          SnackbarUtils.showError(context, 'Error: $e');
        }
      } finally {
        if (mounted) {
          setState(() => _isUpdating = false);
        }
      }
    }
  }
}