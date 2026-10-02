import '../config/api_config.dart';
import '../models/shop.dart';
import 'api_service.dart';

class CatalogService {
  CatalogService(this._api);

  final ApiService _api;

  Future<List<Shop>> shops({String? category}) async {
    final res = await _api.get(
      ApiConfig.shops,
      query: category == null ? null : {'category': category},
    );
    return (res['shops'] as List<dynamic>? ?? [])
        .map((e) => Shop.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Catalog> catalog(int shopId) async =>
      Catalog.fromJson(await _api.get(ApiConfig.catalog(shopId)));
}
