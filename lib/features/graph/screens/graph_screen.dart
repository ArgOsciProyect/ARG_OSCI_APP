// lib/features/graph/screens/graph_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data_acquisition/domain/models/data_point.dart';
import '../../data_acquisition/domain/services/data_acquisition_service.dart';
import '../widgets/line_chart.dart';

class GraphScreen extends StatelessWidget {
  final String mode;

  const GraphScreen({required this.mode, super.key});

  @override
  Widget build(BuildContext context) {
    final DataAcquisitionService dataAcquisitionService = Get.find<DataAcquisitionService>();

    if (mode == 'Oscilloscope') {
      // Iniciar la adquisición de datos en modo Oscilloscope
      dataAcquisitionService.fetchData();
    }

    return Scaffold(
      appBar: AppBar(title: Text('Graph - $mode Mode')),
      body: Center(
        child: StreamBuilder<List<DataPoint>>(
          stream: dataAcquisitionService.dataPointsStream,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return LineChart(dataPoints: snapshot.data!);
            } else {
              return Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }
}