/// Funções utilitárias de formatação e parsing usadas nas telas de campo.
class AgroFormatters {
  /// Formata uma data no padrão brasileiro `dd/MM/yyyy`.
  static String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  /// Formata data e hora no padrão brasileiro `dd/MM/yyyy HH:mm`.
  static String formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${formatDate(local)} $hour:$minute';
  }

  /// Formata data para `yyyy-MM-dd` (compatível com coluna `date` do PostgreSQL).
  static String toIsoDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().padLeft(4, '0');
    return '$year-$month-$day';
  }

  /// Faz o parsing de números aceitando vírgula ou ponto decimal.
  static double? tryParseDecimal(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }
}

