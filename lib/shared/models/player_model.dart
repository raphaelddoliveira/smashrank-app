import 'enums.dart';

class PlayerModel {
  final String id;
  final String authId;
  final String fullName;
  final String? nickname;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final DateTime? dateOfBirth;
  final PlayerRole role;
  final PlayerStatus status;
  final PaymentStatus feeStatus;
  final DateTime? feeDueDate;
  final DateTime? feeOverdueSince;
  final String? bio;
  final DominantHand? dominantHand;
  final String? favoriteSportId;
  final BackhandType? backhandType;
  final String? preferredSurface;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlayerModel({
    required this.id,
    required this.authId,
    required this.fullName,
    this.nickname,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.dateOfBirth,
    this.role = PlayerRole.player,
    this.status = PlayerStatus.active,
    this.feeStatus = PaymentStatus.pending,
    this.feeDueDate,
    this.feeOverdueSince,
    this.bio,
    this.dominantHand,
    this.favoriteSportId,
    this.backhandType,
    this.preferredSurface,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAdmin => role == PlayerRole.admin;
  bool get isActive => status == PlayerStatus.active;
  bool get isOnAmbulance => status == PlayerStatus.ambulance;
  bool get hasFeeOverdue => feeStatus == PaymentStatus.overdue;

  PlayerModel copyWith({
    String? id,
    String? authId,
    String? fullName,
    String? nickname,
    String? email,
    String? phone,
    String? avatarUrl,
    DateTime? dateOfBirth,
    PlayerRole? role,
    PlayerStatus? status,
    PaymentStatus? feeStatus,
    DateTime? feeDueDate,
    DateTime? feeOverdueSince,
    String? bio,
    DominantHand? dominantHand,
    String? favoriteSportId,
    BackhandType? backhandType,
    String? preferredSurface,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlayerModel(
      id: id ?? this.id,
      authId: authId ?? this.authId,
      fullName: fullName ?? this.fullName,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      role: role ?? this.role,
      status: status ?? this.status,
      feeStatus: feeStatus ?? this.feeStatus,
      feeDueDate: feeDueDate ?? this.feeDueDate,
      feeOverdueSince: feeOverdueSince ?? this.feeOverdueSince,
      bio: bio ?? this.bio,
      dominantHand: dominantHand ?? this.dominantHand,
      favoriteSportId: favoriteSportId ?? this.favoriteSportId,
      backhandType: backhandType ?? this.backhandType,
      preferredSurface: preferredSurface ?? this.preferredSurface,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      id: json['id'] as String,
      authId: json['auth_id'] as String,
      fullName: json['full_name'] as String,
      nickname: json['nickname'] as String?,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      role: PlayerRole.fromString(json['role'] as String),
      status: PlayerStatus.fromString(json['status'] as String),
      feeStatus:
          PaymentStatus.fromString(json['fee_status'] as String? ?? 'pending'),
      feeDueDate: json['fee_due_date'] != null
          ? DateTime.parse(json['fee_due_date'] as String)
          : null,
      feeOverdueSince: json['fee_overdue_since'] != null
          ? DateTime.parse(json['fee_overdue_since'] as String)
          : null,
      bio: json['bio'] as String?,
      dominantHand: json['dominant_hand'] != null
          ? DominantHand.fromString(json['dominant_hand'] as String)
          : null,
      favoriteSportId: json['favorite_sport_id'] as String?,
      backhandType: json['backhand_type'] != null
          ? BackhandType.fromString(json['backhand_type'] as String)
          : null,
      preferredSurface: json['preferred_surface'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auth_id': authId,
      'full_name': fullName,
      'nickname': nickname,
      'email': email,
      'phone': phone,
      'avatar_url': avatarUrl,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
      'role': role.name,
      'status': status.name,
      'fee_status': feeStatus.name,
      'fee_due_date': feeDueDate?.toIso8601String().split('T').first,
      'fee_overdue_since': feeOverdueSince?.toIso8601String().split('T').first,
      'bio': bio,
      'dominant_hand': dominantHand?.name,
      'favorite_sport_id': favoriteSportId,
      'backhand_type': backhandType?.dbValue,
      'preferred_surface': preferredSurface,
    };
  }

  /// Fields allowed for player self-update
  Map<String, dynamic> toUpdateJson() {
    return {
      'full_name': fullName,
      'nickname': nickname,
      'phone': phone,
      'avatar_url': avatarUrl,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
      'bio': bio,
      'dominant_hand': dominantHand?.name,
      'favorite_sport_id': favoriteSportId,
      'backhand_type': backhandType?.dbValue,
      'preferred_surface': preferredSurface,
    };
  }
}
