import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/restaurant_service.dart';

/// Provider dell'anagrafica personale del locale: espone alla UI l'elenco
/// dello staff appoggiandosi a [RestaurantService].
class StaffProvider extends ChangeNotifier {
  final RestaurantService _restaurantService;
  StreamSubscription<List<AppUser>>? _subscription;
  String? _restaurantId;

  StaffProvider(this._restaurantService);

  List<AppUser> _staff = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<AppUser> get staff => List.unmodifiable(_staff);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Il membro dello staff con questo uid, o `null` se non presente.
  AppUser? byUid(String uid) {
    for (final member in _staff) {
      if (member.uid == uid) return member;
    }
    return null;
  }

  /// Ascolta l'elenco del personale del locale.
  void listenForRestaurant(String restaurantId) {
    if (_subscription != null && _restaurantId == restaurantId) return;

    _subscription?.cancel();
    _restaurantId = restaurantId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _restaurantService.watchStaff(restaurantId).listen(
      (staff) {
        _staff = staff;
        _isLoading = false;
        notifyListeners();
      },
      onError: (_) {
        _subscription?.cancel();
        _subscription = null;
        _isLoading = false;
        _errorMessage = 'Impossibile caricare il personale.';
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
