import '../../routes/route_names.dart';

String destinationAfterAuthentication({
  required bool hasCompletedQuickAssessment,
}) {
  return hasCompletedQuickAssessment ? RouteNames.home : RouteNames.onboarding;
}
