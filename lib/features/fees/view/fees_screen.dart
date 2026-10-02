import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/models/monthly_fee_model.dart';
import '../../../shared/providers/current_player_provider.dart';
import '../viewmodel/fee_viewmodel.dart';

/// Mensalidade do jogador: mostra o mês em aberto e gera o PIX no clique.
/// A cobrança só nasce na Cora quando a pessoa toca em "Gerar PIX".
class FeesScreen extends ConsumerWidget {
  const FeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mesAtual = ref.watch(mensalidadeDoMesProvider);
    final historico = ref.watch(minhasMensalidadesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mensalidade')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mensalidadeDoMesProvider);
          ref.invalidate(minhasMensalidadesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            mesAtual.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    e is AppException
                        ? e.message
                        : 'Não foi possível carregar a mensalidade.',
                  ),
                ),
              ),
              data: (fee) => fee == null
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Nenhuma mensalidade em aberto.'),
                      ),
                    )
                  : _CardMensalidade(fee: fee),
            ),
            const SizedBox(height: 24),
            Text('Histórico', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            historico.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (lista) => lista.isEmpty
                  ? const Text('Sem mensalidades anteriores.')
                  : Column(
                      children: lista
                          .map((f) => ListTile(
                                dense: true,
                                leading: Icon(
                                  f.isPaid ? Icons.check_circle : Icons.schedule,
                                  color: f.isPaid
                                      ? AppColors.success
                                      : f.isOverdue
                                          ? AppColors.error
                                          : AppColors.warning,
                                ),
                                title: Text(f.mesFormatado),
                                subtitle: Text(
                                  f.isPaid ? 'Paga' : 'Vence em ${_data(f.dueDate)}',
                                ),
                                trailing: Text('R\$ ${f.amount.toStringAsFixed(2)}'),
                              ))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

class _CardMensalidade extends ConsumerStatefulWidget {
  final MonthlyFeeModel fee;
  const _CardMensalidade({required this.fee});

  @override
  ConsumerState<_CardMensalidade> createState() => _CardMensalidadeState();
}

class _CardMensalidadeState extends ConsumerState<_CardMensalidade> {
  String? _pix;
  bool _gerando = false;

  @override
  void initState() {
    super.initState();
    _pix = widget.fee.pixCode; // já gerado antes: reaproveita
  }

  @override
  Widget build(BuildContext context) {
    final fee = widget.fee;
    final player = ref.watch(currentPlayerProvider).valueOrNull;
    final semCpf = (player?.document ?? '').isEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fee.mesFormatado, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'R\$ ${fee.amount.toStringAsFixed(2)} · vence em ${FeesScreen._data(fee.dueDate)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (fee.isPaid)
              const Row(children: [
                Icon(Icons.check_circle, color: AppColors.success),
                SizedBox(width: 8),
                Text('Mensalidade paga'),
              ])
            else if (semCpf)
              const Text(
                'Cadastre seu CPF no perfil para pagar pelo app.',
                style: TextStyle(color: AppColors.warning),
              )
            else if (_pix == null)
              ElevatedButton.icon(
                onPressed: _gerando ? null : _gerar,
                icon: _gerando
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.pix),
                label: Text(_gerando ? 'Gerando...' : 'Gerar PIX'),
              )
            else ...[
              const Text('Copie o código e pague no seu banco:'),
              const SizedBox(height: 8),
              SelectableText(
                _pix!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _pix!));
                  if (context.mounted) {
                    SnackbarUtils.showSuccess(context, 'Código PIX copiado');
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copiar código'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _gerar() async {
    setState(() => _gerando = true);
    final pix = await ref.read(feeActionProvider.notifier).gerarPix(widget.fee.id);
    if (!mounted) return;
    setState(() {
      _gerando = false;
      _pix = pix;
    });
    if (pix == null) {
      final erro = ref.read(feeActionProvider).error;
      SnackbarUtils.showError(
        context,
        erro is AppException ? erro.message : 'Não foi possível gerar o PIX.',
      );
    }
  }
}
