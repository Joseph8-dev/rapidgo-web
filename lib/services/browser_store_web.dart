import 'package:web/web.dart' as web;

class BrowserStore {
  const BrowserStore.session() : _persistent = false;
  const BrowserStore.local() : _persistent = true;

  final bool _persistent;

  web.Storage get _storage =>
      _persistent ? web.window.localStorage : web.window.sessionStorage;

  Future<String?> read({required String key}) async {
    try {
      return _storage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  Future<void> write({required String key, required String? value}) async {
    try {
      if (value == null) {
        _storage.removeItem(key);
      } else {
        _storage.setItem(key, value);
      }
    } catch (_) {}
  }

  Future<void> delete({required String key}) async {
    try {
      _storage.removeItem(key);
    } catch (_) {}
  }
}
