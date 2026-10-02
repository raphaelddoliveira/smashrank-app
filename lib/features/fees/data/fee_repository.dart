import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_handler.dart';
import '../../../shared/models/monthly_fee_model.dart';

final feeRepositoryProvider = Provider<FeeRepository>((ref) {
  return FeeRepository(Supabase.instance.client);
});

class FeeRepository {
  final SupabaseClient _client;
  FeeRepository(this._client);

  /// Mensalidade do mês do jogador logado. Criada na hora se ainda não existir
  /// — é só uma linha no nosso banco, não fala com o banco (Cora) e não custa.
  Future<MonthlyFeeModel?> mensalidadeDoMes(String clubId) async {
    try {
      final data = await _client.rpc(
        SupabaseConstants.rpcMensalidadeDoMes,
        params: {'p_club_id': clubId},
      );
      if (data == null) return null;
      final json = data is List ? data.first : data;
      return MonthlyFeeModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Histórico de mensalidades do jogador logado.
  Future<List<MonthlyFeeModel>> minhasMensalidades() async {
    try {
      final playerId = _client.auth.currentUser?.id;
      if (playerId == null) return [];
      final data = await _client
          .from(SupabaseConstants.monthlyFeesTable)
          .select()
          .order('reference_month', ascending: false)
          .limit(12);
      return data.map((e) => MonthlyFeeModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Pede o PIX ao serviço de cobrança. É AQUI que a cobrança é emitida na
  /// Cora — só no clique do jogador, nunca em lote.
  Future<String> gerarPix(String feeId) async {
    final base = AppConstants.cobrancaServiceUrl;
    if (base.isEmpty) {
      throw const ValidationException(
        'Pagamento pelo app ainda não está disponível.',
        code: 'SERVICO_NAO_CONFIGURADO',
      );
    }
    final token = _client.auth.currentSession?.accessToken;
    if (token == null) {
      throw const AuthException('Sessão expirada. Entre de novo.');
    }

    final res = await http.post(
      Uri.parse('$base/api/pix'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'fee_id': feeId}),
    );
    final corpo = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 300) {
      throw ValidationException(
        (corpo['erro'] as String?) ?? 'Não foi possível gerar o PIX.',
        code: 'PIX_${res.statusCode}',
      );
    }
    final pix = corpo['pix_code'] as String?;
    if (pix == null || pix.isEmpty) {
      throw const ValidationException('O banco não devolveu o código PIX.');
    }
    return pix;
  }
}
