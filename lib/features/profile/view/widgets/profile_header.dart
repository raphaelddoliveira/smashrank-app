import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/player_model.dart';

class ProfileHeader extends StatelessWidget {
  final PlayerModel player;

  const ProfileHeader({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.secondaryGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withAlpha(60),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.background,
            ),
            child: CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.surfaceVariant,
              backgroundImage: player.avatarUrl != null
                  ? CachedNetworkImageProvider(player.avatarUrl!)
                  : null,
              child: player.avatarUrl == null
                  ? Text(
                      player.fullName.isNotEmpty
                          ? player.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 36),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          player.fullName,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        if (player.nickname != null) ...[
          const SizedBox(height: 4),
          Text(
            '"${player.nickname}"',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onBackgroundMedium,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          player.email,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.onBackgroundLight,
              ),
        ),
        if (player.bio != null && player.bio!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            player.bio!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onBackgroundMedium,
                ),
          ),
        ],
      ],
    );
  }
}
