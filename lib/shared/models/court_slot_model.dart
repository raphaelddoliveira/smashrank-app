class CourtSlotModel {
  final String id;
  final String courtId;
  final int dayOfWeek; // 0 = Sunday, 1 = Monday, ..., 6 = Saturday
  final String startTime; // HH:mm format
  final String endTime;
  final bool isActive;
  final DateTime createdAt;

  const CourtSlotModel({
    required this.id,
    required this.courtId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
    required this.createdAt,
  });

  String get dayLabel => switch (dayOfWeek) {
        0 => 'Domingo',
        1 => 'Segunda',
        2 => 'Terça',
        3 => 'Quarta',
        4 => 'Quinta',
        5 => 'Sexta',
        6 => 'Sábado',
        _ => '',
      };

  String get dayShort => switch (dayOfWeek) {
        0 => 'Dom',
        1 => 'Seg',
        2 => 'Ter',
        3 => 'Qua',
        4 => 'Qui',
        5 => 'Sex',
        6 => 'Sáb',
        _ => '',
      };

  String get timeRange => '${_formatTime(startTime)} - ${_formatTime(endTime)}';

  static String _formatTime(String time) {
    // Handle "HH:mm:ss" -> "HH:mm"
    final parts = time.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return time;
  }

  factory CourtSlotModel.fromJson(Map<String, dynamic> json) {
    return CourtSlotModel(
      id: json['id'] as String,
      courtId: json['court_id'] as String,
      dayOfWeek: json['day_of_week'] as int,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'court_id': courtId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'is_active': isActive,
    };
  }
}
