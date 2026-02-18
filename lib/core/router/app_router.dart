import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/view/login_screen.dart';
import '../../features/auth/view/register_screen.dart';
import '../../features/auth/view/forgot_password_screen.dart';
import '../../features/clubs/view/create_club_screen.dart';
import '../../features/clubs/view/join_club_screen.dart';
import '../../features/clubs/view/club_management_screen.dart';
import '../../features/ranking/view/ranking_screen.dart';
import '../../features/ranking/view/ranking_history_screen.dart';
import '../../features/challenges/view/challenges_screen.dart';
import '../../features/challenges/view/create_challenge_screen.dart';
import '../../features/challenges/view/challenge_detail_screen.dart';
import '../../features/challenges/view/propose_dates_screen.dart';
import '../../features/challenges/view/choose_date_screen.dart';
import '../../features/challenges/view/record_result_screen.dart';
import '../../features/courts/view/courts_screen.dart';
import '../../features/courts/view/court_schedule_screen.dart';
import '../../features/courts/view/my_reservations_screen.dart';
import '../../features/notifications/view/notifications_screen.dart';
import '../../features/profile/view/profile_screen.dart';
import '../../features/admin/view/admin_dashboard_screen.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/models/court_model.dart';
import '../../services/supabase_service.dart';
import '../constants/route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final supabase = ref.watch(supabaseClientProvider);

  return GoRouter(
    initialLocation: RouteNames.ranking,
    refreshListenable: _GoRouterAuthRefresh(supabase.auth),
    redirect: (context, state) {
      final session = supabase.auth.currentSession;
      final isLoggedIn = session != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!isLoggedIn && !isAuthRoute) return RouteNames.login;
      if (isLoggedIn && isAuthRoute) return RouteNames.ranking;
      return null;
    },
    routes: [
      // Auth routes (no bottom nav)
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Main app routes with bottom nav
      ShellRoute(
        builder: (context, state, child) => AppScaffold(child: child),
        routes: [
          GoRoute(
            path: RouteNames.ranking,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: RankingScreen(),
            ),
            routes: [
              GoRoute(
                path: 'history/:playerId',
                builder: (context, state) {
                  final playerId = state.pathParameters['playerId']!;
                  final playerName =
                      state.uri.queryParameters['name'] ?? 'Jogador';
                  return RankingHistoryScreen(
                    playerId: playerId,
                    playerName: playerName,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.challenges,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ChallengesScreen(),
            ),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const CreateChallengeScreen(),
              ),
              GoRoute(
                path: ':challengeId',
                builder: (context, state) => ChallengeDetailScreen(
                  challengeId: state.pathParameters['challengeId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'propose-dates',
                    builder: (context, state) => ProposeDatesScreen(
                      challengeId: state.pathParameters['challengeId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'choose-date',
                    builder: (context, state) {
                      final extra =
                          state.extra as Map<String, dynamic>? ?? {};
                      final proposedDates =
                          extra['proposedDates'] as List<DateTime>? ?? [];
                      return ChooseDateScreen(
                        challengeId: state.pathParameters['challengeId']!,
                        proposedDates: proposedDates,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'record-result',
                    builder: (context, state) {
                      final extra =
                          state.extra as Map<String, dynamic>? ?? {};
                      return RecordResultScreen(
                        challengeId: state.pathParameters['challengeId']!,
                        challengerId: extra['challengerId'] as String? ?? '',
                        challengedId:
                            extra['challengedId'] as String? ?? '',
                        challengerName:
                            extra['challengerName'] as String? ?? 'Desafiante',
                        challengedName:
                            extra['challengedName'] as String? ?? 'Desafiado',
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.courts,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CourtsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'my-reservations',
                builder: (context, state) =>
                    const MyReservationsScreen(),
              ),
              GoRoute(
                path: ':courtId/schedule',
                builder: (context, state) {
                  final court = state.extra as CourtModel;
                  return CourtScheduleScreen(court: court);
                },
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.notifications,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: NotificationsScreen(),
            ),
          ),
          GoRoute(
            path: RouteNames.profile,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),

      // Club routes (no bottom nav)
      GoRoute(
        path: RouteNames.createClub,
        builder: (context, state) => const CreateClubScreen(),
      ),
      GoRoute(
        path: RouteNames.joinClub,
        builder: (context, state) => const JoinClubScreen(),
      ),
      GoRoute(
        path: '/clubs/:clubId/manage',
        builder: (context, state) => ClubManagementScreen(
          clubId: state.pathParameters['clubId']!,
        ),
      ),

      // Admin routes (no bottom nav)
      GoRoute(
        path: RouteNames.adminDashboard,
        builder: (context, state) => const AdminDashboardScreen(),
        routes: [
          GoRoute(
            path: 'players',
            builder: (context, state) => const AdminPlayersScreen(),
          ),
          GoRoute(
            path: 'ambulances',
            builder: (context, state) => const AdminAmbulanceScreen(),
          ),
          GoRoute(
            path: 'sports',
            builder: (context, state) => const AdminSportsScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Converts Supabase auth state changes into a [ChangeNotifier]
/// so GoRouter can react to auth events.
class _GoRouterAuthRefresh extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;

  _GoRouterAuthRefresh(GoTrueClient auth) {
    _subscription = auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
