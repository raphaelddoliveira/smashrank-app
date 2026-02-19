import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/providers/current_player_provider.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../data/club_repository.dart';
import '../viewmodel/club_providers.dart';

class JoinClubScreen extends ConsumerStatefulWidget {
  const JoinClubScreen({super.key});

  @override
  ConsumerState<JoinClubScreen> createState() => _JoinClubScreenState();
}

class _JoinClubScreenState extends ConsumerState<JoinClubScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      SnackbarUtils.showError(context, 'Digite o código de convite');
      return;
    }

    final player = ref.read(currentPlayerProvider).valueOrNull;
    if (player == null) return;

    setState(() => _loading = true);
    try {
      await ref.read(clubRepositoryProvider).joinClubByCode(
        authId: player.authId,
        inviteCode: code,
      );

      ref.invalidate(myClubsProvider);

      if (mounted) {
        SnackbarUtils.showSuccess(
          context,
          'Solicitação enviada! Aguarde aprovação do admin.',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrar em Clube'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.qr_code_rounded,
              size: 80,
              color: AppColors.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Entre com o código de convite',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Peça o código ao admin do clube',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onBackgroundLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Código de convite',
                hintText: 'Ex: A1B2C3D4',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                fontSize: 20,
                letterSpacing: 4,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GradientButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Solicitar Entrada'),
            ),
          ],
        ),
      ),
    );
  }
}
