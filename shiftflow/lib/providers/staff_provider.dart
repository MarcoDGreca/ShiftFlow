import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/restaurant_service.dart';

/// Provider dell'anagrafica personale del locale: espone alla UI l'elenco
/// dello staff appoggiandosi a [RestaurantService].
class StaffProvider extends ChangeNotifier {
  // ignore: unused_field  (usato quando implementeremo le sottoscrizioni)
  final RestaurantService _restaurantService;

  StaffProvider(this._restaurantService);

  List<AppUser> _staff = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<AppUser> get staff => List.unmodifiable(_staff);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Ascolta l'elenco del personale del locale.
  void listenForRestaurant(String restaurantId) {
    // TODO: sottoscrivere _restaurantService.watchStaff(...).
    throw UnimplementedError();
  }
}
