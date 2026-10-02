import 'package:uuid/uuid.dart';

import 'browser_store.dart';

class DeviceService {
  DeviceService({BrowserStore? storage}) : _storage = storage ?? const BrowserStore.local();

  static const _key = 'rapidgo.device_id';

  final BrowserStore _storage;
  String? _cached;

  Future<String?> deviceId() async {
    if (_cached != null) return _cached;
    try {
      var id = await _storage.read(key: _key);
      if (id == null || id.isEmpty) {
        id = const Uuid().v4();
        await _storage.write(key: _key, value: id);
      }
      _cached = id;
      return id;
    } catch (_) {
      return null;
    }
  }
}
