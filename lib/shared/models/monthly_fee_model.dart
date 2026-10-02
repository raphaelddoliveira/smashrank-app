class MonthlyFeeModel {
  final String id;
  final String playerId;
  final DateTime referenceMonth;
  final double amount;
  final String status; // pending | paid | overdue
  final DateTime dueDate;
  final DateTime? paidAt;
  final String? description;
  final String? pixCode;
  final String? coraInvoiceId;

  const MonthlyFeeModel({
    required this.id,
    required this.playerId,
    required this.referenceMonth,
    required this.amount,
    required this.status,
    required this.dueDate,
    this.paidAt,
    this.description,
    this.pixCode,
    this.coraInvoiceId,
  });

  bool get isPaid => status == 'paid';
  bool get isOverdue =>
      !isPaid && DateTime.now().isAfter(DateTime(dueDate.year, dueDate.month, dueDate.day, 23, 59));

  String get mesFormatado {
    const meses = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
    ];
    return '${meses[referenceMonth.month - 1]}/${referenceMonth.year}';
  }

  factory MonthlyFeeModel.fromJson(Map<String, dynamic> json) {
    return MonthlyFeeModel(
      id: json['id'] as String,
      playerId: json['player_id'] as String,
      referenceMonth: DateTime.parse(json['reference_month'] as String),
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      dueDate: DateTime.parse(json['due_date'] as String),
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at'] as String) : null,
      description: json['description'] as String?,
      pixCode: json['pix_code'] as String?,
      coraInvoiceId: json['cora_invoice_id'] as String?,
    );
  }
}
