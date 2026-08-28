enum PopulationRole {
  student,
  teaching,
  nonTeaching;

  String get storedValue => name;

  String get label => switch (this) {
    PopulationRole.student => 'Student',
    PopulationRole.teaching => 'Teaching',
    PopulationRole.nonTeaching => 'Non-Teaching',
  };

  static PopulationRole? parse(Object? value) {
    final normalized = value?.toString().trim().toLowerCase().replaceAll(
      RegExp(r'[\s_-]+'),
      '',
    );
    return switch (normalized) {
      'student' => PopulationRole.student,
      'faculty' || 'teaching' || 'teachingpersonnel' => PopulationRole.teaching,
      'staff' ||
      'nonteaching' ||
      'nonteachingpersonnel' => PopulationRole.nonTeaching,
      _ => null,
    };
  }
}

enum AccessRole {
  appUser,
  portalStaff,
  counselor,
  admin;

  String get storedValue => name;
  bool get canUsePortal => this != AccessRole.appUser;
  bool get canReviewProfiles => canUsePortal;
  bool get canAccessClinicalData =>
      this == AccessRole.counselor || this == AccessRole.admin;
  bool get canManageAccess => this == AccessRole.admin;

  static AccessRole parse(Object? value, {Object? legacyRole}) {
    final normalized = value?.toString().trim().toLowerCase().replaceAll(
      RegExp(r'[\s_-]+'),
      '',
    );
    if (normalized == 'portalstaff') return AccessRole.portalStaff;
    if (normalized == 'counselor' || normalized == 'counsellor') {
      return AccessRole.counselor;
    }
    if (normalized == 'admin') return AccessRole.admin;
    final legacy = legacyRole?.toString().trim().toLowerCase();
    if (legacy == 'admin') return AccessRole.admin;
    if (legacy == 'counselor' || legacy == 'counsellor') {
      return AccessRole.counselor;
    }
    return AccessRole.appUser;
  }
}
