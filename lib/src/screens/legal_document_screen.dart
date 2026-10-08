import 'package:flutter/material.dart' hide Text;
import '../core/i18n.dart';

enum LegalDocumentType { terms, privacy }

abstract final class LegalDocuments {
  static const termsVersion = '2026-10-08-v8';
  static const privacyVersion = '2026-10-08-v7';

  static LegalDocument documentFor(LegalDocumentType type) {
    return switch (type) {
      LegalDocumentType.terms => _terms,
      LegalDocumentType.privacy => _privacy,
    };
  }

  static const _terms = LegalDocument(
    title: 'Terms & Conditions',
    effectiveDate: '8 October 2026',
    introduction:
        'These Terms & Conditions govern your use of VriendTime. By creating an account, you agree to these terms.',
    sections: [
      LegalSection(
        heading: '1. About VriendTime',
        paragraphs: [
          'VriendTime helps adults join a small Friendship Circle that meets weekly for six weeks. VriendTime forms the group, sets the schedule, and provides meetup details, reminders, a group chat, and links that help you add a meetup to your calendar.',
          'VriendTime is a facilitator. Unless we expressly say otherwise, venues and other attendees are independent third parties and are not our employees or agents.',
          'VriendTime is run by Pratikesh Singh, a private individual in the Netherlands. You can reach us at support@vriendtime.com.',
        ],
      ),
      LegalSection(
        heading: '2. Eligibility and your account',
        paragraphs: [
          'You must be at least 18 years old and legally able to enter into these terms. You must provide accurate information, keep it current, protect your password, and tell us promptly if you believe your account has been misused.',
          'You may not create an account for someone else, impersonate another person, or use VriendTime after your account has been suspended or closed without our permission.',
        ],
      ),
      LegalSection(
        heading: '3. Friendship Circles, payments and meetups',
        paragraphs: [
          'The founding Circle programme costs €19 once for six weeks. Food, drinks, travel, and activity purchases are separate. There is no subscription or further programme fee after graduation. Your group and schedule are shown before you accept the invitation.',
          'Accepting an invitation requires an explicit agreement to pay €19. You pay with the payment link shown in the app; during the pilot this is a Tikkie or bank payment link from the organiser. Accepting does not collect money. Your place and group chat open when the organiser confirms receipt.',
          'Each Circle is a leisure service on fixed dates. For this kind of service the statutory 14-day right of withdrawal for online purchases does not apply. Instead, the following cancellation rules apply.',
          'Before your first meetup: until 48 hours before the first meetup starts, you can leave your Circle in the app and ask for your €19 back. We may ask why you are leaving, so we can offer you another group instead. If you still want a refund, we check your request and refund the full €19 to the account you paid from.',
          'After that: the €19 is not refunded. If your Circle does not feel right, you can switch to another group once, free of charge, until your second meetup starts (also before your first meetup). You keep your place on the waiting list and your €19 covers the new Circle. If we cannot offer you a new group within a reasonable time, we refund your €19. After your second meetup has started, no switch or refund is possible, and joining a further Circle means paying again.',
          'If VriendTime cancels your Circle, received programme fees are always refunded. If you leave because of a safety concern you have reported to us, we will look at a refund or a free move with you, separately from the rules above. Refunds are arranged manually and these terms do not limit any rights you have under mandatory consumer law. Contact the organiser for other cancellation or payment concerns.',
          'Meetup details such as the venue, time or activity may change. For the weeks we plan, the exact venue is shared shortly before the meetup. Venue details must not be used to disrupt the venue or compromise another member’s safety. If a meetup is cancelled or materially changed, we tell your Circle in the app.',
          'Venue purchases and services supplied directly by a third party may be governed by that third party’s own terms.',
          'Food and drinks are prepared and supplied by independent venues, not VriendTime. You are responsible for deciding what you consume, checking ingredients and allergens directly with the venue, communicating dietary needs, and deciding whether a venue’s food or hygiene practices are suitable for you. VriendTime cannot guarantee that food is allergen-free, safe for a particular diet, or that you will enjoy it.',
        ],
      ),
      LegalSection(
        heading: '4. Community conduct and safety',
        paragraphs: [
          'Treat other members, venue staff, and the public with respect. Harassment, discrimination, threats, violence, unwanted sexual conduct, stalking, fraud, spam, illegal activity, and conduct that puts anyone at risk are prohibited.',
          'Do not post or send unlawful, abusive, misleading, or privacy-invasive content. Do not share another person’s contact details, photos, messages, or precise location without permission.',
          'Meeting people involves real-world risk. Other attendees are people who have also registered with VriendTime and may otherwise be unknown to us. Unless we explicitly state otherwise, we do not conduct criminal-background, identity, health, or character checks. We cannot guarantee any attendee’s identity, intentions, behaviour, health status, or compatibility with you.',
          'We take reasonable steps to design safer meetups, set conduct rules, protect private venue details, and respond to concerns. Those steps cannot eliminate every risk. Use your judgment, protect your belongings, arrange your own safe travel, leave any situation that feels unsafe, and contact local emergency services if there is immediate danger.',
        ],
      ),
      LegalSection(
        heading: '5. Your content',
        paragraphs: [
          'You retain ownership of content you submit, such as profile details, photos, and messages. You give VriendTime a limited, worldwide, non-exclusive licence to host, store, reproduce, display, and process that content only as needed to operate, secure, and improve the service.',
          'You confirm that you have the rights needed to submit your content and that it does not violate another person’s rights or these terms.',
          'You can report content or behaviour that breaks these terms with Report a concern in the app, or by email to support@vriendtime.com. We may remove messages, photos or other content that break these terms, and we may take a member out of a Circle when that is needed to keep members safe. If we remove your content or take you out of a Circle, we tell you, and you can email support@vriendtime.com to ask why or to object.',
        ],
      ),
      LegalSection(
        heading: '6. Our service and intellectual property',
        paragraphs: [
          'VriendTime and its software, branding, design, and original content are protected by intellectual-property laws. We give you a personal, limited, revocable, non-transferable right to use the service for its intended purpose.',
          'You may not copy, sell, scrape, reverse engineer, interfere with, overload, or attempt to gain unauthorised access to the service, except where applicable law expressly permits it.',
        ],
      ),
      LegalSection(
        heading: '7. Suspension and ending your account',
        paragraphs: [
          'You may stop using VriendTime at any time and can permanently delete your account from the Account section of your Profile. We may restrict, suspend, or close an account when reasonably necessary to protect members or the service, investigate suspected misuse, comply with law, or enforce these terms.',
          'Account closure does not remove obligations or rights that by their nature continue, including provisions about intellectual property, liability, disputes, and amounts already due.',
        ],
      ),
      LegalSection(
        heading: '8. Disclaimers and liability',
        paragraphs: [
          'We aim to provide a reliable service, but VriendTime is provided on an “as available” basis. We do not promise uninterrupted operation, that every meetup will proceed, or that information supplied by members, venues, or other third parties will always be complete or accurate.',
          'You choose voluntarily whether to join a Circle and whether to attend, stay at, eat or drink at, travel to, or interact with people at a meetup. To the fullest extent permitted by law, you accept responsibility for those choices and for your own health, allergies, dietary decisions, personal safety, belongings, conduct, conversations, expectations, and enjoyment. A disappointing experience, personal incompatibility, illness caused by an independent venue, loss of property, or harm caused by another attendee or third party is not something VriendTime can guarantee against.',
          'To the fullest extent permitted by law, VriendTime is not responsible for the acts or omissions of attendees, venues, transport providers, or other independent third parties, or for indirect or unforeseeable loss. Nothing in these terms excludes or limits liability that cannot legally be excluded, including liability for our own intent or deliberate recklessness, death or personal injury caused by negligence where applicable, or your mandatory rights as a consumer.',
        ],
      ),
      LegalSection(
        heading: '9. Changes',
        paragraphs: [
          'We may update the service or these terms. If a change materially affects your rights, we will provide reasonable notice in the app, by email, or through another appropriate channel. Where required, we will ask you to accept updated terms before continuing to use the service.',
        ],
      ),
      LegalSection(
        heading: '10. Governing law and support',
        paragraphs: [
          'These terms are governed by Dutch law. If you are a consumer, this does not take away mandatory protections or courts available to you under the law of your country of residence. We encourage you to contact us first so we can try to resolve a concern informally.',
          'Questions about these terms: email support@vriendtime.com, or use Help & contact in the app.',
        ],
      ),
    ],
  );

  static const _privacy = LegalDocument(
    title: 'Privacy Policy',
    effectiveDate: '8 October 2026',
    introduction:
        'This policy explains how VriendTime collects, uses, shares, and protects personal data when you use the app and related services.',
    sections: [
      LegalSection(
        heading: '1. Who is responsible for your data',
        paragraphs: [
          'VriendTime is run by Pratikesh Singh, a private individual in the Netherlands, who is the controller responsible for the processing described in this policy. You can raise privacy questions and data-rights requests by email at support@vriendtime.com or through Help & contact in the app.',
        ],
      ),
      LegalSection(
        heading: '2. Data we collect',
        paragraphs: [
          'Account data: email address, password authentication records, first name, account identifiers, and account timestamps.',
          'Profile data: first name, date of birth, profile photo, a short introduction, the languages you speak, your interests, the days and times you are free, and, if you choose to give it, a WhatsApp number. Optional fields are identified in the app.',
          'Circle data: age based on your birthday, matching goals, social style, optional life context, your six-week commitment, membership, RSVPs, extra plans you add, private meetup check-ins and optional connection choices, people you would rather not be matched with again, requests to move to another group, programme outcomes, and the optional 90-day follow-up. Organisers use matching answers to form groups. Other members cannot see your private check-ins, matching choices or payment agreements.',
          'Payment data: the €19 agreement and its version and timestamp, contact email, and organiser confirmations of payment or refund. Bank and card details are not collected through the app. Payment records and the contact email needed to resolve refunds may be retained after account deletion for accounting and dispute purposes.',
          'Communication and safety data: messages you send in your Circle’s group chat, reports, support enquiries, and information needed to investigate safety or policy concerns.',
          'Technical data: information necessary for authentication, security, diagnostics, and operation of the app, such as session data, device or browser information, IP address, and error information generated by our service providers.',
          'On your device, the app stores your sign-in session and your language choice, so you stay signed in and see the right language. We do not use tracking or advertising cookies.',
        ],
      ),
      LegalSection(
        heading: '3. How we use data and our legal bases',
        paragraphs: [
          'We process account, profile, Circle, payment and communication data to provide the service you request and perform our contract with you. This includes creating your account, matching you with a Circle, sharing meetup details with your Circle, enabling the group chat, handling payments, refunds and moves, and providing support.',
          'We process age information to enforce the adults-only eligibility rule and to support safety. We use security, diagnostic, and limited service-usage information for our legitimate interests in preventing misuse, protecting members, fixing problems, and improving VriendTime, balanced against your rights.',
          'We may process information to comply with legal obligations and to establish, exercise, or defend legal claims. Where a separate consent is legally required, we will ask for it and you may withdraw it for future processing.',
        ],
      ),
      LegalSection(
        heading: '4. What other members can see',
        paragraphs: [
          'New Circle applications require a primary profile photo for recognition. A profile photo is not identity verification. That photo is available only to your assigned Circle and authorised matching organisers. It is never shown publicly.',
          'Information is shared with the other members of your Circle only where needed for the programme: your first name, profile photo, short introduction, interests, and the messages you send to your Circle. If you give a WhatsApp number, the organiser sees it so they can contact you.',
          'Your email address, date of birth, WhatsApp number, matching answers and private account details are never shown to other members. Avoid placing private information in your introduction or in messages that other members can read.',
        ],
      ),
      LegalSection(
        heading: '5. Service providers and other recipients',
        paragraphs: [
          'We use Supabase for sign-in, the database and file storage (on servers in the EU), Netlify to host the website, Resend to send account and app emails, and Zoho Mail for our support mailbox (support@vriendtime.com). These providers process data on our instructions and under appropriate contractual safeguards. We also keep private backup copies of the database and photos, for up to eight weeks, so we can recover from mistakes or outages.',
          'You pay the €19 with a payment link (during the pilot a Tikkie or bank payment link). The payment provider and your bank process that payment under their own privacy policies; we see the name, amount and date of the payment so we can match it to your place.',
          'We may share relevant details with meetup venues, professional advisers, authorities, or safety partners when necessary to deliver a meetup, respond to an incident, protect rights and safety, or comply with law. We do not sell your personal data.',
          'If you choose an external action, such as opening WhatsApp, a maps service, or a calendar service, that provider receives information under its own privacy policy. VriendTime does not control the provider’s independent processing.',
        ],
      ),
      LegalSection(
        heading: '6. International transfers',
        paragraphs: [
          'Some service providers may process data outside the European Economic Area. Where required, we use an approved transfer mechanism, such as an adequacy decision or the European Commission’s standard contractual clauses, together with appropriate safeguards.',
        ],
      ),
      LegalSection(
        heading: '7. Retention and deletion',
        paragraphs: [
          'We keep personal data only as long as needed: account, profile, application and Circle data, and your messages, while your account exists; notifications for up to one year; safety reports for one year after they are resolved; error logs for 30 days; backups for up to eight weeks; and payment and refund records for seven years, because Dutch tax law requires it.',
          'You can permanently delete your account from Account details in your Profile. When your account is deleted, we delete its profile, Circle application, messages, notifications, and profile photos unless we must retain specific information for legal, fraud-prevention, safety, accounting, or dispute purposes. Backup copies are removed on their normal secure rotation schedule.',
        ],
      ),
      LegalSection(
        heading: '8. Your choices and rights',
        paragraphs: [
          'You can review or update your profile and matching answers in the app. Depending on applicable law, you may request access, correction, deletion, restriction, portability, or object to certain processing. You may withdraw consent without affecting earlier lawful processing.',
          'You can download your own account and Circle data from your Circle profile. Email support@vriendtime.com to make other requests. We may need to verify your identity. You also have the right to complain to the Dutch Data Protection Authority (Autoriteit Persoonsgegevens) or the supervisory authority where you live or work.',
        ],
      ),
      LegalSection(
        heading: '9. Security and children',
        paragraphs: [
          'We use technical and organisational measures intended to protect personal data, including access controls and private storage for profile photos. No system can guarantee absolute security, so keep your password private and contact us if you suspect misuse.',
          'VriendTime is for adults aged 18 and over. We do not knowingly offer the service to children. If you believe a child has provided personal data, contact us so we can investigate and delete it where appropriate.',
        ],
      ),
      LegalSection(
        heading: '10. Policy changes and support',
        paragraphs: [
          'We may update this policy as the service or law changes. We will post the new version and update its effective date. We will provide additional notice when a change is material or when the law requires it.',
          'For privacy questions, requests or complaints, email support@vriendtime.com. This works even if you no longer have an account.',
        ],
      ),
    ],
  );
}

class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.effectiveDate,
    required this.introduction,
    required this.sections,
  });

  final String title;
  final String effectiveDate;
  final String introduction;
  final List<LegalSection> sections;
}

class LegalSection {
  const LegalSection({required this.heading, required this.paragraphs});

  final String heading;
  final List<String> paragraphs;
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.type});

  final LegalDocumentType type;

  @override
  Widget build(BuildContext context) {
    final document = LegalDocuments.documentFor(type);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: SafeArea(
        top: false,
        child: SelectionArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.title,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: const Color(0xFF062B55),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Effective ${document.effectiveDate}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF138B8A),
                        ),
                      ),
                      if (isDutch) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Deze Nederlandse vertaling is er voor je gemak. Bij verschillen geldt de Engelse versie.',
                          style: TextStyle(
                              fontSize: 13, fontStyle: FontStyle.italic),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(document.introduction),
                      const SizedBox(height: 24),
                      for (final section in document.sections) ...[
                        Text(section.heading,
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: 10),
                        for (final paragraph in section.paragraphs) ...[
                          Text(
                            paragraph,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.55,
                              color: const Color(0xFF344B56),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
