/// Status enum representing different stages of device setup process
enum SetupStatus {
  /// Initial state before setup begins
  initial,

  /// Attempting to connect to device AP
  connecting,

  /// Scanning for available WiFi networks
  scanning,

  /// User selecting network from available options
  selecting,

  /// Configuring device with selected network
  configuring,

  /// Waiting for device to connect to new network
  waitingForNetworkChange,

  /// Setup encountered an error
  error,

  /// Setup step completed successfully
  success,

  /// Entire setup process completed
  completed
}

/// Immutable state class for tracking setup progress and data
class SetupState {
  /// Current status of setup process
  final SetupStatus status;

  /// Error message if setup failed
  final String? error;

  /// Whether current error state can be retried
  final bool canRetry;

  /// List of available WiFi networks
  final List<String> networks;

  /// Creates a new setup state
  ///
  /// [status] Current setup status
  /// [error] Optional error message
  /// [canRetry] Whether error can be retried
  /// [networks] List of available networks
  const SetupState({
    this.status = SetupStatus.initial,
    this.error,
    this.canRetry = true,
    this.networks = const [],
  });

  /// Creates a copy with optional new values
  ///
  /// Returns new SetupState instance
  SetupState copyWith({
    SetupStatus? status,
    String? error,
    bool? canRetry,
    List<String>? networks,
  }) {
    return SetupState(
      status: status ?? this.status,
      error: error ?? this.error,
      canRetry: canRetry ?? this.canRetry,
      networks: networks ?? this.networks,
    );
  }
}
