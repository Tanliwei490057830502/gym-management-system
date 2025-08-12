import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({Key? key}) : super(key: key);

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> with TickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  late TabController _tabController;

  // 收入数据
  Map<String, double> weeklyRevenue = {};
  double totalWeeklyRevenue = 0.0;
  List<RevenueData> revenueHistory = [];

  // 费用设置
  final _additionalFeeController = TextEditingController();
  final _descriptionController = TextEditingController();
  double _currentFee = 0.0;
  String _feeDescription = '';

  bool _isLoading = true;
  bool _isSavingFee = false;
  String _selectedPeriod = 'This Week';
  final List<String> _periods = ['This Week', 'This Month', 'Last Month', 'Last 3 Months'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _additionalFeeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadFeeSettings(),
        _loadWeeklyRevenue(),
        _loadRevenueHistory(),
      ]);
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFeeSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('gym_settings')
          .doc(user!.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final fee = (data['additionalFee'] ?? 0.0).toDouble();
        final description = data['feeDescription'] ?? '';

        setState(() {
          _currentFee = fee;
          _feeDescription = description;
          _additionalFeeController.text = fee.toStringAsFixed(0);
          _descriptionController.text = description;
        });
      }
    } catch (e) {
      print('Error loading fee settings: $e');
    }
  }

  Future<void> _loadWeeklyRevenue() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('gym_revenues')
          .where('gymAdminId', isEqualTo: user!.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
          .where('date', isLessThan: Timestamp.fromDate(startOfWeek.add(const Duration(days: 7))))
          .get();

      Map<String, double> dailyRevenue = {
        'Monday': 0.0, 'Tuesday': 0.0, 'Wednesday': 0.0, 'Thursday': 0.0,
        'Friday': 0.0, 'Saturday': 0.0, 'Sunday': 0.0,
      };

      double total = 0.0;

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0.0).toDouble();
        final dayOfWeek = data['dayOfWeek'] ?? 1;

        String dayName = _getDayName(dayOfWeek);
        dailyRevenue[dayName] = (dailyRevenue[dayName] ?? 0.0) + amount;
        total += amount;
      }

      setState(() {
        weeklyRevenue = dailyRevenue;
        totalWeeklyRevenue = total;
      });
    } catch (e) {
      print('Error loading weekly revenue: $e');
    }
  }

  Future<void> _loadRevenueHistory() async {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case 'This Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'Last Month':
        startDate = DateTime(now.year, now.month - 1, 1);
        break;
      case 'Last 3 Months':
        startDate = DateTime(now.year, now.month - 3, 1);
        break;
      default:
        startDate = now.subtract(Duration(days: now.weekday - 1));
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('gym_revenues')
          .where('gymAdminId', isEqualTo: user!.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('date', descending: true)
          .limit(50)
          .get();

      List<RevenueData> history = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        history.add(RevenueData.fromFirestore(data));
      }

      setState(() {
        revenueHistory = history;
      });
    } catch (e) {
      print('Error loading revenue history: $e');
    }
  }

  Future<void> _saveFeeSettings() async {
    if (user == null) return;

    setState(() => _isSavingFee = true);

    try {
      final fee = double.tryParse(_additionalFeeController.text) ?? 0.0;
      final description = _descriptionController.text.trim();

      // 使用 Map<String, Object> 确保类型兼容
      final Map<String, Object> updateData = {
        'additionalFee': fee,
        'feeDescription': description,
        'updatedAt': FieldValue.serverTimestamp(),
        'gymAdminId': user!.uid,
      };

      await FirebaseFirestore.instance
          .collection('gym_settings')
          .doc(user!.uid)
          .set(updateData, SetOptions(merge: true));

      setState(() {
        _currentFee = fee;
        _feeDescription = description;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Fee settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to save: $e')),
      );
    } finally {
      setState(() => _isSavingFee = false);
    }
  }

  String _getDayName(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return 'Monday';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.grey.shade50,
          child: const Center(
            child: Text('Please login to view analytics'),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey.shade50,
        child: Column(
          children: [
            // 页面标题和标签栏
            _buildHeader(),

            // 标签内容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAnalyticsTab(),
                  _buildFeeSettingsTab(),
                  _buildRevenueHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 标题部分
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade600, Colors.blue.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.analytics,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revenue Analytics & Fee Management',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage fees, track earnings, and analyze revenue performance',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              // 时间段选择下拉菜单
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.purple.shade300),
                ),
                child: DropdownButton<String>(
                  value: _selectedPeriod,
                  underline: const SizedBox.shrink(),
                  items: _periods.map((period) {
                    return DropdownMenuItem(
                      value: period,
                      child: Text(period),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedPeriod = value;
                      });
                      _loadRevenueHistory();
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 标签栏
          TabBar(
            controller: _tabController,
            labelColor: Colors.purple.shade600,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.purple.shade600,
            tabs: const [
              Tab(
                icon: Icon(Icons.bar_chart, size: 20),
                text: 'Analytics Dashboard',
              ),
              Tab(
                icon: Icon(Icons.attach_money, size: 20),
                text: 'Fee Settings',
              ),
              Tab(
                icon: Icon(Icons.history, size: 20),
                text: 'Revenue History',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          // 主要图表区域
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 周收入图表
              Expanded(
                flex: 2,
                child: _buildWeeklyChart(),
              ),

              const SizedBox(width: 20),

              // 每日统计
              Expanded(
                flex: 1,
                child: _buildDailyStats(),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // 统计摘要卡片
          _buildSummaryCards(),
        ],
      ),
    );
  }

  Widget _buildFeeSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          // 当前费用设置显示
          _buildCurrentFeeDisplay(),

          const SizedBox(height: 30),

          // 费用设置表单
          _buildFeeSettingsForm(),

          const SizedBox(height: 30),

          // 说明信息
          _buildHowItWorksInfo(),
        ],
      ),
    );
  }

  Widget _buildRevenueHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: _buildRevenueHistoryList(),
    );
  }

  Widget _buildCurrentFeeDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _currentFee > 0 ? Colors.green.shade50 : Colors.grey.shade50,
            _currentFee > 0 ? Colors.green.shade100 : Colors.grey.shade100,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _currentFee > 0 ? Colors.green.shade300 : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _currentFee > 0 ? Colors.green.shade600 : Colors.grey.shade600,
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
                      'RM ${_currentFee.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _currentFee > 0 ? Colors.green.shade700 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _currentFee > 0 ? Colors.green.shade600 : Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _currentFee > 0 ? 'ACTIVE' : 'INACTIVE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (_feeDescription.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _feeDescription,
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeeSettingsForm() {
    return Container(
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
            controller: _descriptionController,
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

  Widget _buildWeeklyChart() {
    return Container(
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.purple.shade600,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Total estimated revenue for the week: RM ${totalWeeklyRevenue.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 200,
            child: _buildSimpleBarChart(),
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((day) => Text(
              day,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleBarChart() {
    final maxValue = weeklyRevenue.values.isNotEmpty
        ? weeklyRevenue.values.reduce((a, b) => a > b ? a : b)
        : 100.0;

    if (maxValue == 0) {
      return const Center(
        child: Text(
          'No revenue data available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: weeklyRevenue.entries.map((entry) {
        final height = (entry.value / maxValue) * 150;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (entry.value > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'RM${entry.value.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Container(
              width: 30,
              height: height > 0 ? height : 5,
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildDailyStats() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.purple.shade600,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Statistics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          ...weeklyRevenue.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${entry.key}:',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'RM ${entry.value.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final monthlyTotal = revenueHistory
        .where((r) => r.date.month == DateTime.now().month)
        .fold(0.0, (sum, r) => sum + r.amount);

    final averageDaily = totalWeeklyRevenue / 7;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Weekly Total',
            'RM ${totalWeeklyRevenue.toStringAsFixed(0)}',
            Icons.calendar_view_week,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Monthly Total',
            'RM ${monthlyTotal.toStringAsFixed(0)}',
            Icons.calendar_month,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Daily Average',
            'RM ${averageDaily.toStringAsFixed(0)}',
            Icons.trending_up,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Current Fee',
            'RM ${_currentFee.toStringAsFixed(0)}',
            Icons.attach_money,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
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
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueHistoryList() {
    if (revenueHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            const Text(
              'No Revenue Records Found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Revenue records will appear here when customers purchase courses with additional fees.',
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

    return Container(
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
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  color: Colors.purple.shade600,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Revenue History - $_selectedPeriod',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${revenueHistory.length} records',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: revenueHistory.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey.shade200,
            ),
            itemBuilder: (context, index) {
              final revenue = revenueHistory[index];
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.attach_money,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                ),
                title: Text(
                  revenue.description,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      revenue.formattedDate,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    if (revenue.courseTitle.isNotEmpty)
                      Text(
                        'Course: ${revenue.courseTitle}',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'RM ${revenue.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        revenue.source,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// 收入数据模型
class RevenueData {
  final double amount;
  final String source;
  final String description;
  final DateTime date;
  final String courseTitle;
  final String userId;

  RevenueData({
    required this.amount,
    required this.source,
    required this.description,
    required this.date,
    required this.courseTitle,
    required this.userId,
  });

  factory RevenueData.fromFirestore(Map<String, dynamic> data) {
    final timestamp = data['date'] as Timestamp;
    return RevenueData(
      amount: (data['amount'] ?? 0.0).toDouble(),
      source: data['source'] ?? '',
      description: data['description'] ?? 'Revenue',
      date: timestamp.toDate(),
      courseTitle: data['courseTitle'] ?? '',
      userId: data['userId'] ?? '',
    );
  }

  String get formattedDate {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}