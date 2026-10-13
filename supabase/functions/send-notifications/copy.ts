// Email wording in English and Dutch.
//
// The database writes every notification in English (see the trigger
// circle_notification_copy). Members who use the app in Dutch get their email
// in Dutch: fixed sentences are looked up, sentences with a name, a Circle or
// a number are matched by pattern. Anything not found stays English rather
// than becoming a bad translation.

export type Lang = "en" | "nl";

const fixed: Record<string, string> = {
  // Members
  "You’re invited to a Circle": "Je bent uitgenodigd voor een Circle",
  "Meet your group and see all six dates. Accept and pay by the date shown in the app to keep your place.":
    "Maak kennis met je groep en bekijk alle zes de data. Accepteer en betaal vóór de datum in de app om je plek te houden.",
  "You’re in! Your place is confirmed": "Je bent erbij! Je plek is bevestigd",
  "We’ve received your €19. Say hello to your Circle in the chat and look at the details of your first meetup.":
    "We hebben je €19 ontvangen. Zeg hallo tegen je Circle in de chat en bekijk de details van je eerste meetup.",
  "Your €19 from your previous Circle covers this one. Say hello to your new Circle in the chat.":
    "Je €19 van je vorige Circle geldt ook voor deze. Zeg hallo tegen je nieuwe Circle in de chat.",
  "See your Circle tomorrow": "Morgen zie je je Circle",
  "How was your meetup?": "Hoe was je meetup?",
  "Pick how it felt and, if you like, who you’d enjoy seeing more of. It stays private: only you and the organiser see it.":
    "Kies hoe het voelde en, als je wilt, wie je vaker wilt zien. Het blijft privé: alleen jij en de organisator zien het.",
  "Six weeks together: well done!": "Zes weken samen: goed gedaan!",
  "Your Circle and its chat stay open, so keep making plans together. Want to meet new people as well? You can join a new Circle in the app.":
    "Je Circle en de chat blijven open, dus blijf samen plannen maken. Wil je ook nieuwe mensen ontmoeten? Je kunt je in de app aanmelden voor een nieuwe Circle.",
  "How is your Circle doing?": "Hoe gaat het met je Circle?",
  "It’s been three months since your Circle started. Answer four quick yes-or-not-yet questions about whether you’re still in touch. It helps us make better groups.":
    "Je Circle begon drie maanden geleden. Beantwoord vier korte ja-of-nog-niet-vragen over of jullie nog contact hebben. Zo maken we betere groepen.",
  "Cancellation received": "Annulering ontvangen",
  "Your cancellation is with the organiser. We’ll be in touch about your €19.":
    "Je annulering ligt bij de organisator. We nemen contact met je op over je €19.",
  "Your Circle has been cancelled": "Je Circle gaat niet door",
  "We’re sorry, this Circle can’t go ahead. If you paid, your €19 will be returned. Reply to this email if you have any questions.":
    "Het spijt ons, deze Circle kan niet doorgaan. Heb je betaald, dan krijg je je €19 terug. Heb je vragen? Beantwoord dan deze e-mail.",
  "New messages in your Circle": "Nieuwe berichten in je Circle",
  "Your Circle plan changed": "Het plan van je Circle is gewijzigd",
  "Open your Circle to see the updated activity, place, and time.":
    "Open je Circle om de nieuwe activiteit, plek en tijd te zien.",
  "Extra plan cancelled": "Extra plan geannuleerd",
  "Your Circle has a plan update": "Er is een update voor een plan van je Circle",
  "Open the plan to see the latest details.": "Open het plan voor de nieuwste details.",
  "Your refund is complete": "Je terugbetaling is afgerond",
  "The organiser has confirmed that your €19 has been returned. Contact us if it has not arrived.":
    "De organisator heeft bevestigd dat je €19 is teruggestort. Neem contact op als het niet is aangekomen.",
  "We’ll refund your €19": "We betalen je €19 terug",
  "We couldn’t find a new group in time, so the organiser will return your €19.":
    "We konden niet op tijd een nieuwe groep vinden, dus de organisator stort je €19 terug.",
  "Your €19 has not arrived yet": "Je €19 is nog niet binnen",
  "Your place was released: payment not received": "Je plek is vrijgegeven: betaling niet ontvangen",
  "A change in your Circle": "Een verandering in je Circle",
  "Someone has stepped away. Your remaining meetups are unchanged.":
    "Iemand is gestopt. Je overige meetups blijven hetzelfde.",
  "You’ve left the Circle": "Je hebt de Circle verlaten",
  "Your place is released and your refund request is with the organiser. We’ll be in touch about it.":
    "Je plek is vrijgegeven en je verzoek om terugbetaling ligt bij de organisator. We nemen er contact over op.",
  "Your place and your unpaid agreement are cancelled.": "Je plek en je onbetaalde afspraak zijn geannuleerd.",
  "Your place and unpaid agreement are cancelled.": "Je plek en je onbetaalde afspraak zijn geannuleerd.",
  "You’re switching groups": "Je stapt over naar een andere groep",
  "Your €19 carries over to your next Circle. We’ll invite you when a group fits your times.":
    "Je €19 gaat mee naar je volgende Circle. We nodigen je uit zodra er een groep bij je tijden past.",
  "You’re moving to a new group": "Je gaat naar een nieuwe groep",
  "We’ll match you with a new Circle. Your €19 carries over, so you won’t pay again.":
    "We koppelen je aan een nieuwe Circle. Je €19 gaat mee, dus je betaalt niet opnieuw.",
  "Thanks for your report": "Bedankt voor je melding",
  "The organiser has looked into it. If anything else happens, report it again or email support@vriendtime.com.":
    "De organisator heeft ernaar gekeken. Gebeurt er nog iets, meld het dan opnieuw of mail naar support@vriendtime.com.",
  "The organiser has removed you from this Circle. If you think this is a mistake, email support@vriendtime.com.":
    "De organisator heeft je uit deze Circle gehaald. Denk je dat dit een vergissing is? Mail dan naar support@vriendtime.com.",
  // Organisers
  "Someone says they paid": "Iemand zegt betaald te hebben",
  "A member says they’ve paid. Check Tikkie or your bank, then confirm the payment on the To do tab.":
    "Een lid zegt betaald te hebben. Controleer Tikkie of je bank en bevestig de betaling op het tabblad Te doen.",
  "A member asked for a refund": "Een lid vraagt om terugbetaling",
  "A member reported a concern": "Een lid heeft een zorg gemeld",
  "Open the organiser panel to read and handle it.": "Open het organisatorpaneel om het te lezen en af te handelen.",
  "A place opened in a Circle": "Er is een plek vrijgekomen in een Circle",
  "A place is overdue": "Een plek is niet op tijd betaald",
  "A member is switching groups": "Een lid stapt over naar een andere groep",
  "A member wants to move to another group": "Een lid wil naar een andere groep",
  "A member is missing meetups": "Een lid mist meetups",
  "A member left a Circle": "Een lid heeft een Circle verlaten",
  "Circles can be formed": "Er kunnen Circles worden gevormd",
  "A meetup has no place yet": "Een meetup heeft nog geen plek",
  "Enjoy your free week": "Geniet van je vrije week",
  "Things to do in VriendTime": "Te doen in VriendTime",
  "No one-to-one coffee for you this time. See you with the whole group!": "Deze keer geen één-op-één koffie voor jou. Tot ziens met de hele groep!",
};

const weekTitles: Record<string, string> = {
  "Dinner together": "Samen eten",
  "Go beyond “what do you do?”": "Meer dan “wat doe je voor werk?”",
  "Find out who’s secretly competitive": "Ontdek wie stiekem competitief is",
  "Choose something together": "Samen iets kiezen",
  "A plan of your own": "Een eigen plan",
  "One last get-together": "Nog één keer samen",
  "Something new together": "Samen iets nieuws",
  "Drinks and a good conversation": "Een drankje en een goed gesprek",
  "Bowling and a drink": "Bowlen en een drankje",
  "Drinks": "Borrelen",
  "Lunch together": "Samen lunchen",
  "Coffee and a walk": "Koffie en een wandeling",
  "Board games": "Bordspellen",
  "Coffee": "Koffie",
  "Coffee and a good conversation": "Koffie en een goed gesprek",
};

const days: Record<string, string> = { Mon: "ma", Tue: "di", Wed: "wo", Thu: "do", Fri: "vr", Sat: "za", Sun: "zo" };
const months: Record<string, string> = {
  Jan: "jan", Feb: "feb", Mar: "mrt", Apr: "apr", May: "mei", Jun: "jun",
  Jul: "jul", Aug: "aug", Sep: "sep", Oct: "okt", Nov: "nov", Dec: "dec",
};
/// "Thu 22 Oct at 19:00" → "do 22 okt om 19:00".
function when(text: string): string {
  return text.replace(/\b(Mon|Tue|Wed|Thu|Fri|Sat|Sun) (\d{2}) (\w{3})(?: at (\d{2}:\d{2}))?/g,
    (_, d, n, mo, t) => `${days[d] ?? d} ${n} ${months[mo] ?? mo}${t ? ` om ${t}` : ""}`);
}
/// Meeting points are typed by the organiser, usually "In front of …".
function place(text: string): string {
  return text.replace(/^In front of /, "Voor ");
}

const patterns: [RegExp, (m: RegExpMatchArray) => string][] = [
  [/^(.+ at \d{2}:\d{2}) · (.+)\. Running late\? Let them know in the app\.$/s, (m) =>
    `${when(m[1])} · ${place(m[2])}. Ben je later? Laat het weten in de app.`],
  [/^(\d{2}:\d{2}) at (.+)\. Running late\? Let them know in the app\.$/, (m) =>
    `${m[1]} bij ${m[2]}. Ben je later? Laat het weten in de app.`],
  [/^(.+) is running late$/, (m) => `${m[1]} is later`],
  [/^About (\d+) minutes\. Your coffee at (\d{2}:\d{2}) at (.+)\.$/, (m) =>
    `Ongeveer ${m[1]} minuten. Jullie koffie om ${m[2]} bij ${m[3]}.`],
  [/^Coffee with (.+) today$/, (m) => `Koffie met ${m[1]} vandaag`],
  [/^(\d{2}:\d{2}) at (.+)\. Running late\? Say so in the group chat\.$/, (m) =>
    `${m[1]} bij ${m[2]}. Ben je later? Laat het weten in de groepschat.`],
  [/^(\d+) payments? to confirm$/, (m) => `${m[1]} ${m[1] === "1" ? "betaling" : "betalingen"} om te bevestigen`],
  [/^(\d+) refund requests? to review$/, (m) => `${m[1]} ${m[1] === "1" ? "terugbetalingsverzoek" : "terugbetalingsverzoeken"} om te bekijken`],
  [/^(\d+) open reports?$/, (m) => `${m[1]} open ${m[1] === "1" ? "melding" : "meldingen"}`],
  [/^This week you could meet (.+)$/, (m) => `Deze week kun je ${m[1]} ontmoeten`],
  [/^(.+) is busy, but (.+) is free$/, (m) => `${m[1]} kan niet, maar ${m[2]} is vrij`],
  [/^(.+ at \d{2}:\d{2}) · (.+)\. Coffee or a drink, just the two of you\. Can you make it\? Answer in the app\.$/s, (m) =>
    `${when(m[1])} · ${place(m[2])}. Koffie of een drankje, alleen jullie twee. Kun je? Antwoord in de app.`],
  [/^You’re meeting (.+)$/, (m) => `Je spreekt af met ${m[1]}`],
  [/^(.+ at \d{2}:\d{2}) · (.+)\. Running late\? Say so in the group chat\.$/s, (m) =>
    `${when(m[1])} · ${place(m[2])}. Ben je later? Laat het weten in de groepschat.`],
  [/^(.+) would love to meet$/, (m) => `${m[1]} wil je graag ontmoeten`],
  [/^(.+) said yes to (.+)\. If your plans changed, you can still say yes in the app\.$/, (m) =>
    `${m[1]} zei ja tegen ${when(m[2])}. Als je plannen veranderd zijn, kun je in de app alsnog ja zeggen.`],
  [/^(.+) can’t make it after all$/, (m) => `${m[1]} kan toch niet`],
  [/^Your coffee on (.+) is off\. See you with the whole group!$/, (m) =>
    `Je koffie op ${when(m[1])} gaat niet door. Tot ziens met de hele groep!`],
  [/^(.+) · week (\d) on (.+): add the place so members can see it the day before\.$/, (m) =>
    `${m[1]} · week ${m[2]} op ${m[3]}: voeg de plek toe zodat leden die de dag ervoor zien.`],
  [/^(.+) · week (\d) on (.+): add the place so members know where to go\.$/, (m) =>
    `${m[1]} · week ${m[2]} op ${when(m[3])}: voeg de plek toe zodat leden weten waar ze heen moeten.`],
  [/^Your plan for week (\d)$/, (m) => `Jullie plan voor week ${m[1]}`],
  [/^Week (\d) of (.+) is planned as (.+?)(?: at (.+))?\. Want to do something else\? Change it together in the app\.$/, (m) =>
    `Week ${m[1]} van ${m[2]} staat gepland als ${weekTitles[m[3]] ?? m[3]}${m[4] ? ` bij ${m[4]}` : ""}. Liever iets anders? Pas het samen aan in de app.`],
  [/^Week (\d) needs a plan$/, (m) => `Week ${m[1]} heeft nog geen plan`],
  [/^Nobody has planned week (\d) of (.+) yet\. Pick an activity and a place together in the app\.$/, (m) =>
    `Nog niemand heeft week ${m[1]} van ${m[2]} gepland. Kies samen een activiteit en plek in de app.`],
  [/^(.+) · Open the app for the time and place\.$/, (m) =>
    `${weekTitles[m[1]] ?? m[1]} · Open de app voor de tijd en plek.`],
  [/^(\d+) new messages? in (.+)\. Open VriendTime to read and reply\.$/, (m) =>
    `${m[1]} ${m[1] === "1" ? "nieuw bericht" : "nieuwe berichten"} in ${m[2]}. Open VriendTime om te lezen en te antwoorden.`],
  [/^Your place in (.+) is confirmed once your €19 arrives\. Pay by the end of tomorrow to keep it\.$/, (m) =>
    `Je plek in ${m[1]} is bevestigd zodra je €19 binnen is. Betaal uiterlijk morgen om je plek te houden.`],
  [/^We did not receive your €19 for (.+) by your pay-by date, so your place has been released\. That is the only reason\. You are back on the waiting list, keeping your place in the queue, and we will invite you to another Circle\.$/, (m) =>
    `We hebben je €19 voor ${m[1]} niet vóór de betaaldatum ontvangen, dus je plek is vrijgegeven. Dat is de enige reden. Je staat weer op de wachtlijst, op je oude plek, en we nodigen je uit voor een andere Circle.`],
  [/^You’re no longer in (.+)$/, (m) => `Je zit niet meer in ${m[1]}`],
  [/^(.+) left (.+) and asked for their €19 back\. Open the organiser panel to review it\.$/, (m) =>
    `${m[1]} heeft ${m[2]} verlaten en vraagt de €19 terug. Open het organisatorpaneel om het te bekijken.`],
  [/^(.+) is no longer joining (.+)\. Invite someone from the Circles tab\.$/, (m) =>
    `${m[1]} doet niet meer mee aan ${m[2]}. Nodig iemand uit via het tabblad Circles.`],
  [/^(.+) has not paid for (.+) by the pay-by date\. Check Tikkie, then confirm the payment or release the place\.$/, (m) =>
    `${m[1]} heeft niet op tijd betaald voor ${m[2]}. Controleer Tikkie en bevestig de betaling of geef de plek vrij.`],
  [/^(.+) left (.+) and keeps their €19 for a new group\. Reason: (.*)$/s, (m) =>
    `${m[1]} heeft ${m[2]} verlaten en houdt de €19 voor een nieuwe groep. Reden: ${m[3]}`],
  [/^(.+) has missed (\d+) meetups\.$/, (m) => `${m[1]} heeft ${m[2]} meetups gemist.`],
  [/^(\d+) people are ready to be grouped\. Open Form Circles to see the groups\.$/, (m) =>
    `${m[1]} mensen zijn klaar om ingedeeld te worden. Open Circles vormen om de groepen te zien.`],
  [/^(.*) They have already paid; their next Circle is free\.$/s, (m) =>
    `${m[1]} Deze persoon heeft al betaald; de volgende Circle is gratis.`],
];

/// [text] in [lang]; English, or untranslatable text, comes back unchanged.
export function translate(text: string, lang: Lang): string {
  if (lang !== "nl") return text;
  // The organiser digest: one alert per line, "• Title: body".
  if (text.includes("\n") || text.startsWith("• ")) {
    return text.split("\n").map((line) => {
      if (!line.startsWith("• ")) return translate(line, lang);
      const item = line.slice(2);
      // "Title: body" when the part before the first colon is a known title.
      const cut = item.indexOf(": ");
      if (cut > 0 && fixed[item.slice(0, cut)]) {
        return `• ${fixed[item.slice(0, cut)]}: ${translate(item.slice(cut + 2), lang)}`;
      }
      return `• ${translate(item, lang)}`;
    }).join("\n");
  }
  const exact = fixed[text];
  if (exact) return exact;
  for (const [pattern, build] of patterns) {
    const m = text.match(pattern);
    if (m) return build(m);
  }
  return text;
}

/// What the button in the email says, by where it leads.
export function buttonLabel(open: string, lang: Lang): string {
  const kind = open.split(":")[0];
  const labels: Record<string, [string, string]> = {
    messages: ["Read the messages", "Lees de berichten"],
    meetup: ["See the meetup", "Bekijk de meetup"],
    checkin: ["Tell us how it went", "Laat weten hoe het was"],
    outcome: ["Answer the questions", "Beantwoord de vragen"],
    payments: ["See your payments", "Bekijk je betalingen"],
    organiser: ["Open the organiser panel", "Open het organisatorpaneel"],
  };
  const pair = labels[kind] ?? ["Open VriendTime", "Open VriendTime"];
  return lang === "nl" ? pair[1] : pair[0];
}

export const chrome = {
  greeting: (name: string | null, lang: Lang) =>
    lang === "nl" ? (name ? `Hoi ${name},` : "Hoi,") : (name ? `Hi ${name},` : "Hi,"),
  footer: (lang: Lang) =>
    lang === "nl"
      ? "Je krijgt deze e-mail omdat je je hebt aangemeld voor een Friendship Circle in Alkmaar. Je kunt deze e-mails uitzetten onder Profiel in de app."
      : "You are receiving this because you applied for a Friendship Circle in Alkmaar. You can turn these emails off under Profile in the app.",
};
