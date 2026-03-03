# SmashRank

Sistema completo de gerenciamento de ranking de esportes de raquete, com cadastro de jogadores, sistema de desafios com 11 regras automatizadas, reserva de quadras com slots fixos por hora, e painel administrativo.

---

## Stack Tecnologica

| Camada | Tecnologia |
|--------|-----------|
| **Frontend** | Flutter 3.38.6 / Dart 3.10.7 |
| **Arquitetura** | MVVM (Model-View-ViewModel) feature-first |
| **State Management** | Riverpod 2.x (manual, sem code generation) |
| **Backend** | Supabase (PostgreSQL + Auth + Realtime + Storage) |
| **Navegacao** | GoRouter com auth guard |
| **Auth** | Email/Senha + Google Sign-In + Apple Sign-In |
| **Automacoes** | Vercel Cron Jobs (penalizacoes automaticas) |

---

## Decisoes Tecnicas

- **Sem code generation**: build_runner/freezed/riverpod_generator removidos por incompatibilidade com Dart 3.10.7. Todos os providers e models sao manuais.
- **API-first**: Toda a logica de negocio critica esta em funcoes PostgreSQL `SECURITY DEFINER` para garantir atomicidade e consistencia.
- **RLS (Row Level Security)**: Todas as tabelas possuem policies de seguranca.
- **Realtime**: Supabase Realtime para atualizacoes ao vivo do ranking e desafios.
- **Deep Linking**: Configurado para `smashrank://` (custom scheme) + universal links.

---

## Estrutura do Projeto

```
lib/
  main.dart                          # Entry point (ProviderScope + Supabase.initialize)
  app.dart                           # MaterialApp.router (GoRouter + Theme)

  core/
    constants/
      app_constants.dart             # Regras de negocio (cooldowns, penalizacoes, etc.)
      route_names.dart               # Nomes de todas as rotas
      supabase_constants.dart        # Nomes de tabelas e RPCs do Supabase
    errors/
      app_exception.dart             # Hierarquia de excecoes (Auth, Network, Database, etc.)
      error_handler.dart             # Mapeia erros Supabase -> AppException
    extensions/
      context_extensions.dart        # Extensions do BuildContext
      date_extensions.dart           # Formatacao de datas, timeAgo, countdown
    router/
      app_router.dart                # GoRouter com auth redirect + bottom nav shell
    theme/
      app_colors.dart                # Cores do app (tennis green, gold, status colors)
      app_text_styles.dart           # Estilos de texto
      app_theme.dart                 # ThemeData Material 3 (light + dark)
    utils/
      snackbar_utils.dart            # Helpers para exibir snackbars
      validators.dart                # Validadores de form (email, senha, telefone)

  services/
    auth_service.dart                # Wrapper do GoTrueClient (login, signup, social, reset)
    storage_service.dart             # Upload de avatar/recibos para Supabase Storage
    supabase_service.dart            # Providers do SupabaseClient, GoTrueClient, Storage

  shared/
    models/
      enums.dart                     # Enums espelhando o banco (PlayerStatus, ChallengeStatus, etc.)
      ranking_history_model.dart     # Model com fromJson/toJson, positionChange, reasonLabel
      player_model.dart              # Model completo com fromJson/toJson/copyWith manual
      challenge_model.dart           # Model com joins, proposedDates, statusLabel, computed properties
      match_model.dart               # Model com SetScore, scoreDisplay
      ambulance_model.dart           # Model com isProtected, daysActive
      court_model.dart               # Model com surfaceLabel
      court_slot_model.dart          # Model com dayLabel, timeRange
      reservation_model.dart         # Model com joins (courtName, playerName), timeRange, formattedDate
      notification_model.dart        # Model com iconLabel por tipo, challengeId navigation
    providers/
      auth_state_provider.dart       # StreamProvider do onAuthStateChange
      current_player_provider.dart   # FutureProvider do jogador logado
    widgets/
      app_scaffold.dart              # Bottom navigation (5 tabs: Ranking, Desafios, Quadras, Alertas, Perfil)

  features/
    auth/
      data/
        auth_repository.dart         # Auth + criacao automatica de player no signup
      view/
        login_screen.dart            # Login email/senha + social + links
        register_screen.dart         # Cadastro completo (nome, email, whatsapp, senha)
        forgot_password_screen.dart  # Reset de senha por email
        widgets/
          auth_form_field.dart       # TextFormField reutilizavel
          social_login_buttons.dart  # Botoes Google + Apple
      viewmodel/
        login_viewmodel.dart         # StateNotifier com login email + social
        register_viewmodel.dart      # StateNotifier com registro completo

    profile/
      data/
        player_repository.dart       # CRUD do perfil (getPlayer, getAllPlayers, update, avatar)
      view/
        profile_screen.dart          # Perfil com header, stats, info tiles, logout
        widgets/
          profile_header.dart        # Avatar + nome + nickname + email
          stats_card.dart            # Card com icone, valor e label
      viewmodel/
        profile_viewmodel.dart       # StateNotifier com updateProfile e updateAvatar

    ranking/                         # [FASE 3 - Completa]
      data/
        ranking_repository.dart      # getRanking, getRankingStream (Realtime), getPlayerHistory
      view/
        ranking_screen.dart          # Lista com posicao, avatar, nome, status (Realtime + pull-to-refresh)
        ranking_history_screen.dart  # Timeline + grafico fl_chart + resumo do jogador
        widgets/
          ranking_list_tile.dart     # Tile com badge posicao (ouro/prata/bronze), avatar, status
          ranking_position_change.dart # Indicador de subida/descida com seta colorida
          ranking_chart.dart         # Grafico de evolucao de posicao (fl_chart LineChart)
      viewmodel/
        ranking_list_viewmodel.dart  # StreamProvider com Realtime do Supabase
        ranking_history_viewmodel.dart # FutureProvider.family(playerId)

    challenges/                      # [FASE 4 - Completa]
      data/
        challenge_repository.dart    # createChallenge (RPC), proposeDates, chooseDate, recordResult (RPC), getEligibleOpponents, lifecycle completo + notificacoes (dates_proposed, date_chosen, general)
      view/
        challenges_screen.dart       # Tabs Ativos/Historico com FAB para criar desafio
        create_challenge_screen.dart # Selecao de oponente (ate 2 posicoes acima, protecao visivel)
        challenge_detail_screen.dart # Timeline do desafio, status, acoes contextuais por papel
        propose_dates_screen.dart    # Desafiado propoe 3 datas com DatePicker + TimePicker
        choose_date_screen.dart      # Desafiante escolhe 1 das 3 datas propostas
        record_result_screen.dart    # Registro de placar set a set com super tiebreak
        widgets/
      viewmodel/
        challenge_list_viewmodel.dart   # FutureProvider para desafios ativos + historico
        create_challenge_viewmodel.dart # eligibleOpponentsProvider + CreateChallengeNotifier
        challenge_detail_viewmodel.dart # challengeDetailProvider, challengeMatchProvider, ChallengeActionNotifier

    courts/                          # [FASE 5 - Completa]
      data/
        court_repository.dart        # getCourts, getSlotsForCourt, getReservationsForDate, createReservation, cancelReservation, getMyReservations
      view/
        courts_screen.dart           # Cards das quadras com tipo de piso e cobertura
        court_schedule_screen.dart   # Calendario (table_calendar) + grid de slots por horario
        my_reservations_screen.dart  # Reservas do jogador com opcao de cancelar
        widgets/
      viewmodel/
        courts_viewmodel.dart        # FutureProvider lista de quadras
        reservation_viewmodel.dart   # Providers para slots, reservas por data, minhas reservas, acoes

    notifications/                   # [FASE 6 - Completa]
      data/
        notification_repository.dart # getNotifications, getUnreadCount, markAsRead, markAllAsRead
      view/
        notifications_screen.dart    # Lista com icones por tipo, badge nao lida, marcar todas como lidas
        widgets/
      viewmodel/
        notification_viewmodel.dart  # notificationsProvider, unreadCountProvider, NotificationActionNotifier

    admin/                           # [FASE 6 - Completa]
      view/
        admin_dashboard_screen.dart  # Dashboard admin (jogadores, ambulancia, mensalidades, quadras)

supabase/
  migrations/
    001_initial_schema.sql           # 11 tabelas, 6 enums, indexes, triggers
    002_rls_policies.sql             # RLS em todas as tabelas + helper functions
    003_database_functions.sql       # 9 funcoes de logica de negocio
    004_seed_data.sql                # 3 quadras + slots horarios
    005_phase7_notifications.sql     # Notificacoes em todas as funcoes + fix RLS + bug fix expire
  full_setup.sql                     # SQL consolidado (tudo acima em 1 arquivo)

vercel-crons/                        # Cron jobs para penalizacoes automaticas
  api/cron/
    expire-challenges.js             # A cada hora: WO automatico em desafios sem resposta 48h
    daily-penalties.js               # Diario 3h: penalizacao ambulancia + inadimplencia
    monthly-penalties.js             # Dia 1 4h: penalizacao inatividade mensal
  package.json
  vercel.json                        # Schedules dos crons
  .env.example
```

---

## Banco de Dados (PostgreSQL via Supabase)

### Tabelas (11)

| Tabela | Descricao |
|--------|-----------|
| `players` | Jogadores com auth_id, ranking, cooldowns, ambulancia, mensalidade |
| `ranking_history` | Historico de todas as alteracoes de posicao |
| `challenges` | Desafios com lifecycle completo (pending -> scheduled -> completed/wo) |
| `matches` | Resultados com placar em JSONB (set a set) |
| `ambulances` | Controle de ambulancias ativas e penalizacoes diarias |
| `courts` | Quadras disponiveis |
| `court_slots` | Slots fixos por dia da semana/hora |
| `court_reservations` | Reservas especificas por data |
| `notifications` | Notificacoes in-app |
| `monthly_fees` | Mensalidades |
| `whatsapp_logs` | Logs para futura integracao N8N/WhatsApp |

### Funcoes PostgreSQL (9)

| Funcao | Descricao |
|--------|-----------|
| `swap_ranking_after_challenge()` | Troca posicoes quando desafiante vence + notifica match_result e ranking_change |
| `activate_ambulance()` | Penaliza -3 posicoes, ativa protecao 10 dias + notifica ambulance_activated |
| `deactivate_ambulance()` | Desativa ambulancia + notifica ambulance_expired |
| `apply_ambulance_daily_penalties()` | -1 posicao/dia apos protecao (cron) + notifica ranking_change |
| `apply_overdue_penalties()` | -10 posicoes por inadimplencia 15+ dias (cron) + notifica payment_overdue |
| `apply_monthly_inactivity_penalties()` | -1 posicao por inatividade mensal (cron) + notifica ranking_change |
| `validate_challenge_creation()` | Valida TODAS as regras de negocio |
| `create_challenge()` | Valida + cria desafio + notifica challenge_received |
| `expire_pending_challenges()` | WO automatico apos 48h sem resposta (cron) + notifica wo_warning |

---

## Regras de Negocio (11 Regras)

1. **Desafio limitado a 2 posicoes acima** no ranking
2. **Cooldown de 48h** para o desafiante apos resultado
3. **Protecao de 24h** para o desafiado apos ser desafiado
4. **Prazo de 7 dias** para jogar apos agendar (com extensao de +2 dias por chuva)
5. **48h para responder** a um desafio (senao WO automatico)
6. **1 desafio ativo** por vez por jogador
7. **Desafiante vence**: toma a posicao do desafiado, desafiado desce 1
8. **Desafiado vence**: ninguem muda de posicao
9. **Ambulancia**: -3 posicoes imediato, 10 dias protegido, depois -1/dia
10. **Inadimplencia 15+ dias**: -10 posicoes e bloqueio de desafios
11. **Inatividade mensal**: -1 posicao se nao participou de nenhum desafio no mes

---

## O Que Ja Foi Implementado

### Fase 1 - Setup do Projeto + Banco de Dados (COMPLETA)
- [x] Projeto Flutter criado com todas as dependencias
- [x] Estrutura de pastas MVVM feature-first completa
- [x] 4 SQL migrations (schema, RLS, functions, seed)
- [x] SQL consolidado (`full_setup.sql`)
- [x] Infraestrutura core (theme Material 3, router, services, constants, errors, extensions, utils)
- [x] `flutter analyze` = 0 issues

### Fase 2 - Auth + Cadastro de Jogadores (COMPLETA)
- [x] PlayerModel com fromJson/toJson/copyWith manual (25+ campos)
- [x] AuthService (email, Google, Apple, reset password)
- [x] StorageService (upload avatar/recibos)
- [x] AuthRepository (auth + criacao automatica de player no signup/social login)
- [x] Auth state providers (StreamProvider + current player)
- [x] LoginViewModel + RegisterViewModel
- [x] ProfileViewModel (update profile, update avatar)
- [x] PlayerRepository (CRUD)
- [x] Tela de Login (email/senha + social + links)
- [x] Tela de Cadastro (nome, email, whatsapp, senha, confirmacao)
- [x] Tela de Recuperacao de Senha
- [x] Tela de Perfil (header, stats, info tiles, logout)
- [x] GoRouter com auth guard + bottom navigation shell
- [x] `flutter analyze` = 0 issues

### Fase 3 - Sistema de Ranking (COMPLETA)
- [x] RankingHistoryModel com fromJson/toJson, positionChange, reasonLabel
- [x] RankingRepository (getRanking, getRankingStream Realtime, getPlayerHistory)
- [x] RankingListViewModel (StreamProvider com Supabase Realtime)
- [x] RankingHistoryViewModel (FutureProvider.family por playerId)
- [x] Tela de Ranking (lista Realtime, pull-to-refresh, badges ouro/prata/bronze, status icons)
- [x] Tela de Historico de Ranking (summary card, grafico fl_chart, timeline com dots coloridos)
- [x] Widgets: ranking_list_tile, ranking_position_change, ranking_chart
- [x] `flutter analyze` = 0 issues

### Fase 4 - Sistema de Desafios (COMPLETA)
- [x] ChallengeModel com joins (challengerName, challengedName, avatarUrls), computed properties, statusLabel PT-BR
- [x] MatchModel com SetScore (placar set a set), scoreDisplay
- [x] AmbulanceModel com isProtected, daysActive
- [x] ChallengeRepository (createChallenge RPC, proposeDates, chooseDate, recordResult RPC, cancelChallenge, getEligibleOpponents, validateChallenge RPC)
- [x] ViewModels: challenge_list (ativos + historico), create_challenge (oponentes elegiveis), challenge_detail (acoes do lifecycle)
- [x] Tela de Desafios (tabs Ativos/Historico, FAB para criar, status colors, win/loss indicators)
- [x] Tela de Criar Desafio (lista oponentes elegiveis, avatar, posicao, protecao, confirmacao dialog)
- [x] Tela de Detalhe do Desafio (players card VS, status com countdown, datas propostas, resultado, acoes contextuais)
- [x] Tela de Propor Datas (3 DatePicker + TimePicker, cards interativos, validacao)
- [x] Tela de Escolher Data (radio selection entre 3 datas, indicadores hoje/amanha/expirada)
- [x] Tela de Registrar Resultado (selecao vencedor, placar set a set com dropdowns, super tiebreak toggle, preview)
- [x] Rotas GoRouter para deep linking (challenges/:challengeId, challenges/create)
- [x] `flutter analyze` = 0 issues
- [x] Sistema de ambulancia (admin) - implementado na Fase 6

### Fase 5 - Reserva de Quadra (COMPLETA)
- [x] CourtModel com surfaceLabel (saibro, dura, grama)
- [x] CourtSlotModel com dayLabel, dayShort, timeRange
- [x] ReservationModel com joins (courtName, playerName), formattedDate, timeRange
- [x] CourtRepository (getCourts, getSlotsForCourt, getReservationsForDate, createReservation, cancelReservation, getMyReservations, getMyReservationHistory)
- [x] ViewModels: courts_viewmodel (lista quadras), reservation_viewmodel (slots por dia, reservas por data, minhas reservas, acoes)
- [x] Tela de Quadras (cards com gradiente, tipo de piso, cobertura, botao minhas reservas)
- [x] Tela de Agenda (table_calendar semana/2sem/mes, grid de slots com status disponivel/reservado/passado, botao reservar)
- [x] Tela de Minhas Reservas (cards com data destaque, horario, indicador hoje/amanha, cancelar)
- [x] Rotas GoRouter para deep linking (courts/my-reservations)
- [x] `flutter analyze` = 0 errors (2 info-level hints)
- [ ] Admin CRUD de quadras e slots - sera feito na Fase 6

### Fase 6 - Notificacoes + Admin + Polish (COMPLETA)
- [x] NotificationModel com iconLabel por tipo (12 tipos), challengeId para navegacao
- [x] NotificationRepository (getNotifications, getUnreadCount, markAsRead, markAllAsRead)
- [x] NotificationViewModels (notificationsProvider, unreadCountProvider, NotificationActionNotifier)
- [x] Tela de Notificacoes (lista com icones coloridos por tipo, indicador nao lida, marcar todas como lidas)
- [x] Badge de notificacoes nao lidas no bottom navigation bar
- [x] AppScaffold atualizado: ConsumerWidget com badge + FAB admin condicional
- [x] Painel Admin: dashboard com 4 modulos (jogadores, ambulancia, mensalidades, quadras)
- [x] Admin Jogadores: lista com status badge, acoes (ativar/desativar/suspender)
- [x] Admin Ambulancia: ativar via RPC (-3 posicoes + protecao 10 dias), desativar via RPC
- [x] `flutter analyze` = 0 errors

### Fase 7 - Notificacoes Completas + Vercel Cron Jobs (COMPLETA)
- [x] Fix RLS policy: permitir jogadores inserir notificacoes para outros
- [x] Notificacoes SQL em 7 funcoes: swap_ranking, activate/deactivate_ambulance, daily/overdue/inactivity penalties, expire_challenges
- [x] Bug fix: expire_pending_challenges - status 'scheduled' antes de chamar swap
- [x] Notificacoes Dart em 3 metodos: proposeDates (dates_proposed), chooseDate (date_chosen), cancelChallenge (general)
- [x] 12 tipos de notificacao 100% implementados
- [x] Vercel Cron Jobs: expire-challenges (horario), daily-penalties (diario 3h), monthly-penalties (dia 1 4h)
- [x] Migration 005_phase7_notifications.sql

### Fase 8 - Futuro
- [ ] Integracao WhatsApp Business API
- [ ] Push notifications (Firebase Cloud Messaging)

---

## Como Rodar

### Pre-requisitos
- Flutter 3.38+ / Dart 3.10+
- Conta no Supabase

### Setup
1. Clone o repositorio
2. Copie `.env.example` para `.env` e preencha com suas credenciais Supabase
3. Execute o `supabase/full_setup.sql` no SQL Editor do Supabase
4. Configure os providers de auth no Supabase Dashboard (Email, Google, Apple)
5. Crie os buckets de Storage: `avatars`, `receipts`
6. Ative Realtime nas tabelas `players`, `challenges`, `ranking_history`

```bash
flutter pub get
flutter run
```

### Configuracao do Supabase
- **Authentication**: Habilitar Email/Senha + Google + Apple
- **Storage**: Criar buckets `avatars` (public) e `receipts` (private)
- **Realtime**: Ativar nas tabelas `players`, `challenges`, `ranking_history`
- **Database**: Executar `full_setup.sql` no SQL Editor

---

## Dependencias Principais

| Pacote | Versao | Uso |
|--------|--------|-----|
| flutter_riverpod | ^2.6.1 | State management |
| supabase_flutter | ^2.8.0 | Backend (DB, Auth, Storage, Realtime) |
| go_router | ^14.8.1 | Navegacao declarativa com auth guard |
| fl_chart | ^0.70.2 | Graficos de ranking |
| table_calendar | ^3.2.0 | Calendario de reservas |
| cached_network_image | ^3.4.1 | Cache de avatares |
| google_sign_in | ^6.2.2 | Login com Google |
| sign_in_with_apple | ^6.1.3 | Login com Apple |
| app_links | ^6.3.3 | Deep linking |
| image_picker | ^1.1.2 | Upload de fotos |
| flutter_dotenv | ^5.2.1 | Variaveis de ambiente |
| intl | ^0.20.2 | Formatacao de datas |
