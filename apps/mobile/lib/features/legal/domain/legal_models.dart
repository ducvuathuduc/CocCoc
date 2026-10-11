/// Which in-app legal document is being read.
enum LegalDocumentKind { terms, privacy, acknowledgements }

/// One headed block of a legal document.
class LegalSection {
  const LegalSection({required this.heading, required this.body});
  final String heading;
  final String body;
}

/// A readable legal document (Terms, Privacy Policy, Acknowledgements).
class LegalDocument {
  const LegalDocument({
    required this.kind,
    required this.title,
    required this.updated,
    required this.intro,
    required this.sections,
  });
  final LegalDocumentKind kind;
  final String title;
  final String updated;
  final String intro;
  final List<LegalSection> sections;
}

/// An open-source package bundled in the app.
class OpenSourcePackage {
  const OpenSourcePackage({
    required this.name,
    required this.version,
    required this.license,
    required this.purpose,
  });
  final String name;
  final String version;
  final String license;
  final String purpose;
}
