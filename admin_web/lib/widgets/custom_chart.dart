import 'package:flutter/material.dart';

class CustomChart extends StatelessWidget {
  final List<ChartData> data;
  final String title;
  final String subtitle;
  final Color lineColor;
  final List<String> xAxisLabels;
  final double minY;
  final double maxY;

  const CustomChart({
    Key? key,
    required this.data,
    required this.title,
    this.subtitle = '',
    this.lineColor = Colors.blue,
    this.xAxisLabels = const [],
    this.minY = 0,
    this.maxY = 1000,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图表标题
          _buildChartHeader(),
          const SizedBox(height: 20),

          // 图表主体
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: LineChartPainter(
                data: data,
                lineColor: lineColor,
                xAxisLabels: xAxisLabels,
                minY: minY,
                maxY: maxY,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }
}

// 图表数据模型
class ChartData {
  final double x;
  final double y;
  final String label;

  ChartData({
    required this.x,
    required this.y,
    this.label = '',
  });
}

// 自定义折线图绘制器
class LineChartPainter extends CustomPainter {
  final List<ChartData> data;
  final Color lineColor;
  final List<String> xAxisLabels;
  final double minY;
  final double maxY;

  LineChartPainter({
    required this.data,
    required this.lineColor,
    required this.xAxisLabels,
    required this.minY,
    required this.maxY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final margin = 50.0;
    final chartWidth = size.width - 2 * margin;
    final chartHeight = size.height - 2 * margin;

    // 绘制网格
    _drawGrid(canvas, size, margin, chartWidth, chartHeight);

    // 绘制坐标轴
    _drawAxes(canvas, size, margin, chartWidth, chartHeight);

    // 绘制折线和数据点
    _drawLineAndPoints(canvas, margin, chartWidth, chartHeight);

    // 绘制标签
    _drawLabels(canvas, size, margin, chartWidth, chartHeight);
  }

  void _drawGrid(Canvas canvas, Size size, double margin, double chartWidth, double chartHeight) {
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;

    // 垂直网格线
    for (int i = 0; i <= data.length - 1; i++) {
      final x = margin + (i * chartWidth / (data.length - 1));
      canvas.drawLine(
        Offset(x, margin),
        Offset(x, size.height - margin),
        gridPaint,
      );
    }

    // 水平网格线
    for (int i = 0; i <= 5; i++) {
      final y = margin + (i * chartHeight / 5);
      canvas.drawLine(
        Offset(margin, y),
        Offset(size.width - margin, y),
        gridPaint,
      );
    }
  }

  void _drawAxes(Canvas canvas, Size size, double margin, double chartWidth, double chartHeight) {
    final axisPaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 2;

    // X轴
    canvas.drawLine(
      Offset(margin, size.height - margin),
      Offset(size.width - margin, size.height - margin),
      axisPaint,
    );

    // Y轴
    canvas.drawLine(
      Offset(margin, margin),
      Offset(margin, size.height - margin),
      axisPaint,
    );
  }

  void _drawLineAndPoints(Canvas canvas, double margin, double chartWidth, double chartHeight) {
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = lineColor.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final shadowPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = margin + (i * chartWidth / (data.length - 1));
      final y = margin + chartHeight - ((data[i].y - minY) / (maxY - minY)) * chartHeight;

      if (i == 0) {
        path.moveTo(x, y);
        shadowPath.moveTo(x, margin + chartHeight);
        shadowPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        shadowPath.lineTo(x, y);
      }

      // 绘制数据点
      canvas.drawCircle(Offset(x, y), 5, pointPaint);

      // 绘制数据点阴影
      canvas.drawCircle(
        Offset(x, y),
        8,
        Paint()..color = lineColor.withOpacity(0.2),
      );
    }

    // 完成阴影路径
    if (data.isNotEmpty) {
      final lastX = margin + ((data.length - 1) * chartWidth / (data.length - 1));
      shadowPath.lineTo(lastX, margin + chartHeight);
      shadowPath.close();
    }

    // 绘制阴影
    canvas.drawPath(shadowPath, shadowPaint);

    // 绘制折线
    canvas.drawPath(path, linePaint);
  }

  void _drawLabels(Canvas canvas, Size size, double margin, double chartWidth, double chartHeight) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // X轴标签
    final labelsToUse = xAxisLabels.isNotEmpty ? xAxisLabels :
    List.generate(data.length, (i) => data[i].label.isNotEmpty ? data[i].label : i.toString());

    for (int i = 0; i < labelsToUse.length && i < data.length; i++) {
      final x = margin + (i * chartWidth / (data.length - 1));
      textPainter.text = TextSpan(
        text: labelsToUse[i],
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - margin + 10),
      );
    }

    // Y轴标签
    for (int i = 0; i <= 5; i++) {
      final value = minY + (i * (maxY - minY) / 5);
      final y = size.height - margin - (i * chartHeight / 5);

      textPainter.text = TextSpan(
        text: value.toInt().toString(),
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(margin - textPainter.width - 10, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

// 预设图表样式
class ChartStyles {
  static const Color revenueColor = Color(0xFF6366F1);
  static const Color membersColor = Color(0xFF10B981);
  static const Color appointmentsColor = Color(0xFFF59E0B);
  static const Color activitiesColor = Color(0xFFEF4444);

  static List<ChartData> getSampleRevenueData() {
    return [
      ChartData(x: 0, y: 760, label: 'Mon'),
      ChartData(x: 1, y: 800, label: 'Tue'),
      ChartData(x: 2, y: 820, label: 'Wed'),
      ChartData(x: 3, y: 780, label: 'Thu'),
      ChartData(x: 4, y: 850, label: 'Fri'),
      ChartData(x: 5, y: 880, label: 'Sat'),
      ChartData(x: 6, y: 830, label: 'Sun'),
    ];
  }

  static List<ChartData> getSampleMemberData() {
    return [
      ChartData(x: 0, y: 220, label: 'Jan'),
      ChartData(x: 1, y: 235, label: 'Feb'),
      ChartData(x: 2, y: 240, label: 'Mar'),
      ChartData(x: 3, y: 247, label: 'Apr'),
      ChartData(x: 4, y: 250, label: 'May'),
      ChartData(x: 5, y: 265, label: 'Jun'),
    ];
  }
}

// 简化的图表组件用于快速使用
class QuickRevenueChart extends StatelessWidget {
  final double height;

  const QuickRevenueChart({
    Key? key,
    this.height = 300,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      child: CustomChart(
        data: ChartStyles.getSampleRevenueData(),
        title: 'Weekly Revenue',
        subtitle: 'RM 5,720 total this week',
        lineColor: ChartStyles.revenueColor,
        xAxisLabels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        minY: 700,
        maxY: 900,
      ),
    );
  }
}

class QuickMemberChart extends StatelessWidget {
  final double height;

  const QuickMemberChart({
    Key? key,
    this.height = 300,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      child: CustomChart(
        data: ChartStyles.getSampleMemberData(),
        title: 'Member Growth',
        subtitle: '247 total members',
        lineColor: ChartStyles.membersColor,
        xAxisLabels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
        minY: 200,
        maxY: 300,
      ),
    );
  }
}