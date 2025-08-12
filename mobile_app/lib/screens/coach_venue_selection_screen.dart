// lib/screens/coach_venue_selection_screen.dart
// 用途：教练选择健身房并发送绑定/解绑请求（直接从gym_center集合获取数据）
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/coach_service.dart';

class CoachVenueSelectionScreen extends StatefulWidget {
  const CoachVenueSelectionScreen({super.key});

  @override
  State<CoachVenueSelectionScreen> createState() => _CoachVenueSelectionScreenState();
}

class _CoachVenueSelectionScreenState extends State<CoachVenueSelectionScreen>
    with TickerProviderStateMixin {
  final currentUser = FirebaseAuth.instance.currentUser;

  // 跟踪不同状态的健身房
  Set<String> pendingBindRequests = {}; // 待批准的绑定请求
  Set<String> boundGyms = {}; // 已绑定的健身房
  Set<String> pendingUnbindRequests = {}; // 待批准的解绑请求

  bool _isLoading = true;
  String? _expandedGymId; // 跟踪当前展开的健身房卡片

  // 健身房信息列表
  List<GymCenterInfo> _gymCenters = [];

  @override
  void initState() {
    super.initState();
    _loadCoachStatus();
    _loadGymCenters();
  }

  Future<void> _loadCoachStatus() async {
    if (currentUser == null) return;

    try {
      // 1. 获取所有绑定请求状态
      final allRequests = await FirebaseFirestore.instance
          .collection('binding_requests')
          .where('coachId', isEqualTo: currentUser!.uid)
          .get();

      Set<String> pendingBinds = {};
      Set<String> pendingUnbinds = {};

      for (var doc in allRequests.docs) {
        final data = doc.data();
        final gymId = data['gymId'] as String;
        final status = data['status'] as String;
        final requestType = data['type'] as String? ?? 'bind'; // 默认为绑定类型

        if (status == 'pending') {
          if (requestType == 'bind') {
            pendingBinds.add(gymId);
          } else if (requestType == 'unbind') {
            pendingUnbinds.add(gymId);
          }
        }
      }

      // 2. 检查教练当前绑定的健身房
      final coachDoc = await FirebaseFirestore.instance
          .collection('coaches')
          .doc(currentUser!.uid)
          .get();

      Set<String> currentBoundGyms = {};
      if (coachDoc.exists) {
        final data = coachDoc.data()!;
        // 支持单个或多个健身房绑定
        if (data['assignedGymId'] != null) {
          currentBoundGyms.add(data['assignedGymId']);
        }
        // 如果有多个健身房绑定的字段
        if (data['boundGyms'] != null) {
          final boundGymsList = List<String>.from(data['boundGyms']);
          currentBoundGyms.addAll(boundGymsList);
        }
      }

      setState(() {
        pendingBindRequests = pendingBinds;
        boundGyms = currentBoundGyms;
        pendingUnbindRequests = pendingUnbinds;
      });
    } catch (e) {
      print('Error loading coach status: $e');
    }
  }

  Future<void> _loadGymCenters() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('gym_info')
          .get();

      List<GymCenterInfo> gymCenters = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        gymCenters.add(GymCenterInfo.fromFirestore(doc.id, data));
      }

      setState(() {
        _gymCenters = gymCenters;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading gym centers: $e');
      setState(() => _isLoading = false);
    }
  }

  void _toggleExpansion(String gymId) {
    setState(() {
      if (_expandedGymId == gymId) {
        _expandedGymId = null;
      } else {
        _expandedGymId = gymId;
      }
    });
  }

  // 获取健身房的状态
  GymStatus _getGymStatus(String gymId) {
    if (boundGyms.contains(gymId)) {
      if (pendingUnbindRequests.contains(gymId)) {
        return GymStatus.boundWithPendingUnbind;
      }
      return GymStatus.bound;
    } else if (pendingBindRequests.contains(gymId)) {
      return GymStatus.pendingBind;
    }
    return GymStatus.unbound;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Gym Center'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _gymCenters.isEmpty
          ? _buildNoGymAvailable()
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 30),
            _buildGymCentersList(),
            const SizedBox(height: 30),
            _buildMyRequestsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final boundCount = boundGyms.length;
    final pendingCount = pendingBindRequests.length + pendingUnbindRequests.length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade600, Colors.purple.shade800],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.fitness_center,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gym Center Management',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Bound to $boundCount gym${boundCount != 1 ? 's' : ''} • $pendingCount pending request${pendingCount != 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoGymAvailable() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.store_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          const Text(
            'No Gym Centers Available',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'No gym centers found in the system.\nPlease contact the administrator.',
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

  Widget _buildGymCentersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Gym Centers (${_gymCenters.length})',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        ..._gymCenters.map((gymCenter) {
          final isExpanded = _expandedGymId == gymCenter.id;
          final status = _getGymStatus(gymCenter.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildExpandableGymCard(gymCenter, isExpanded, status),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildExpandableGymCard(GymCenterInfo gymCenter, bool isExpanded, GymStatus status) {
    // 根据状态确定卡片样式
    Color headerStartColor;
    Color headerEndColor;
    Color borderColor;

    switch (status) {
      case GymStatus.bound:
        headerStartColor = Colors.green.shade600;
        headerEndColor = Colors.green.shade800;
        borderColor = Colors.green.shade300;
        break;
      case GymStatus.boundWithPendingUnbind:
        headerStartColor = Colors.orange.shade600;
        headerEndColor = Colors.orange.shade800;
        borderColor = Colors.orange.shade300;
        break;
      case GymStatus.pendingBind:
        headerStartColor = Colors.blue.shade600;
        headerEndColor = Colors.blue.shade800;
        borderColor = Colors.blue.shade300;
        break;
      default:
        headerStartColor = isExpanded ? Colors.purple.shade600 : Colors.blue.shade600;
        headerEndColor = isExpanded ? Colors.purple.shade800 : Colors.blue.shade800;
        borderColor = Colors.grey.shade300;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isExpanded ? borderColor.withOpacity(0.3) : Colors.grey.shade200,
            blurRadius: isExpanded ? 20 : 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: status != GymStatus.unbound ? borderColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 可点击的头部
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleExpansion(gymCenter.id),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [headerStartColor, headerEndColor],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getStatusIcon(status),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  gymCenter.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getStatusText(status),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (gymCenter.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              gymCenter.description,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // 展开/收起指示器
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 可展开的详细内容
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: _buildCollapsedContent(status),
            ),
            secondChild: Padding(
              padding: const EdgeInsets.all(24),
              child: _buildExpandedContent(gymCenter, status),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedContent(GymStatus status) {
    switch (status) {
      case GymStatus.bound:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You are currently bound to this gym center',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      case GymStatus.boundWithPendingUnbind:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.pending,
                color: Colors.orange.shade600,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Unbind request pending approval',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      case GymStatus.pendingBind:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.schedule,
                color: Colors.blue.shade600,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bind request pending approval',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      default:
        return Text(
          'Tap to view details and send bind request',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        );
    }
  }

  Widget _buildExpandedContent(GymCenterInfo gymCenter, GymStatus status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 详细信息
        if (gymCenter.phone.isNotEmpty) ...[
          _buildDetailRow(
            Icons.phone,
            'Phone',
            gymCenter.phone,
            Colors.green,
          ),
          const SizedBox(height: 16),
        ],
        if (gymCenter.email.isNotEmpty) ...[
          _buildDetailRow(
            Icons.email,
            'Email',
            gymCenter.email,
            Colors.blue,
          ),
          const SizedBox(height: 16),
        ],
        if (gymCenter.address.isNotEmpty) ...[
          _buildDetailRow(
            Icons.location_on,
            'Address',
            gymCenter.address,
            Colors.red,
          ),
          const SizedBox(height: 16),
        ],
        if (gymCenter.website.isNotEmpty) ...[
          _buildDetailRow(
            Icons.language,
            'Website',
            gymCenter.website,
            Colors.orange,
          ),
          const SizedBox(height: 16),
        ],

        // Operating hours
        if (gymCenter.operatingHours.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildOperatingHours(gymCenter.operatingHours),
        ],

        // Amenities
        if (gymCenter.amenities.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildAmenities(gymCenter.amenities),
        ],

        const SizedBox(height: 32),

        // Action buttons based on status
        _buildActionButtons(gymCenter, status),
      ],
    );
  }

  Widget _buildActionButtons(GymCenterInfo gymCenter, GymStatus status) {
    switch (status) {
      case GymStatus.bound:
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _sendUnbindRequest(gymCenter),
                icon: const Icon(Icons.link_off, size: 20),
                label: const Text(
                  'Request Unbind',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You are currently bound to this gym center and can start working.',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case GymStatus.boundWithPendingUnbind:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.pending,
                color: Colors.orange.shade600,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your unbind request is pending approval from the gym administrator.',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );

      case GymStatus.pendingBind:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.schedule,
                color: Colors.blue.shade600,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your bind request is pending approval from the gym administrator.',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );

      default:
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _sendBindRequest(gymCenter),
            icon: const Icon(Icons.send, size: 20),
            label: const Text(
              'Send Bind Request',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
    }
  }

  IconData _getStatusIcon(GymStatus status) {
    switch (status) {
      case GymStatus.bound:
        return Icons.check_circle;
      case GymStatus.boundWithPendingUnbind:
        return Icons.pending;
      case GymStatus.pendingBind:
        return Icons.schedule;
      default:
        return Icons.fitness_center;
    }
  }

  String _getStatusText(GymStatus status) {
    switch (status) {
      case GymStatus.bound:
        return 'BOUND';
      case GymStatus.boundWithPendingUnbind:
        return 'UNBINDING';
      case GymStatus.pendingBind:
        return 'PENDING';
      default:
        return 'AVAILABLE';
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOperatingHours(Map<String, String> hours) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.access_time,
              color: Colors.purple.shade600,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Operating Hours',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: hours.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAmenities(List<String> amenities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.star,
              color: Colors.blue.shade600,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Amenities & Services',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: amenities.map((amenity) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.blue.shade600,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    amenity,
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMyRequestsSection() {
    return StreamBuilder<List<BindingRequest>>(
      stream: CoachService.getCoachBindingRequestsStream(currentUser?.uid ?? ''),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Requests History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...snapshot.data!.map((request) {
              return _buildRequestCard(request);
            }),
          ],
        );
      },
    );
  }

  Widget _buildRequestCard(BindingRequest request) {
    Color statusColor;
    IconData statusIcon;
    String requestTypeText = request.type;

    switch (request.status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${requestTypeText == 'unbind' ? 'Unbind' : 'Bind'} request to ${request.gymName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (request.createdAt != null)
                  Text(
                    'Sent on ${request.createdAt!.day}/${request.createdAt!.month}/${request.createdAt!.year}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                if (request.status == 'rejected' && request.rejectReason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Reason: ${request.rejectReason}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              request.statusDisplayText,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendBindRequest(GymCenterInfo gymCenter) async {
    if (currentUser == null) return;

    final message = await _showMessageDialog('Send Bind Request',
        'Please introduce yourself and explain why you want to join this gym:');
    if (message == null) return;

    final success = await CoachService.sendBindingRequest(
      coachId: currentUser!.uid,
      coachName: currentUser!.displayName ?? 'Unknown Coach',
      coachEmail: currentUser!.email ?? '',
      gymId: gymCenter.id,
      gymName: gymCenter.name,
      message: message,
      type: 'bind', // 指定为绑定请求
      targetAdminUid: gymCenter.id,  // gym_info 的文档ID就是管理员UID
    );

    if (success) {
      await _loadCoachStatus(); // 重新加载状态
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bind request sent to ${gymCenter.name} successfully!'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to send bind request. Please try again.'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _sendUnbindRequest(GymCenterInfo gymCenter) async {
    if (currentUser == null) return;

    final message = await _showMessageDialog('Request Unbind',
        'Please explain why you want to unbind from this gym:');
    if (message == null) return;

    final success = await CoachService.sendBindingRequest(
      coachId: currentUser!.uid,
      coachName: currentUser!.displayName ?? 'Unknown Coach',
      coachEmail: currentUser!.email ?? '',
      gymId: gymCenter.id,
      gymName: gymCenter.name,
      message: message,
      type: 'unbind', // 指定为解绑请求
      targetAdminUid: gymCenter.id,  // gym_info 的文档ID就是管理员UID
    );

    if (success) {
      await _loadCoachStatus(); // 重新加载状态
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unbind request sent to ${gymCenter.name} successfully!'),
          backgroundColor: Colors.orange.shade600,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to send unbind request. Please try again.'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<String?> _showMessageDialog(String title, String description) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Write your message here...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade600,
            ),
            child: const Text(
              'Send',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// 健身房绑定状态枚举
enum GymStatus {
  unbound, // 未绑定
  pendingBind, // 绑定请求待批准
  bound, // 已绑定
  boundWithPendingUnbind, // 已绑定但有待批准的解绑请求
}

// 健身房信息数据类
class GymCenterInfo {
  final String id;
  final String name;
  final String description;
  final String phone;
  final String email;
  final String address;
  final String website;
  final Map<String, String> operatingHours;
  final List<String> amenities;

  GymCenterInfo({
    required this.id,
    required this.name,
    this.description = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.website = '',
    this.operatingHours = const {},
    this.amenities = const [],
  });

  factory GymCenterInfo.fromFirestore(String id, Map<String, dynamic> data) {
    return GymCenterInfo(
      id: id,
      name: data['name'] ?? 'Unknown Gym',
      description: data['description'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      address: data['address'] ?? '',
      website: data['website'] ?? '',
      operatingHours: data['operatingHours'] != null
          ? Map<String, String>.from(data['operatingHours'])
          : {},
      amenities: data['amenities'] != null
          ? List<String>.from(data['amenities'])
          : [],
    );
  }
}