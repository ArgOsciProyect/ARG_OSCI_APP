// lib/features/setup/domain/models/setup_state.dart
enum SetupStatus {
  initial,
  connecting,
  scanning,
  selecting,
  configuring,
  waitingForNetworkChange,
  error,
  success,
  completed
}

class SetupState {
  final SetupStatus status;
  final String? error;
  final bool canRetry;
  final List<String> networks;

  const SetupState({
    this.status = SetupStatus.initial,
    this.error,
    this.canRetry = true,
    this.networks = const [],
  });

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
