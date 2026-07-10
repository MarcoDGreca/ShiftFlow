import 'package:flutter/foundation.dart';

import '../models/leave_request.dart';
import '../services/leave_request_service.dart';

/// Provider delle richieste di permesso/cambio turno: espone la lista alla UI
/// appoggiandosi a [LeaveRequestService].
class LeaveRequestProvider extends ChangeNotifier {
  // ignore: unused_field  (usato quando implementeremo le sottoscrizioni)
  final LeaveRequestService _leaveRequestService;

  LeaveRequestProvider(this._leaveRequestService);

  final List<LeaveRequest> _requests = [];
  final bool _isLoading = false;
  String? _errorMessage;

  List<LeaveRequest> get requests => List.unmodifiable(_requests);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Ascolta le richieste del singolo dipendente (storico personale).
  void listenForEmployee(String restaurantId, String employeeUid) {
    // TODO: sottoscrivere watchRequestsForEmployee(...).
    throw UnimplementedError();
  }

  /// Ascolta tutte le richieste del locale (coda del Responsabile).
  void listenForRestaurant(String restaurantId) {
    // TODO: sottoscrivere watchAllRequests(...).
    throw UnimplementedError();
  }
}
