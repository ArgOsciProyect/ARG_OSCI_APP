// lib/features/graph/widgets/line_chart.dart
import 'package:flutter/material.dart';
import '../../data_acquisition/domain/models/data_point.dart';

class LineChart extends StatefulWidget {
  final List<DataPoint> dataPoints;

  const LineChart({required this.dataPoints, super.key});

  @override
  _LineChartState createState() => _LineChartState();
}

class _LineChartState extends State<LineChart> {
  double timeScale = 1.0;
  double valueScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            height: 300,
            width: double.infinity,
            child: widget.dataPoints.isEmpty
                ? Center(child: Text('No data'))
                : CustomPaint(
                    painter: LineChartPainter(widget.dataPoints, timeScale, valueScale),
                  ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_left),
              onPressed: () {
                setState(() {
                  timeScale *= 0.9;
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.arrow_right),
              onPressed: () {
                setState(() {
                  timeScale *= 1.1;
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.arrow_upward),
              onPressed: () {
                setState(() {
                  valueScale *= 1.1;
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.arrow_downward),
              onPressed: () {
                setState(() {
                  valueScale *= 0.9;
                });
              },
            ),
          ],
        ),
      ],
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<DataPoint> dataPoints;
  final double timeScale;
  final double valueScale;

  LineChartPainter(this.dataPoints, this.timeScale, this.valueScale);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2;

    // Dibujar la grilla
    final gridPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 0.5;

    for (double i = 0; i <= size.width; i += size.width / 10) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }

    for (double i = 0; i <= size.height; i += size.height / 10) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // Dibujar las líneas de datos
    for (int i = 0; i < dataPoints.length - 1; i++) {
      final p1 = Offset(dataPoints[i].x * timeScale, size.height - dataPoints[i].y * valueScale);
      final p2 = Offset(dataPoints[i + 1].x * timeScale, size.height - dataPoints[i + 1].y * valueScale);
      canvas.drawLine(p1, p2, paint);
    }

    // Dibujar referencias de x e y
    final textPainter = TextPainter(
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    );

    for (double i = 0; i <= size.width; i += size.width / 10) {
      textPainter.text = TextSpan(
        text: (i / timeScale).toStringAsFixed(1),
        style: TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(i, size.height - 20));
    }

    for (double i = 0; i <= size.height; i += size.height / 10) {
      textPainter.text = TextSpan(
        text: ((size.height - i) / valueScale).toStringAsFixed(1),
        style: TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, i));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}