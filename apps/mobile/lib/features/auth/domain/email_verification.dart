/// Returned by Appwrite Account.get, never inferred from a button press.
class EmailVerificationStatus {
  const EmailVerificationStatus({
    required this.userId,
    required this.email,
    required this.verified,
  });

  final String userId, email;
  final bool verified;
}
