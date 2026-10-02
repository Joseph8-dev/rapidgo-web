class BrowserStore {
  const BrowserStore.session();
  const BrowserStore.local();

  static final Map<String, String> _data = {};

  Future<String?> read({required String key}) async => _data[key];

  Future<void> write({required String key, required String? value}) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  Future<void> delete({required String key}) async {
    _data.remove(key);
  }
}
