// screens/simple_admin_displayname_screen.dart
// 简化版管理界面：类型安全，易于使用

import 'package:flutter/material.dart';
import '../services/displayname_service.dart';

class SimpleAdminDisplayNameScreen extends StatefulWidget {
  const SimpleAdminDisplayNameScreen({Key? key}) : super(key: key);

  @override
  State<SimpleAdminDisplayNameScreen> createState() => _SimpleAdminDisplayNameScreenState();
}

class _SimpleAdminDisplayNameScreenState extends State<SimpleAdminDisplayNameScreen> {
  bool _isLoading = false;
  ReportData? _reportData;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DisplayName 修复工具'),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _generateReport,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在处理中...'),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildReportCard(),
            const SizedBox(height: 16),
            _buildQuickActionsCard(),
            const SizedBox(height: 16),
            _buildSpecificFixCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final isError = _statusMessage.contains('失败') || _statusMessage.contains('错误');
    final isSuccess = _statusMessage.contains('成功') || _statusMessage.contains('完成');

    return Card(
      color: isError
          ? Colors.red.shade50
          : isSuccess
          ? Colors.green.shade50
          : Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isError
                  ? Icons.error
                  : isSuccess
                  ? Icons.check_circle
                  : Icons.info,
              color: isError
                  ? Colors.red
                  : isSuccess
                  ? Colors.green
                  : Colors.blue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _statusMessage.isEmpty ? '准备就绪' : _statusMessage,
                style: TextStyle(
                  fontSize: 14,
                  color: isError
                      ? Colors.red.shade700
                      : isSuccess
                      ? Colors.green.shade700
                      : Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard() {
    if (_reportData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('正在加载报告...'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  '问题分析报告',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 绑定请求统计
            _buildStatRow(
              '绑定请求',
              _reportData!.bindingRequestsTotal,
              _reportData!.bindingRequestsUnknown,
              _reportData!.bindingRequestsPercentage,
              Colors.orange,
            ),
            const Divider(),

            // 教练记录统计
            _buildStatRow(
              '教练记录',
              _reportData!.coachesTotal,
              _reportData!.coachesWithoutName,
              _reportData!.coachesPercentage,
              Colors.blue,
            ),
            const Divider(),

            // 用户记录统计
            _buildStatRow(
              '用户记录',
              _reportData!.usersTotal,
              _reportData!.usersWithoutName,
              _reportData!.usersPercentage,
              Colors.green,
            ),

            const SizedBox(height: 16),

            // 总计
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _reportData!.totalIssues > 0
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _reportData!.totalIssues > 0
                      ? Colors.red.shade200
                      : Colors.green.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _reportData!.totalIssues > 0 ? Icons.warning : Icons.check_circle,
                    color: _reportData!.totalIssues > 0 ? Colors.red.shade600 : Colors.green.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _reportData!.totalIssues > 0
                        ? '发现 ${_reportData!.totalIssues} 个问题需要修复'
                        : '✅ 没有发现问题！',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _reportData!.totalIssues > 0
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String title, int total, int problems, double percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: color, size: 12),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('总数: $total'),
              Text('问题: $problems'),
              Text('比例: ${percentage.toStringAsFixed(1)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.flash_on, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  '快速操作',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 一键修复按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _reportData?.totalIssues == 0 ? null : _fixAllIssues,
                icon: const Icon(Icons.auto_fix_high),
                label: Text(
                  _reportData?.totalIssues == 0
                      ? '没有问题需要修复'
                      : '一键修复所有问题 (${_reportData?.totalIssues ?? 0}个)',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 其他操作
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _fixBindingRequests,
                    icon: const Icon(Icons.person_search),
                    label: const Text('仅修复绑定请求'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade600,
                      side: BorderSide(color: Colors.orange.shade600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _validateFixes,
                    icon: const Icon(Icons.verified),
                    label: const Text('验证修复'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade600,
                      side: BorderSide(color: Colors.blue.shade600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecificFixCard() {
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                const Text(
                  '特定问题修复',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.yellow.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '针对用户报告的问题:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Coach ID: s3Vn0B1Ld2aCKT5EqN1YiIWvyg23\n'
                        'Email: weiliqi1234@gmail.com\n'
                        'Problem: Unknown Coach',
                    style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _fixSpecificIssue,
                icon: const Icon(Icons.person_pin),
                label: const Text('修复这个特定问题'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateReport() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '正在生成报告...';
    });

    try {
      final report = await DisplayNameService.generateReport();
      setState(() {
        _reportData = report;
        _statusMessage = '报告生成完成';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '生成报告失败: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fixAllIssues() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '正在执行一键修复...';
    });

    try {
      final results = await DisplayNameService.fixAllIssues();
      setState(() {
        if (results.hasErrors) {
          _statusMessage = '修复过程中遇到错误';
        } else if (results.hasFixedItems) {
          _statusMessage = '🎉 修复完成！绑定请求: ${results.bindingRequestsFixed}个，认证用户: ${results.authUsersFixed}个';
        } else {
          _statusMessage = '没有发现需要修复的问题';
        }
      });
      await _generateReport(); // 刷新报告
    } catch (e) {
      setState(() {
        _statusMessage = '一键修复失败: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fixBindingRequests() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '正在修复绑定请求...';
    });

    try {
      final fixedCount = await DisplayNameService.fixUnknownCoachRequests();
      setState(() {
        _statusMessage = '修复完成，共修复 $fixedCount 个绑定请求';
      });
      await _generateReport(); // 刷新报告
    } catch (e) {
      setState(() {
        _statusMessage = '修复绑定请求失败: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _validateFixes() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '正在验证修复结果...';
    });

    try {
      final isValid = await DisplayNameService.validateFixes();
      setState(() {
        _statusMessage = isValid
            ? '✅ 验证通过！所有问题已修复'
            : '⚠️ 验证失败，仍有问题需要处理';
      });
      await _generateReport(); // 刷新报告
    } catch (e) {
      setState(() {
        _statusMessage = '验证过程失败: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fixSpecificIssue() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '正在修复特定问题...';
    });

    try {
      // 直接调用修复绑定请求，会自动处理所有 Unknown Coach 的情况
      final fixedCount = await DisplayNameService.fixUnknownCoachRequests();
      setState(() {
        _statusMessage = fixedCount > 0
            ? '✅ 特定问题修复完成，共修复 $fixedCount 个问题'
            : '没有发现需要修复的特定问题';
      });
      await _generateReport(); // 刷新报告
    } catch (e) {
      setState(() {
        _statusMessage = '修复特定问题失败: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }
}