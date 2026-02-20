import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/player_model.dart';
import '../../../shared/models/sport_model.dart';
import '../../../shared/providers/current_player_provider.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../viewmodel/profile_viewmodel.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();

  DominantHand? _dominantHand;
  String? _favoriteSportId;
  BackhandType? _backhandType;
  String? _preferredSurface;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    final player = ref.read(currentPlayerProvider).valueOrNull;
    if (player != null) {
      _nameController.text = player.fullName;
      _nicknameController.text = player.nickname ?? '';
      _phoneController.text = player.phone ?? '';
      _bioController.text = player.bio ?? '';
      _dominantHand = player.dominantHand;
      _favoriteSportId = player.favoriteSportId;
      _backhandType = player.backhandType;
      _preferredSurface = player.preferredSurface;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAndCropAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null) return;

    // Crop image (all platforms)
    XFile fileToUpload = picked;
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar foto',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
            cropStyle: CropStyle.circle,
          ),
          IOSUiSettings(
            title: 'Recortar foto',
            aspectRatioLockEnabled: true,
            cropStyle: CropStyle.circle,
          ),
          if (kIsWeb)
            WebUiSettings(context: context),
        ],
      );
      if (cropped == null) return; // user cancelled crop
      fileToUpload = XFile(cropped.path);
    } catch (_) {
      // Crop unavailable — use original
    }

    final player = ref.read(currentPlayerProvider).valueOrNull;
    if (player == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      await ref.read(profileViewModelProvider.notifier).updateAvatar(
            player.id,
            fileToUpload,
          );
      ref.invalidate(currentPlayerProvider);
      if (mounted) SnackbarUtils.showSuccess(context, 'Foto atualizada!');
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Erro ao enviar foto: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final player = ref.read(currentPlayerProvider).valueOrNull;
    if (player == null) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(profileViewModelProvider.notifier).updateProfile(
            playerId: player.id,
            fullName: _nameController.text.trim(),
            nickname: _nicknameController.text.trim().isEmpty
                ? null
                : _nicknameController.text.trim(),
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            bio: _bioController.text.trim().isEmpty
                ? null
                : _bioController.text.trim(),
            dominantHand: _dominantHand,
            favoriteSportId: _favoriteSportId,
            backhandType: _backhandType,
            preferredSurface: _preferredSurface,
          );
      ref.invalidate(currentPlayerProvider);
      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Perfil atualizado!');
        context.pop();
      }
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, 'Erro ao salvar perfil');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerAsync = ref.watch(currentPlayerProvider);
    final sportsAsync = ref.watch(allSportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Perfil')),
      body: playerAsync.when(
        data: (player) {
          if (player == null) {
            return const Center(child: Text('Jogador não encontrado'));
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAvatarSection(player),
                const SizedBox(height: 24),
                _buildPersonalSection(),
                const SizedBox(height: 24),
                _buildSportSection(sportsAsync),
                const SizedBox(height: 32),
                _buildSaveButton(),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }

  Widget _buildAvatarSection(PlayerModel player) {
    return Center(
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.secondaryGradient,
            ),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.background,
              ),
              child: CircleAvatar(
                radius: 52,
                backgroundColor: AppColors.surfaceVariant,
                backgroundImage: player.avatarUrl != null
                    ? NetworkImage(player.avatarUrl!)
                    : null,
                child: _isUploadingPhoto
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : player.avatarUrl == null
                        ? Text(
                            player.fullName.isNotEmpty
                                ? player.fullName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontSize: 40),
                          )
                        : null,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _isUploadingPhoto ? null : _pickAndCropAvatar,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dados pessoais',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Nome completo',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Nome é obrigatório' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nicknameController,
          decoration: const InputDecoration(
            labelText: 'Apelido',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Telefone',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _bioController,
          decoration: const InputDecoration(
            labelText: 'Bio',
            prefixIcon: Icon(Icons.edit_note),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
          maxLength: 200,
        ),
        const SizedBox(height: 12),
        Text(
          'Mão dominante',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<DominantHand?>(
          segments: const [
            ButtonSegment(
              value: DominantHand.right,
              label: Text('Destro'),
              icon: Icon(Icons.back_hand_outlined),
            ),
            ButtonSegment(
              value: DominantHand.left,
              label: Text('Canhoto'),
              icon: Icon(Icons.back_hand_outlined),
            ),
          ],
          selected: {_dominantHand},
          onSelectionChanged: (v) => setState(() => _dominantHand = v.first),
          emptySelectionAllowed: true,
        ),
      ],
    );
  }

  Widget _buildSportSection(AsyncValue<List<SportModel>> sportsAsync) {
    return sportsAsync.when(
      data: (sports) {
        final activeSports = sports.where((s) => s.isActive).toList();
        final selectedSport = _favoriteSportId != null
            ? activeSports
                .where((s) => s.id == _favoriteSportId)
                .firstOrNull
            : null;
        final showTennisFields = selectedSport?.isTennis == true;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esporte',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Esporte favorito',
                prefixIcon: Icon(Icons.sports),
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _favoriteSportId,
                  isDense: true,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Nenhum'),
                    ),
                    ...activeSports.map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Row(
                          children: [
                            Icon(s.iconData, size: 18),
                            const SizedBox(width: 8),
                            Text(s.name),
                          ],
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _favoriteSportId = v;
                      final sport = v != null
                          ? activeSports.where((s) => s.id == v).firstOrNull
                          : null;
                      if (sport?.isTennis != true) {
                        _backhandType = null;
                        _preferredSurface = null;
                      }
                    });
                  },
                ),
              ),
            ),
            if (showTennisFields) ...[
              const SizedBox(height: 16),
              Text(
                'Backhand',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<BackhandType?>(
                segments: const [
                  ButtonSegment(
                    value: BackhandType.oneHanded,
                    label: Text('Uma mão'),
                  ),
                  ButtonSegment(
                    value: BackhandType.twoHanded,
                    label: Text('Duas mãos'),
                  ),
                ],
                selected: {_backhandType},
                onSelectionChanged: (v) =>
                    setState(() => _backhandType = v.first),
                emptySelectionAllowed: true,
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Piso preferido',
                  prefixIcon: Icon(Icons.grid_on),
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _preferredSurface,
                    isDense: true,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Nenhum'),
                      ),
                      ...selectedSport!.facilityConfig.surfaces.map(
                        (s) => DropdownMenuItem(
                          value: s.value,
                          child: Text(s.label),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _preferredSurface = v),
                  ),
                ),
              ),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: _isSaving ? null : _save,
        icon: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check),
        label: Text(_isSaving ? 'Salvando...' : 'Salvar'),
      ),
    );
  }
}
