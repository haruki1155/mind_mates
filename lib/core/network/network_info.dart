import 'connectivity_service.dart';

class NetworkInfo {
  const NetworkInfo(this._connectivityService);

  final ConnectivityService _connectivityService;

  Future<bool> get isConnected => _connectivityService.isConnected;
}
