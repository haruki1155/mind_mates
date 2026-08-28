import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/admin/domain/admin_management_models.dart';
import 'package:mind_mates/features/admin/domain/admin_session_policy.dart';
import 'package:mind_mates/models/profile_roles.dart';

void main() {
  test('approved portal staff do not require mailbox verification', () {
    expect(
      evaluateAdminSession(
        accessRole: AccessRole.portalStaff,
        staffAccountStatus: StaffAccountStatus.approved,
        emailVerified: false,
      ),
      AdminSessionDecision.allowPortalStaff,
    );
  });

  test('approved counselors do not require mailbox verification', () {
    expect(
      evaluateAdminSession(
        accessRole: AccessRole.counselor,
        staffAccountStatus: StaffAccountStatus.approved,
        emailVerified: false,
      ),
      AdminSessionDecision.allowCounselor,
    );
  });

  test('super-admin still requires a verified mailbox', () {
    expect(
      evaluateAdminSession(
        accessRole: AccessRole.admin,
        staffAccountStatus: null,
        emailVerified: false,
      ),
      AdminSessionDecision.requireSuperAdminEmailVerification,
    );
    expect(
      evaluateAdminSession(
        accessRole: AccessRole.admin,
        staffAccountStatus: null,
        emailVerified: true,
      ),
      AdminSessionDecision.allowSuperAdmin,
    );
  });

  test('approval status and portal role are both mandatory for staff', () {
    for (final status in [
      StaffAccountStatus.pending,
      StaffAccountStatus.rejected,
      StaffAccountStatus.disabled,
    ]) {
      expect(
        evaluateAdminSession(
          accessRole: AccessRole.portalStaff,
          staffAccountStatus: status,
          emailVerified: true,
        ),
        isNot(AdminSessionDecision.allowPortalStaff),
      );
    }
    expect(
      evaluateAdminSession(
        accessRole: AccessRole.appUser,
        staffAccountStatus: StaffAccountStatus.approved,
        emailVerified: true,
      ),
      AdminSessionDecision.denied,
    );
  });
}
