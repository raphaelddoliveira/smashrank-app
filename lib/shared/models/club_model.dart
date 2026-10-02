class ClubModel {
  final String id;
  final String name;
  final String? description;
  final String inviteCode;
  final String? avatarUrl;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Contacts
  final String? phone;
  final String? email;
  final String? website;

  // Mensalidade (cobrança pelo app). Valor nulo = cobrança desligada.
  final double? monthlyFeeAmount;
  final int? monthlyFeeDueDay;

  // Cover image
  final String? coverUrl;

  // Address
  final String? addressStreet;
  final String? addressNumber;
  final String? addressComplement;
  final String? addressNeighborhood;
  final String? addressCity;
  final String? addressState;
  final String? addressZip;

  const ClubModel({
    required this.id,
    required this.name,
    this.description,
    required this.inviteCode,
    this.avatarUrl,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.email,
    this.website,
    this.coverUrl,
    this.addressStreet,
    this.addressNumber,
    this.addressComplement,
    this.addressNeighborhood,
    this.addressCity,
    this.addressState,
    this.addressZip,
    this.monthlyFeeAmount,
    this.monthlyFeeDueDay,
  });

  bool get hasAddress =>
      addressStreet != null &&
      addressStreet!.isNotEmpty &&
      addressCity != null &&
      addressCity!.isNotEmpty;

  String? get fullAddress {
    if (!hasAddress) return null;
    final parts = <String>[];
    if (addressStreet != null && addressStreet!.isNotEmpty) {
      var street = addressStreet!;
      if (addressNumber != null && addressNumber!.isNotEmpty) {
        street += ', ${addressNumber!}';
      }
      parts.add(street);
    }
    if (addressComplement != null && addressComplement!.isNotEmpty) {
      parts.add(addressComplement!);
    }
    if (addressNeighborhood != null && addressNeighborhood!.isNotEmpty) {
      parts.add(addressNeighborhood!);
    }
    final cityState = <String>[];
    if (addressCity != null && addressCity!.isNotEmpty) {
      cityState.add(addressCity!);
    }
    if (addressState != null && addressState!.isNotEmpty) {
      cityState.add(addressState!);
    }
    if (cityState.isNotEmpty) parts.add(cityState.join(' - '));
    if (addressZip != null && addressZip!.isNotEmpty) {
      parts.add('CEP: ${addressZip!}');
    }
    return parts.join('\n');
  }

  bool get hasContacts =>
      (phone != null && phone!.isNotEmpty) ||
      (email != null && email!.isNotEmpty) ||
      (website != null && website!.isNotEmpty);

  factory ClubModel.fromJson(Map<String, dynamic> json) {
    return ClubModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      inviteCode: json['invite_code'] as String,
      avatarUrl: json['avatar_url'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      coverUrl: json['cover_url'] as String?,
      monthlyFeeAmount: json['monthly_fee_amount'] == null
          ? null
          : (json['monthly_fee_amount'] as num).toDouble(),
      monthlyFeeDueDay: json['monthly_fee_due_day'] as int?,
      addressStreet: json['address_street'] as String?,
      addressNumber: json['address_number'] as String?,
      addressComplement: json['address_complement'] as String?,
      addressNeighborhood: json['address_neighborhood'] as String?,
      addressCity: json['address_city'] as String?,
      addressState: json['address_state'] as String?,
      addressZip: json['address_zip'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'invite_code': inviteCode,
      'avatar_url': avatarUrl,
      'created_by': createdBy,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (website != null) 'website': website,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (addressStreet != null) 'address_street': addressStreet,
      if (addressNumber != null) 'address_number': addressNumber,
      if (addressComplement != null) 'address_complement': addressComplement,
      if (addressNeighborhood != null)
        'address_neighborhood': addressNeighborhood,
      if (addressCity != null) 'address_city': addressCity,
      if (addressState != null) 'address_state': addressState,
      if (addressZip != null) 'address_zip': addressZip,
    };
  }
}
