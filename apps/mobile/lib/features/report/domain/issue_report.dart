/// Copy for the in-lesson "Report an issue" menu (Gummble sc_f2f569c1,
/// refs/gap/report_issue_menu.png) and its toast (sc_2082f9ab).
class IssueReportContent {
  const IssueReportContent({
    this.categories = const [
      'The audio does not sound correct.',
      'The audio is missing.',
      'The hints are wrong.',
      'The hints are missing.',
      'An image does not look quite right.',
      'An image is missing.',
      'My answer should not have been accepted.',
      'There’s an issue with the English meaning.',
      'Something else went wrong.',
    ],
    this.menuLabel = 'Report an issue',
    this.successToast = 'Issue successfully reported!',
    this.failureToast = 'Report not sent. Try again.',
  });
  final List<String> categories;
  final String menuLabel, successToast, failureToast;
}

class IssueReport {
  const IssueReport({required this.exerciseId, required this.category});
  final String exerciseId, category;
}
