import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/models/monthly_fee_model.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../data/fee_repository.dart';

/// Mensalidade do mês do jogador logado (criada na hora se não existir).
final mensalidadeDoMesProvider =
    FutureProvider.autoDispose<MonthlyFeeModel?>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  if (clubId == null) return null;
  return ref.watch(feeRepositoryProvider).mensalidadeDoMes(clubId);
});

/// Histórico (últimos 12 meses).
final minhasMensalidadesProvider =
    FutureProvider.autoDispose<List<MonthlyFeeModel>>((ref) async {
  return ref.watch(feeRepositoryProvider).minhasMensalidades();
});

final feeActionProvider =
    StateNotifierProvider<FeeActionNotifier, AsyncValue<String?>>((ref) {
  return FeeActionNotifier(ref.watch(feeRepositoryProvider));
});

class FeeActionNotifier extends StateNotifier<AsyncValue<String?>> {
  final FeeRepository _repository;
  FeeActionNotifier(this._repository) : super(const AsyncData(null));

  /// Emite (ou reaproveita) a cobrança PIX e devolve o copia-e-cola.
  Future<String?> gerarPix(String feeId) async {
    state = const AsyncLoading();
    try {
      final pix = await _repository.gerarPix(feeId);
      state = AsyncData(pix);
      return pix;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}
