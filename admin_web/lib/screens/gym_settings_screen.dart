// lib/screens/gym_settings_screen.dart
// 用途：健身房设置界面（整合费用设置功能）

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/gym_service.dart';
import '../services/gym_revenue_service.dart';
import '../utils/snackbar_utils.dart';
import 'package:gym_admin_web/models/gym_info.dart';

// 导入 ChartsScreen 用于导航
import 'charts_screen.dart';

class GymSettingsScreen extends StatefulWidget {
  const GymSettingsScreen({Key? key}) : super(key: key);

  @override
  State<GymSettingsScreen> createState() => _GymSettingsScreenState();
}

class _GymSettingsScreenState extends State<GymSettingsScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  final user = FirebaseAuth.instance.currentUser;

  // 表单控制器
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();

  // 费用设置控制器（与 ChartsScreen 保持一致）
  final TextEditingController _additionalFeeController = TextEditingController();
  final TextEditingController _feeDescriptionController = TextEditingController();

  // 营业时间控制器
  final Map<String, TextEditingController> _hoursControllers = {};

  // 设施和社交媒体
  List<String> _amenities = [];
  List<String> _socialMedia = [];

  // 状态管理
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isSavingFee = false;
  GymInfo? _currentGymInfo;

  // 费用设置相关 - 使用 Map 而不是自定义类避免冲突
  Map<String, dynamic>? _feeSettings;
  bool _isLoadingFees = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _initializeControllers();
    _loadGymInfo();
    _loadFeeSettings();
  }

  void _initializeControllers() {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    for (String day in days) {
      _hoursControllers[day] = TextEditingController();
    }
  }

  Future<void> _loadGymInfo() async {
    setState(() => _isLoading = true);

    try {
      // 检查用户是否已认证
      if (!GymService.isUserAuthenticated()) {
        SnackbarUtils.showError(context, 'Please log in to access gym settings');
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      final gymInfo = await GymService.getGymInfo();
      if (gymInfo != null && mounted) {
        _populateForm(gymInfo);
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Error loading gym information: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadFeeSettings() async {
    if (user == null) return;

    try {
      final settings = await GymRevenueService.getGymFeeSettings(user!.uid);
      setState(() {
        _feeSettings = settings ?? {
          'additionalFee': 0.0,
          'feeDescription': '',
        };
        final fee = (_feeSettings!['additionalFee'] ?? 0.0).toDouble();
        final description = _feeSettings!['feeDescription'] ?? '';
        _additionalFeeController.text = fee.toStringAsFixed(0);
        _feeDescriptionController.text = description;
        _isLoadingFees = false;
      });
    } catch (e) {
      print('Error loading fee settings: $e');
      setState(() => _isLoadingFees = false);
    }
  }

  void _populateForm(GymInfo gymInfo) {
    if (!mounted) return;

    setState(() {
      _currentGymInfo = gymInfo;
      _nameController.text = gymInfo.name;
      _descriptionController.text = gymInfo.description;
      _phoneController.text = gymInfo.phone;
      _emailController.text = gymInfo.email;
      _addressController.text = gymInfo.address;
      _websiteController.text = gymInfo.website;

      // 营业时间
      _hoursControllers.forEach((day, controller) {
        controller.text = gymInfo.operatingHours[day] ?? '';
      });

      _amenities = List.from(gymInfo.amenities);
      _socialMedia = List.from(gymInfo.socialMedia);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _websiteController.dispose();
    _additionalFeeController.dispose();
    _feeDescriptionController.dispose();

    _hoursControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildBasicInfoTab(),
                _buildOperatingHoursTab(),
                _buildAmenitiesTab(),
                _buildFeeSettingsTab(),
                _buildPreviewTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade600, Colors.blue.shade600],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 24, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.settings,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gym Management Center',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Configure your fitness center information and settings',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _resetForm,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Reset', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveGymInfo,
                icon: _isSaving
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.purple.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.purple.shade600,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: Colors.purple.shade600,
        isScrollable: true,
        tabs: const [
          Tab(text: 'Overview', icon: Icon(Icons.dashboard, size: 18)),
          Tab(text: 'Basic Info', icon: Icon(Icons.info_outline, size: 18)),
          Tab(text: 'Hours', icon: Icon(Icons.access_time, size: 18)),
          Tab(text: 'Amenities', icon: Icon(Icons.fitness_center, size: 18)),
          Tab(text: 'Fee Settings', icon: Icon(Icons.attach_money, size: 18)),
          Tab(text: 'Preview', icon: Icon(Icons.preview, size: 18)),
        ],
      ),
    );
  }

  // 概览标签
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 快速操作卡片
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildQuickActionCard(
                'Fee Settings',
                _isLoadingFees ? 'Loading...' : 'Current: RM ${((_feeSettings?['additionalFee'] ?? 0.0).toDouble()).toStringAsFixed(0)}',
                Icons.attach_money,
                Colors.green,
                    () => _tabController.animateTo(4), // 跳转到费用设置标签
              ),
              _buildQuickActionCard(
                'Revenue Analytics',
                'View earnings & reports',
                Icons.bar_chart,
                Colors.blue,
                    () => _navigateToAnalytics(),
              ),
              _buildQuickActionCard(
                'Basic Info',
                'Edit gym details',
                Icons.business,
                Colors.orange,
                    () => _tabController.animateTo(1), // 跳转到基本信息标签
              ),
            ],
          ),

          const SizedBox(height: 30),

          // 状态概览卡片
          const Text(
            'Status Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildStatusCard(
                  'Gym Information',
                  _currentGymInfo != null ? 'Complete' : 'Incomplete',
                  _currentGymInfo != null ? Colors.green : Colors.orange,
                  Icons.business,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildStatusCard(
                  'Fee Settings',
                  ((_feeSettings?['additionalFee'] ?? 0.0).toDouble()) > 0 ? 'Active' : 'Inactive',
                  ((_feeSettings?['additionalFee'] ?? 0.0).toDouble()) > 0 ? Colors.green : Colors.grey,
                  Icons.attach_money,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 简化的统计卡片，移除有问题的组件
          Row(
            children: [
              Expanded(
                child: _buildSimpleStatsCard(
                  'Coaches',
                  'Manage coaches',
                  Icons.people,
                  Colors.blue,
                  'View coaches and their status',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildSimpleStatsCard(
                  'Requests',
                  'Binding requests',
                  Icons.request_page,
                  Colors.purple,
                  'Coach binding requests',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
      String title,
      String subtitle,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(String title, String status, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 简化的统计卡片，替代有问题的组件
  Widget _buildSimpleStatsCard(String title, String subtitle, IconData icon, Color color, String description) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
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
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // 费用设置标签（与 ChartsScreen 保持一致）
  Widget _buildFeeSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Fee Management',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _navigateToAnalytics(),
                icon: const Icon(Icons.bar_chart, size: 18),
                label: const Text('View Analytics'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 当前费用设置显示
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ((_feeSettings?['additionalFee'] ?? 0.0).toDouble()) > 0 ? Colors.green.shade50 : Colors.grey.shade50,
                  ((_feeSettings?['additionalFee'] ?? 0.0).toDouble()) > 0 ? Colors.green.shade100 : Colors.grey.shade100,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ((_feeSettings?['additionalFee'] ?? 0.0).toDouble()) > 0 ? Colors.green.shade300 : Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: _isLoadingFees
                ? const Center(child: CircularProgressIndicator())
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ((_feeSettings?['additionalFee'] ?? 0.0).toDouble()) > 0 ? Colors.green.shade600 : Colors.grey.shade600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.attach_money,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Additional Fee',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'RM ${((_feeSettings?['additionalFee'] ?? 0.0).toDouble()).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: ((_feeSettings?['additionalFee'] ?? 0.0).toDouble()) > 0 ? Colors.green.shade700 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: ((_feeSettings?['additionalFee'] ?? 0.0).toDouble()) > 0 ? Colors.green.shade600 : Colors.grey.shade600,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        ((_feeSettings?['additionalFee'] ?? 0.0).toDouble()) > 0 ? 'ACTIVE' : 'INACTIVE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                if ((_feeSettings?['feeDescription'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _feeSettings!['feeDescription'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 30),

          // 费用设置表单
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Update Fee Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // 费用金额输入
                TextFormField(
                  controller: _additionalFeeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Additional Fee (RM)',
                    hintText: 'Enter amount (e.g., 20)',
                    prefixIcon: const Icon(Icons.attach_money),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.purple.shade600, width: 2),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 费用描述输入
                TextFormField(
                  controller: _feeDescriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Fee Description (Optional)',
                    hintText: 'e.g., Platform service fee, Facility usage fee',
                    prefixIcon: const Icon(Icons.description),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.purple.shade600, width: 2),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 保存按钮
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isSavingFee ? null : _saveFeeSettings,
                    icon: _isSavingFee
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Icon(Icons.save),
                    label: Text(
                      _isSavingFee ? 'Saving...' : 'Save Fee Settings',
                      style: const TextStyle(
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
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // 说明信息
          _buildHowItWorksInfo(),
        ],
      ),
    );
  }

  Widget _buildHowItWorksInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue.shade600,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'How Additional Fees Work',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoItem('When users purchase coach courses, this additional fee will be automatically added to the coach\'s price'),
          _buildInfoItem('The additional fee will be recorded as gym revenue and shown in your analytics dashboard'),
          _buildInfoItem('Coaches will see the total price (their price + additional fee) but the breakdown will be clear'),
          _buildInfoItem('Set the fee to 0 to disable additional charges'),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.yellow.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.yellow.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.yellow.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Example: If coach price is RM 80 and additional fee is RM 20, customer pays RM 100 total. You receive RM 20 as gym revenue.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.yellow.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.blue.shade600,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 保存费用设置方法（与 ChartsScreen 保持一致）
  Future<void> _saveFeeSettings() async {
    if (user == null) return;

    setState(() => _isSavingFee = true);

    try {
      final fee = double.tryParse(_additionalFeeController.text) ?? 0.0;
      final description = _feeDescriptionController.text.trim();

      final success = await GymRevenueService.updateGymFeeSettings(
        gymAdminId: user!.uid,
        additionalFee: fee,
        feeDescription: description,
      );

      if (success) {
        setState(() {
          _feeSettings = {
            'additionalFee': fee,
            'feeDescription': description,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          };
        });

        SnackbarUtils.showSuccess(context, 'Fee settings saved successfully!');
      } else {
        SnackbarUtils.showError(context, 'Failed to save fee settings');
      }
    } catch (e) {
      SnackbarUtils.showError(context, 'Error saving fee settings: $e');
    } finally {
      if (mounted) {
        setState(() => _isSavingFee = false);
      }
    }
  }

  // 其他现有方法保持不变...
  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildFormField(
                        'Gym Name',
                        _nameController,
                        Icons.business,
                        'Enter your gym name',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter gym name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildFormField(
                        'Description',
                        _descriptionController,
                        Icons.description,
                        'Describe your fitness center...',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormField(
                              'Phone Number',
                              _phoneController,
                              Icons.phone,
                              '+60 XX-XXX XXXX',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter phone number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildFormField(
                              'Email Address',
                              _emailController,
                              Icons.email,
                              'contact@yourgym.com',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter email address';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                  return 'Please enter valid email';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 30),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      _buildFormField(
                        'Address',
                        _addressController,
                        Icons.location_on,
                        'Enter complete address...',
                        maxLines: 6,
                      ),
                      const SizedBox(height: 20),
                      _buildFormField(
                        'Website (Optional)',
                        _websiteController,
                        Icons.language,
                        'www.yourgym.com',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatingHoursTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Operating Hours',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _setAllDaysSame,
                icon: const Icon(Icons.copy_all, size: 18),
                label: const Text('Copy to All Days'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: _hoursControllers.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: TextFormField(
                          controller: entry.value,
                          decoration: InputDecoration(
                            hintText: '7:00 AM - 11:00 PM',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenitiesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 设施管理
          Row(
            children: [
              const Text(
                'Gym Amenities',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _addAmenity,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Amenity'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _amenities.isEmpty
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No amenities added yet.\nClick "Add Amenity" to get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
            )
                : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _amenities.map((amenity) {
                return Chip(
                  label: Text(amenity),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => _removeAmenity(amenity),
                  backgroundColor: Colors.purple.shade50,
                  deleteIconColor: Colors.purple.shade600,
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 40),

          // 社交媒体管理
          Row(
            children: [
              const Text(
                'Social Media Links',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _addSocialMedia,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Link'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _socialMedia.isEmpty
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No social media links added yet.\nClick "Add Link" to get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
            )
                : Column(
              children: _socialMedia.map((link) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _getSocialMediaIcon(link),
                        color: Colors.blue.shade600,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          link,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removeSocialMedia(link),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        iconSize: 20,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // 预览卡片
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题区域
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.fitness_center,
                        color: Colors.purple.shade600,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameController.text.isNotEmpty
                                ? _nameController.text
                                : 'Your Gym Name',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _descriptionController.text.isNotEmpty
                                ? _descriptionController.text
                                : 'Your gym description...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // 联系信息
                Row(
                  children: [
                    Expanded(
                      child: _buildPreviewInfo(
                        Icons.phone,
                        'Phone',
                        _phoneController.text.isNotEmpty ? _phoneController.text : 'Not set',
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildPreviewInfo(
                        Icons.email,
                        'Email',
                        _emailController.text.isNotEmpty ? _emailController.text : 'Not set',
                        Colors.blue,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                _buildPreviewInfo(
                  Icons.location_on,
                  'Address',
                  _addressController.text.isNotEmpty ? _addressController.text : 'Not set',
                  Colors.red,
                ),

                if (_websiteController.text.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildPreviewInfo(
                    Icons.language,
                    'Website',
                    _websiteController.text,
                    Colors.orange,
                  ),
                ],

                // 费用设置预览
                if (_feeSettings != null && ((_feeSettings!['additionalFee'] ?? 0.0).toDouble()) > 0) ...[
                  const SizedBox(height: 20),
                  _buildPreviewInfo(
                    Icons.attach_money,
                    'Additional Service Fee',
                    'RM ${((_feeSettings!['additionalFee'] ?? 0.0).toDouble()).toStringAsFixed(2)}',
                    Colors.green,
                  ),
                ],

                // 设施
                if (_amenities.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Icon(
                        Icons.fitness_center,
                        color: Colors.purple.shade600,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Amenities',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _amenities.map((amenity) {
                      return Chip(
                        label: Text(amenity),
                        backgroundColor: Colors.purple.shade50,
                      );
                    }).toList(),
                  ),
                ],

                // 营业时间预览
                if (_hoursControllers.values.any((controller) => controller.text.isNotEmpty)) ...[
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.blue.shade600,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Operating Hours',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: _hoursControllers.entries
                          .where((entry) => entry.value.text.isNotEmpty)
                          .map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(entry.value.text),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField(
      String label,
      TextEditingController controller,
      IconData icon,
      String hint, {
        int maxLines = 1,
        String? Function(String?)? validator,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.purple.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.purple.shade600, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewInfo(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
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
          const SizedBox(width: 12),
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
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSocialMediaIcon(String url) {
    final lowercaseUrl = url.toLowerCase();
    if (lowercaseUrl.contains('facebook')) return Icons.facebook;
    if (lowercaseUrl.contains('instagram')) return Icons.camera_alt;
    if (lowercaseUrl.contains('twitter') || lowercaseUrl.contains('x.com')) return Icons.alternate_email;
    if (lowercaseUrl.contains('youtube')) return Icons.play_circle_outline;
    if (lowercaseUrl.contains('linkedin')) return Icons.work;
    if (lowercaseUrl.contains('tiktok')) return Icons.music_video;
    return Icons.link;
  }

  // 导航方法
  void _navigateToAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChartsScreen(),
      ),
    );
  }

  // 其他辅助方法
  void _setAllDaysSame() {
    final mondayController = _hoursControllers['Monday'];
    if (mondayController != null && mondayController.text.isNotEmpty) {
      final mondayHours = mondayController.text;
      _hoursControllers.forEach((day, controller) {
        if (day != 'Monday') {
          controller.text = mondayHours;
        }
      });
      if (mounted) {
        setState(() {});
      }
      SnackbarUtils.showSuccess(context, 'Copied Monday hours to all days');
    } else {
      SnackbarUtils.showError(context, 'Please set Monday hours first');
    }
  }

  void _addAmenity() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add Amenity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Enter amenity name',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text(
                'Examples: Free WiFi, Parking, Locker Room, Personal Training, etc.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
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
                final text = controller.text.trim();
                if (text.isNotEmpty && mounted) {
                  setState(() {
                    _amenities.add(text);
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _removeAmenity(String amenity) {
    setState(() {
      _amenities.remove(amenity);
    });
  }

  void _addSocialMedia() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add Social Media Link'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Enter URL (https://...)',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text(
                'Examples: Facebook, Instagram, Twitter, YouTube, etc.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
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
                final text = controller.text.trim();
                if (text.isNotEmpty && mounted) {
                  setState(() {
                    _socialMedia.add(text);
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _removeSocialMedia(String link) {
    setState(() {
      _socialMedia.remove(link);
    });
  }

  void _resetForm() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Form'),
          content: const Text('Are you sure you want to reset all changes? This will restore the last saved data.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                try {
                  if (_currentGymInfo != null) {
                    _populateForm(_currentGymInfo!);
                  } else {
                    _populateForm(GymInfo.defaultInfo());
                  }
                  SnackbarUtils.showSuccess(context, 'Form reset successfully');
                } catch (e) {
                  SnackbarUtils.showError(context, 'Error resetting form: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveGymInfo() async {
    // 检查表单状态
    if (_formKey.currentState == null) {
      SnackbarUtils.showError(context, 'Form is not properly initialized');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      SnackbarUtils.showError(context, 'Please fix the errors in the form');
      return;
    }

    // 检查用户认证状态
    if (!GymService.isUserAuthenticated()) {
      SnackbarUtils.showError(context, 'Please log in to save gym information');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final gymInfo = GymInfo(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        website: _websiteController.text.trim(),
        operatingHours: Map.fromEntries(
          _hoursControllers.entries
              .where((entry) => entry.value.text.isNotEmpty)
              .map((entry) => MapEntry(entry.key, entry.value.text.trim())),
        ),
        amenities: List.from(_amenities),
        socialMedia: List.from(_socialMedia),
      );

      final success = await GymService.saveGymInfo(gymInfo);

      if (success) {
        SnackbarUtils.showSuccess(context, 'Gym information saved successfully!');
        setState(() {
          _currentGymInfo = gymInfo;
        });
      } else {
        SnackbarUtils.showError(context, 'Failed to save gym information');
      }
    } catch (e) {
      SnackbarUtils.showError(context, 'Error saving gym information: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

// 临时的 GymInfo 类（如果不存在的话）
