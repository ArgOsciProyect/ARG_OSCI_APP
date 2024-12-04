// lib/features/graph/screens/graph_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data_acquisition/domain/models/data_point.dart';
import '../../data_acquisition/domain/services/data_acquisition_service.dart';
import '../widgets/line_chart.dart';

class GraphScreen extends StatefulWidget {
  final String mode;

  const GraphScreen({required this.mode, super.key});

  @override
  _GraphScreenState createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  late DataAcquisitionService dataAcquisitionService;

  @override
  void initState() {
    super.initState();
    dataAcquisitionService = Get.find<DataAcquisitionService>();
    if (widget.mode == 'Oscilloscope') {
      // Iniciar la adquisición de datos en modo Oscilloscope
      dataAcquisitionService.fetchData();
    }
  }

  @override
  void dispose() {
    // Detener la adquisición de datos cuando se sale de la pantalla
    dataAcquisitionService.stopData();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Graph - ${widget.mode} Mode')),
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