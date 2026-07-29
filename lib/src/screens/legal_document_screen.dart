import 'package:flutter/material.dart';

enum LegalDocumentType { terms, privacy }

abstract final class LegalDocuments {
  static const termsVersion = '2026-07-15-v2';
  static const privacyVersion = '2026-07-15-v2';

  static LegalDocument documentFor(LegalDocumentType type) {
    return switch (type) {
      LegalDocumentType.terms => _terms,
      LegalDocumentType.privacy => _privacy,
    };
  }

  static const _terms = LegalDocument(
    title: 'Terms & Conditions',
    effectiveDate: '15 July 2026',
    introduction:
        'These Terms & Conditions govern your use of VriendTime. By creating an account, you agree to these terms.',
    sections: [
      LegalSection(
        heading: '1. About VriendTime',
        paragraphs: [
          'VriendTime helps adults discover and reserve places at small-group social meetups. VriendTime may provide meetup information, reminders, group communication, and links that help you add an event to your calendar.',
          'VriendTime is a facilitator. Unless we expressly say otherwise, venues and other attendees are independent third parties and are not our employees or agents.',
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
        heading: '3. Meetups and reservations',
        paragraphs: [
          'Meetup availability, capacity, venue, timing, and other details may change. A reservation is not transferable unless VriendTime agrees. Exact venue information may be shared shortly before a meetup and must not be used to disrupt the venue or compromise another member’s safety.',
          'The cancellation deadline displayed in the app applies to your reservation. If a meetup is cancelled or materially changed, we will try to notify affected members using the contact details associated with their accounts.',
          'Any price or payment information shown for a meetup will be presented before you reserve. Venue purchases and services supplied directly by a third party may be governed by that third party’s own terms.',
          'Food and drinks are prepared and supplied by independent venues, not VriendTime. You are responsible for deciding what you consume, checking ingredients and allergens directly with the venue, communicating dietary needs, and deciding whether a venue’s food or hygiene practices are suitable for you. VriendTime cannot guarantee that food is allergen-free, safe for a particular diet, or that you will enjoy it.',
        ],
      ),
      LegalSection(
        heading: '4. Community conduct and safety',
        paragraphs: [
          'Treat other members, hosts, venue staff, and the public with respect. Harassment, discrimination, threats, violence, unwanted sexual conduct, stalking, fraud, spam, illegal activity, and conduct that puts anyone at risk are prohibited.',
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
          'You choose voluntarily whether to reserve, attend, stay at, eat or drink at, travel to, or interact with people at a meetup. To the fullest extent permitted by law, you accept responsibility for those choices and for your own health, allergies, dietary decisions, personal safety, belongings, conduct, conversations, expectations, and enjoyment. A disappointing experience, personal incompatibility, illness caused by an independent venue, loss of property, or harm caused by another attendee or third party is not something VriendTime can guarantee against.',
          'To the fullest extent permitted by law, VriendTime is not responsible for the acts or omissions of attendees, venues, hosts, transport providers, or other independent third parties, or for indirect or unforeseeable loss. Nothing in these terms excludes or limits liability that cannot legally be excluded, including liability for our own intent or deliberate recklessness, death or personal injury caused by negligence where applicable, or your mandatory rights as a consumer.',
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
          'Questions about these terms can be raised through Contact us in the Profile section of the app.',
        ],
      ),
    ],
  );

  static const _privacy = LegalDocument(
    title: 'Privacy Policy',
    effectiveDate: '15 July 2026',
    introduction:
        'This policy explains how VriendTime collects, uses, shares, and protects personal data when you use the app and related services.',
    sections: [
      LegalSection(
        heading: '1. Who is responsible for your data',
        paragraphs: [
          'VriendTime is the controller responsible for the processing described in this policy. You can raise privacy questions and data-rights requests through Contact us in the Profile section of the app.',
        ],
      ),
      LegalSection(
        heading: '2. Data we collect',
        paragraphs: [
          'Account data: email address, password authentication records, first and last name, account identifiers, and account timestamps.',
          'Profile and preference data: city, date of birth, gender, language, phone number, address, availability, energy and group preferences, conversation goals, dietary notes, interests, and profile photos. Optional fields are identified in the app.',
          'Meetup data: meetup selections, reservations, cancellations, attendance status, calendar actions you initiate, and notifications associated with your meetups.',
          'Communication and safety data: messages sent through available group or support features, reports, support enquiries, and information needed to investigate safety or policy concerns.',
          'Technical data: information necessary for authentication, security, diagnostics, and operation of the app, such as session data, device or browser information, IP address, and error information generated by our service providers.',
        ],
      ),
      LegalSection(
        heading: '3. How we use data and our legal bases',
        paragraphs: [
          'We process account, profile, reservation, and communication data to provide the service you request and perform our contract with you. This includes creating your account, matching your preferences to meetups, managing reservations, revealing meetup details, enabling participant communication, and providing support.',
          'We process age information to enforce the adults-only eligibility rule and to support safety. We use security, diagnostic, and limited service-usage information for our legitimate interests in preventing misuse, protecting members, fixing problems, and improving VriendTime, balanced against your rights.',
          'We may process information to comply with legal obligations and to establish, exercise, or defend legal claims. Where a separate consent is legally required, we will ask for it and you may withdraw it for future processing.',
        ],
      ),
      LegalSection(
        heading: '4. What other members can see',
        paragraphs: [
          'Information is shared with other members only where needed for social and meetup features. Depending on the feature, this may include your first name, profile photo, short introduction, interests, and messages you send to a meetup group.',
          'Your email address, date of birth, phone number, home address, dietary notes, and private account details are not intended to appear on your public member profile. Avoid placing private information in free-text fields or messages that other members can view.',
        ],
      ),
      LegalSection(
        heading: '5. Service providers and other recipients',
        paragraphs: [
          'We use Supabase to provide authentication, database, file-storage, and related backend services. Those providers process data on our instructions and under appropriate contractual safeguards.',
          'We may share relevant details with meetup venues, hosts, professional advisers, authorities, or safety partners when necessary to deliver a meetup, respond to an incident, protect rights and safety, or comply with law. We do not sell your personal data.',
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
          'We retain personal data only for as long as needed for the purposes described above. Account and active profile data are generally retained while your account is open. Operational, safety, transaction, or dispute records may be retained longer where reasonably necessary or legally required.',
          'You can permanently delete your account from the Account section of your Profile. When your account is deleted, we delete its profile, reservations, messages, notifications, and profile photos unless we must retain specific information for legal, fraud-prevention, safety, accounting, or dispute purposes. Backup copies are removed on their normal secure rotation schedule.',
        ],
      ),
      LegalSection(
        heading: '8. Your choices and rights',
        paragraphs: [
          'You can review or update many profile fields in the app. Depending on applicable law, you may request access, correction, deletion, restriction, portability, or object to certain processing. You may withdraw consent without affecting earlier lawful processing.',
          'Use Contact us in the Profile section to make a request. We may need to verify your identity. You also have the right to complain to the Dutch Data Protection Authority (Autoriteit Persoonsgegevens) or the supervisory authority where you live or work.',
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
          'Use Contact us in the Profile section for privacy questions, requests, or complaints.',
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
