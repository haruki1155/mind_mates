class DateFormatter {
  const DateFormatter._();

  static String shortDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
