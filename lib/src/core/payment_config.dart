/// Where a member pays the one-off €19 programme fee.
///
/// There is no company bank account yet, so the pilot collects the fee through
/// a personal bunq.me request rather than a checkout: the app opens the link,
/// the member pays with iDEAL, and the organiser confirms receipt by hand in
/// the admin screen. Because one link serves everyone, a payment is matched to
/// a member by the name on the transfer, which is why the app asks people to
/// pay under the name on their account.
///
/// Until a link is set, every screen falls back to "the organiser will contact
/// you", so an unset link is a quieter experience, never a broken one.
class PaymentConfig {
  /// Paste the bunq.me request URL here, or pass
  /// `--dart-define=CIRCLE_PAYMENT_LINK=https://bunq.me/...` at build time.
  static const circleFeeLink = String.fromEnvironment(
    'CIRCLE_PAYMENT_LINK',
    defaultValue: '',
  );

  /// Only https links are offered, so a mistyped value cannot send a member to
  /// something the app never intended to open.
  static bool get hasCircleFeeLink {
    final uri = Uri.tryParse(circleFeeLink);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }
}
