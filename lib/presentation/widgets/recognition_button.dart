// lib/presentation/widgets/recognition_button.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../application/controllers/setup_controller.dart';

class RecognitionButton extends StatelessWidget {
  final SetupController controller = Get.find<SetupController>();

  RecognitionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        try {
          await controller.sendMessageToDevice("ack");
          Get.snackbar('Success', 'Recognition message sent successfully');
        } catch (e) {
          Get.snackbar('Error', 'Failed to send recognition message: $e');
        }
      },
      child: Text('Send Recognition'),
    );
  }
}