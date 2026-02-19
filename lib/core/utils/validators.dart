abstract final class Validators {
  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'Email obrigatório';
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value)) return 'Email inválido';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Senha obrigatória';
    if (value.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  static String? required(String? value, [String fieldName = 'Campo']) {
    if (value == null || value.trim().isEmpty) return '$fieldName obrigatório';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.isEmpty) return null; // optional
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 10 || digits.length > 13) {
      return 'Telefone inválido';
    }
    return null;
  }
}
