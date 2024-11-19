// lib/presentation/widgets/show_bluetooth_device_dialog.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../application/controllers/setup_controller.dart';
import 'ap_selection_dialog.dart';

void showBluetoothDeviceDialog(BuildContext context) {
  final SetupController controller = Get.find<SetupController>();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Select Bluetooth Device'),
        content: Obx(() {
          if (controller.isScanning) {
            return Center(child: CircularProgressIndicator());
          } else if (controller.devices.isEmpty) {
            return Center(child: Text('No devices found'));
          } else {
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: controller.devices.length,
                itemBuilder: (context, index) {
                  final device = controller.devices[index];
                  return ListTile(
                    title: Text(device.name ?? 'Unknown Device'),
                    subtitle: Text(device.deviceId),
                    onTap: () async {
                      controller.selectDevice(device);
                      final result = await controller.setupSecureConnection();
                      if (result == 'Ready' && context.mounted) {
                        Navigator.of(context).pop();
                        showAPSelectionDialog(context);
                      }
                    },
                  );
                },
              ),
            );
          }
        }),
        actions: <Widget>[
          Obx(() => TextButton(
            onPressed: controller.isScanning ? null : () {
              controller.startScan();
            },
            child: Text('Scan Again'),
          )),
          TextButton(
            child: Text('Close'),
            onPressed: () {
              controller.stopScan();
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}