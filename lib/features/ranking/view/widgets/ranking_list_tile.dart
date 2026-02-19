import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/club_member_model.dart';

class RankingListTile extends StatelessWidget {
  final ClubMemberModel member;
  final VoidCallback? onTap;

  const RankingListTile({
    super.key,
    required this.member,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final position = member.rankingPosition ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Position badge
              _PositionBadge(position: position),
              const SizedBox(width: 12),

              // Avatar
              _PlayerAvatar(member: member),
              const SizedBox(width: 12),

              // Name + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.playerName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (member.playerNickname != null)
                      Text(
                        '"${member.playerNickname}"',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.onBackgroundMedium,
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                  ],
                ),
              ),

              // Status indicators
              _StatusIndicators(member: member),

              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, color: AppColors.onBackgroundLight, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _PositionBadge extends StatelessWidget {
  final int position;

  const _PositionBadge({required this.position});

  @override
  Widget build(BuildContext context) {
    if (position <= 3) {
      final gradient = switch (position) {
        1 => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8D44D), AppColors.gold, Color(0xFFB8941F)],
          ),
        2 => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFC0C0C0), AppColors.silver, Color(0xFF888888)],
          ),
        _ => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD4955A), AppColors.bronze, Color(0xFF8B5E3C)],
          ),
      };

      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: gradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (position == 1 ? AppColors.gold : position == 2 ? AppColors.silver : AppColors.bronze).withAlpha(80),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          '$position',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: -0.3,
            color: Colors.white,
          ),
        ),
      );
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        '$position',
        style: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: -0.3,
          color: AppColors.onBackgroundMedium,
        ),
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  final ClubMemberModel member;

  const _PlayerAvatar({required this.member});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.surfaceVariant,
      backgroundImage: member.playerAvatarUrl != null
          ? CachedNetworkImageProvider(member.playerAvatarUrl!)
          : null,
      child: member.playerAvatarUrl == null
          ? Text(
              member.playerName.isNotEmpty
                  ? member.playerName[0].toUpperCase()
                  : '?',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            )
          : null,
    );
  }
}

class _StatusIndicators extends StatelessWidget {
  final ClubMemberModel member;

  const _StatusIndicators({required this.member});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (member.isOnAmbulance)
          const Tooltip(
            message: 'Ambulância ativa',
            child: Icon(Icons.local_hospital, color: AppColors.ambulanceActive, size: 18),
          ),
        if (member.isOnCooldown)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Tooltip(
              message: 'Em cooldown',
              child: Icon(Icons.timer, color: AppColors.warning, size: 18),
            ),
          ),
        if (member.isProtected)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Tooltip(
              message: 'Protegido',
              child: Icon(Icons.shield, color: AppColors.info, size: 18),
            ),
          ),
      ],
    );
  }
}
