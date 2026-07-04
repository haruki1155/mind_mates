import '../../routes/route_names.dart';

String destinationAfterAuthentication({required bool savedQuickAssessment}) {
  return savedQuickAssessment
      ? RouteNames.quickAssessmentCategory
      : RouteNames.home;
}
