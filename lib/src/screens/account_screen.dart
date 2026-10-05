import 'package:flutter/material.dart' hide Text;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/account_deletion_service.dart';
import '../core/destructive.dart';
import '../core/i18n.dart';
import '../core/responsive.dart';
import '../widgets/section_card.dart';
import 'legal_document_screen.dart';

/// Account & support for a Circle member: the sign-in email, signing out,
/// deleting the account, and help. Everything about the member's Circle
/// profile lives in the Circle app's Profile tab.
class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.user,
    required this.onSignOut,
    required this.onDeleteAccount,
    this.isSigningOut = false,
  });

  final User user;
  final VoidCallback onSignOut;
  final Future<void> Function() onDeleteAccount;
  final bool isSigningOut;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _isDeletingAccount = false;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(24), children: [
      _ProfileAccountCard(
          motionIndex: 0,
          email: widget.user.email ?? 'Email unavailable',
          isSigningOut: widget.isSigningOut,
          isDeletingAccount: _isDeletingAccount,
          onSignOut: widget.onSignOut,
          onDeleteAccount: _confirmAccountDeletion),
      const SizedBox(height: 18),
      _ProfileHelpCard(
          motionIndex: 1,
          onOpenWhatsAppSupport: _openWhatsAppSupport,
          onOpenSafetyPage: () => _push(const _SafetyPage()),
          onOpenFaqPage: () => _push(const _FaqPage()),
          onOpenTerms: () =>
              _push(const LegalDocumentScreen(type: LegalDocumentType.terms)),
          onOpenPrivacy: () => _push(
              const LegalDocumentScreen(type: LegalDocumentType.privacy))),
    ]);
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _openWhatsAppSupport() async {
    final uri = Uri.parse('https://wa.me/31685660139');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!mounted || launched) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("We couldn't open WhatsApp. Try again in a moment."),
      ),
    );
  }

  Future<void> _confirmAccountDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.delete_forever_outlined,
          color: destructiveRed,
        ),
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your profile, photos, Circle application, messages and notifications. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep account'),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-account'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: destructiveFilledStyle,
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isDeletingAccount = true);

    try {
      await widget.onDeleteAccount();
    } on AccountDeletionException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not delete your account. Check your connection and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }
}

class _ProfileAccountCard extends StatelessWidget {
  const _ProfileAccountCard({
    required this.motionIndex,
    required this.email,
    required this.isSigningOut,
    required this.isDeletingAccount,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  final int motionIndex;
  final String email;
  final bool isSigningOut;
  final bool isDeletingAccount;
  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      motionIndex: motionIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Account', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _AccountDetailRow(
            label: t('Email'),
            value: email,
            icon: Icons.mail_outline,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSigningOut || isDeletingAccount ? null : onSignOut,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(isSigningOut ? 'Signing out...' : 'Sign out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF062B55),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF9CA9AE),
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('delete-account'),
              onPressed:
                  isSigningOut || isDeletingAccount ? null : onDeleteAccount,
              icon: isDeletingAccount
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(
                isDeletingAccount ? 'Deleting account...' : 'Delete account',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF9C2F2F),
                side: const BorderSide(color: Color(0xFFD8A1A1)),
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHelpCard extends StatelessWidget {
  const _ProfileHelpCard({
    required this.motionIndex,
    required this.onOpenWhatsAppSupport,
    required this.onOpenSafetyPage,
    required this.onOpenFaqPage,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final int motionIndex;
  final VoidCallback onOpenWhatsAppSupport;
  final VoidCallback onOpenSafetyPage;
  final VoidCallback onOpenFaqPage;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SectionCard(
      motionIndex: motionIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Support', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Get help, review safety guidance, or find quick answers.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF60727A),
            ),
          ),
          const SizedBox(height: 16),
          _NavigationTile(
            label: t('Contact us'),
            value: 'Chat with our team on WhatsApp',
            semanticHint: 'Opens WhatsApp',
            onTap: onOpenWhatsAppSupport,
          ),
          _NavigationTile(
            label: t('Safety'),
            value: 'Guidance for feeling comfortable and getting help',
            onTap: onOpenSafetyPage,
          ),
          _NavigationTile(
            label: t('FAQs'),
            value: 'Common questions about meetups',
            onTap: onOpenFaqPage,
          ),
          _NavigationTile(
            label: t('Terms & Conditions'),
            value: 'Rules for using VriendTime',
            onTap: onOpenTerms,
          ),
          _NavigationTile(
            label: t('Privacy Policy'),
            value: 'How VriendTime handles your data',
            onTap: onOpenPrivacy,
          ),
          _NavigationTile(
            label: t('Open-source licences'),
            value: 'Fonts and software VriendTime is built with',
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'VriendTime',
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqPage extends StatelessWidget {
  const _FaqPage();

  @override
  Widget build(BuildContext context) {
    return _HelpArticlePage(
      title: 'FAQs',
      intro: 'Quick answers about meetups, timing, and expectations.',
      children: const [
        _HelpAnswerCard(
            icon: Icons.euro_rounded,
            title: 'What does a Founding Circle cost?',
            body:
                '€19 one-off for the full six-week programme. Food, drinks and activities are separate. This is not a subscription.'),
        _HelpAnswerCard(
            icon: Icons.groups_2_outlined,
            title: 'Will I meet the same people?',
            body:
                'Yes. Five or six people meet once a week for six weeks. We plan the first three weeks, then your Circle takes the lead.'),
        _HelpAnswerCard(
            icon: Icons.favorite_border_rounded,
            title: 'What if the Circle does not feel right?',
            body:
                'Before your first meetup you can cancel for a full refund, up to 48 hours before it starts. Between your first and second meetup you can move to another group once, free of charge, from your Circle’s home screen. Your €19 carries over. Your reasons and private check-ins are never shared with other members.'),
        _HelpAnswerCard(
            icon: Icons.event_repeat_outlined,
            title: 'What happens after week six?',
            body:
                'Keep your group messages and arrange more meetups. No further programme payment is required.'),
      ],
    );
  }
}

class _SafetyPage extends StatelessWidget {
  const _SafetyPage();

  @override
  Widget build(BuildContext context) {
    return _HelpArticlePage(
      title: 'Safety',
      intro:
          'A few simple guidelines to help everyone feel comfortable arriving and meeting new people.',
      children: const [
        _HelpAnswerCard(
          icon: Icons.health_and_safety_outlined,
          title: 'Trust your instincts',
          body:
              "You can leave at any time. If something doesn't feel right, move somewhere safe and contact us.",
        ),
        _HelpAnswerCard(
          icon: Icons.people_outline,
          title: 'Meet in the planned setting',
          body:
              'Stay at the location shared in the app. If plans change, only go somewhere you feel comfortable.',
        ),
        _HelpAnswerCard(
          icon: Icons.support_agent_outlined,
          title: 'Reach out when needed',
          body:
              'Open Contact us from your profile to message the team directly on WhatsApp.',
        ),
      ],
    );
  }
}

class _HelpArticlePage extends StatelessWidget {
  const _HelpArticlePage({
    required this.title,
    required this.intro,
    required this.children,
  });

  final String title;
  final String intro;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFCF7),
              Color(0xFFEAF7F5),
              Color(0xFFF7ECE4),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = responsiveHorizontalPadding(
                constraints.maxWidth,
              );
              final maxWidth = responsiveContentMaxWidth(constraints.maxWidth);

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                              tooltip: t('Back to profile'),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.92,
                                ),
                                foregroundColor: const Color(0xFF062B55),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                title,
                                style: theme.textTheme.headlineSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          intro,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF60727A),
                          ),
                        ),
                        const SizedBox(height: 18),
                        ...children.map(
                          (child) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HelpAnswerCard extends StatelessWidget {
  const _HelpAnswerCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDE7E3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F4F2),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: const Color(0xFF138B8A), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.titleSmall),
                ),
                const SizedBox(height: 6),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.semanticHint,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: t('$label. $value'),
      hint: semanticHint ?? 'Open $label',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Ink(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFDDE7E3)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 360;
                  final labelText = Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  );
                  final valueText = Text(
                    value,
                    textAlign: compact ? TextAlign.left : TextAlign.right,
                    style: Theme.of(context).textTheme.bodyMedium,
                  );

                  if (compact) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              labelText,
                              const SizedBox(height: 6),
                              valueText,
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded, size: 20),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: labelText),
                      const SizedBox(width: 16),
                      Expanded(child: valueText),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountDetailRow extends StatelessWidget {
  const _AccountDetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDE7E3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F4F2),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 19, color: const Color(0xFF138B8A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF60727A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF60727A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        value,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
