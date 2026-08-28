import '../../../models/profile_roles.dart';
import 'admin_management_models.dart';

enum AdminSessionDecision {
  allowPortalStaff,
  allowCounselor,
  allowSuperAdmin,
  requireSuperAdminEmailVerification,
  pending,
  rejected,
  disabled,
  denied,
}

AdminSessionDecision evaluateAdminSession({
  required AccessRole accessRole,
  required StaffAccountStatus? staffAccountStatus,
  required bool emailVerified,
}) {
  if (staffAccountStatus == StaffAccountStatus.pending) {
    return AdminSessionDecision.pending;
  }
  if (staffAccountStatus == StaffAccountStatus.rejected) {
    return AdminSessionDecision.rejected;
  }
  if (staffAccountStatus == StaffAccountStatus.disabled) {
    return AdminSessionDecision.disabled;
  }
  if (accessRole == AccessRole.admin) {
    return emailVerified
        ? AdminSessionDecision.allowSuperAdmin
        : AdminSessionDecision.requireSuperAdminEmailVerification;
  }
  if (staffAccountStatus != StaffAccountStatus.approved) {
    return AdminSessionDecision.denied;
  }
  return switch (accessRole) {
    AccessRole.portalStaff => AdminSessionDecision.allowPortalStaff,
    AccessRole.counselor => AdminSessionDecision.allowCounselor,
    _ => AdminSessionDecision.denied,
  };
}
