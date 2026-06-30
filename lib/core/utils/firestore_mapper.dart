import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? dateTimeFromFirestore(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  return DateTime.tryParse(value.toString());
}

DateTime dateTimeFromFirestoreOrNow(Object? value) {
  return dateTimeFromFirestore(value) ?? DateTime.now();
}

int intFromFirestore(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value == null) return fallback;
  return int.tryParse(value.toString()) ?? fallback;
}

bool boolFromFirestore(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value == null) return fallback;
  return value.toString().toLowerCase() == 'true';
}
