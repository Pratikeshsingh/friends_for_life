/// Where a member pays the one-off €19 programme fee.
///
/// The organiser sets a payment link per Circle (for example a Tikkie) in the
/// organiser panel. The app opens it, the member pays with iDEAL, and the
/// organiser confirms receipt by hand. With one link per Circle, a payment is
/// matched among five or six names, helped by the time each member tapped
/// Pay. A link passed at build time is only a fallback for Circles without
/// their own.
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

  /// The link a member of [circle] should pay with, or null if there is none.
  static String? linkFor(Map? circle) {
    for (final candidate in [circle?['payment_link'], circleFeeLink]) {
      final uri = Uri.tryParse('${candidate ?? ''}'.trim());
      if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
        return uri.toString();
      }
    }
    return null;
  }
}
