/// Model representing WiFi network credentials with encrypted SSID and password
class WiFiCredentials {
  /// Network SSID (name)
  final String ssid;

  /// Network password
  final String password;

  /// Creates new WiFi credentials
  ///
  /// [ssid] Network name
  /// [password] Network password
  WiFiCredentials(this.ssid, this.password);

  /// Creates WiFi credentials from JSON map
  ///
  /// [json] Map containing 'SSID' and 'Password' keys
  /// Throws [FormatException] if required fields are missing
  /// Returns parsed WiFiCredentials instance
  factory WiFiCredentials.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('SSID') || !json.containsKey('Password')) {
      throw FormatException('Missing required SSID or Password field');
    }

    return WiFiCredentials(
      json['SSID'] as String,
      json['Password'] as String,
    );
  }

  /// Converts credentials to JSON map
  ///
  /// Returns map with 'SSID' and 'Password' keys
  Map<String, dynamic> toJson() {
    return {
      'SSID': ssid,
      'Password': password,
    };
  }

  @override
  String toString() => 'WiFiCredentials(ssid: $ssid)';
}
