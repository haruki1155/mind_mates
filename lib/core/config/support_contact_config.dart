enum SupportContactType { emergency, crisis, counseling, generalInformation }

enum SupportContactVerificationStatus { verified, unverified, expired }

class SupportContact {
  const SupportContact({
    required this.value,
    required this.type,
    required this.displayName,
    required this.availability,
    required this.verificationStatus,
    required this.verifiedAt,
    required this.approvingAuthority,
    required this.enabled,
  });

  final String value;
  final SupportContactType type;
  final String displayName;
  final String availability;
  final SupportContactVerificationStatus verificationStatus;
  final DateTime? verifiedAt;
  final String approvingAuthority;
  final bool enabled;

  bool get isDisplayable =>
      enabled &&
      verificationStatus == SupportContactVerificationStatus.verified &&
      value.trim().isNotEmpty &&
      verifiedAt != null &&
      approvingAuthority.trim().isNotEmpty;

  factory SupportContact.fromJson(Map<String, dynamic> json) {
    T enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) =>
        values.where((item) => item.name == raw?.toString()).firstOrNull ??
        fallback;
    return SupportContact(
      value: json['value']?.toString().trim() ?? '',
      type: enumValue(
        SupportContactType.values,
        json['type'],
        SupportContactType.generalInformation,
      ),
      displayName: json['displayName']?.toString().trim() ?? '',
      availability: json['availability']?.toString().trim() ?? '',
      verificationStatus: enumValue(
        SupportContactVerificationStatus.values,
        json['verificationStatus'],
        SupportContactVerificationStatus.unverified,
      ),
      verifiedAt: DateTime.tryParse(json['verifiedAt']?.toString() ?? ''),
      approvingAuthority: json['approvingAuthority']?.toString().trim() ?? '',
      enabled: json['enabled'] == true,
    );
  }
}

class SupportContactConfig {
  const SupportContactConfig({this.contacts = const []});

  final List<SupportContact> contacts;

  List<SupportContact> get displayableContacts => contacts
      .where((contact) => contact.isDisplayable)
      .toList(growable: false);

  static const unavailable = SupportContactConfig();
  static const safeFallback =
      'Verified contact details are not currently available in MindMate. For urgent concerns, contact a locally verified emergency service, go to the nearest appropriate emergency facility, or ask a trusted person or qualified professional to help you connect with local support. Completing an assessment does not alert anyone automatically.';
}
