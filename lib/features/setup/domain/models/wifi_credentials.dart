// lib/features/setup/domain/models/wifi_credentials.dart
class WiFiCredentials {
  final String ssid;
  final String password;

  WiFiCredentials(this.ssid, this.password);

  // JSON to/from Dart helper functions
  factory WiFiCredentials.fromJson(Map<String, dynamic> json) {
    return WiFiCredentials(
      json['SSID'],
      json['Password'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'SSID': ssid,
      'Password': password,
    };
  }
}