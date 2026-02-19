import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/ranking_history_model.dart';

class RankingChart extends StatelessWidget {
  final List<RankingHistoryModel> history;

  const RankingChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.length < 2) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Histórico insuficiente para gerar gráfico',
            style: TextStyle(color: AppColors.onBackgroundLight),
          ),
        ),
      );
    }

    // Reverse so oldest is first (left side of chart)
    final reversed = history.reversed.toList();
    final spots = <FlSpot>[];
    for (var i = 0; i < reversed.length; i++) {
      spots.add(FlSpot(i.toDouble(), reversed[i].newPosition.toDouble()));
    }

    // Calculate bounds
    final positions = reversed.map((e) => e.newPosition);
    final minPos = positions.reduce((a, b) => a < b ? a : b);
    final maxPos = positions.reduce((a, b) => a > b ? a : b);
    final padding = ((maxPos - minPos) * 0.2).clamp(1, 5).toDouble();

    return SizedBox(
      height: 200,
      child: Padding(
        padding: const EdgeInsets.only(right: 16, top: 8),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppColors.divider,
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: _calculateInterval(reversed.length),
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= reversed.length) {
                      return const SizedBox.shrink();
                    }
                    final date = reversed[index].createdAt;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${date.day}/${date.month}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.onBackgroundLight,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      '#${value.toInt()}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.onBackgroundLight,
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            // Invert Y axis: lower position number = higher on chart
            minY: (minPos - padding).clamp(1, double.infinity),
            maxY: maxPos + padding,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                preventCurveOverShooting: true,
                color: AppColors.primary,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 3,
                      color: AppColors.primary,
                      strokeWidth: 1.5,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.primary.withAlpha(25),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final index = spot.x.toInt();
                    if (index < 0 || index >= reversed.length) return null;
                    final entry = reversed[index];
                    return LineTooltipItem(
                      '#${entry.newPosition}\n${entry.reasonLabel}',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _calculateInterval(int dataLength) {
    if (dataLength <= 7) return 1;
    if (dataLength <= 14) return 2;
    if (dataLength <= 30) return 5;
    return (dataLength / 6).roundToDouble();
  }
}
