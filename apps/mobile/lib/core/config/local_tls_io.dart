import 'dart:io';

void installTrustedCertificate(List<int> pemBytes) {
  SecurityContext.defaultContext.setTrustedCertificatesBytes(pemBytes);
}
