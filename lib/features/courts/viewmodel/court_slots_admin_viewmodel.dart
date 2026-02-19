import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/court_slot_model.dart';
import '../data/court_repository.dart';

/// All slots for a court (including inactive) — for admin management
final allCourtSlotsProvider = FutureProvider.family<List<CourtSlotModel>, String>(
  (ref, courtId) async {
    final repo = ref.watch(courtRepositoryProvider);
    return repo.getAllSlotsForCourt(courtId);
  },
);
