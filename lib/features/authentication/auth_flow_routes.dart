import '../../routes/route_names.dart';
import '../../models/user_model.dart';
import '../../features/admin/domain/admin_management_models.dart';

enum AccountState {
  signedOut,
  resolving,
  profileRecoveryRequired,
  onboardingRequired,
  assessmentRequired,
  ready,
  suspended,
  error,
}

AccountState resolveAccountState({
  required bool isAuthenticated,
  required UserModel? profile,
  bool? assessmentCompleted,
  bool onboardingComplete = false,
  bool hasError = false,
}) {
  if (!isAuthenticated) return AccountState.signedOut;
  if (hasError) return AccountState.error;
  if (profile == null) return AccountState.profileRecoveryRequired;
  final status = profile.staffAccountStatus;
  if (status == StaffAccountStatus.disabled ||
      status == StaffAccountStatus.rejected) {
    return AccountState.suspended;
  }
  if (assessmentCompleted == null) return AccountState.resolving;
  if (!onboardingComplete) return AccountState.onboardingRequired;
  if (!assessmentCompleted) return AccountState.assessmentRequired;
  return AccountState.ready;
}

String destinationForAccountState(AccountState state) {
  return switch (state) {
    AccountState.onboardingRequired => RouteNames.onboarding,
    AccountState.assessmentRequired => RouteNames.assessmentStatus,
    AccountState.ready => RouteNames.home,
    AccountState.profileRecoveryRequired => RouteNames.finishAccountSetup,
    AccountState.signedOut => RouteNames.login,
    _ => RouteNames.assessmentStatus,
  };
}

String destinationAfterAuthentication({
  required bool hasCompletedQuickAssessment,
}) {
  return hasCompletedQuickAssessment ? RouteNames.home : RouteNames.onboarding;
}
