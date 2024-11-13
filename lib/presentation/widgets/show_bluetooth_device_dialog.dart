// lib/presentation/widgets/show_bluetooth_device_dialog.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../application/controllers/setup_controller.dart';

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
                    title: Text(device.platformName.isNotEmpty ? device.platformName : 'Unknown Device'),
                    subtitle: Text(device.remoteId.toString()),
                    onTap: () {
                      controller.selectDevice(device);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            );
          }
        }),
        actions: <Widget>[
          TextButton(
            child: Text('Scan Again'),
            onPressed: () {
              controller.startScan();
            },
          ),
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