// Email wording in English and Dutch.
//
// The database writes every notification in English (see the trigger
// circle_notification_copy). Members who use the app in Dutch get their email
// in Dutch: fixed sentences are looked up, sentences with a name, a Circle or
// a number are matched by pattern. Anything not found stays English rather
// than becoming a bad translation.

export type Lang = "en" | "nl";

const fixed: Record<string, string> = {
  // Small wins (20261041)
  "A WhatsApp group for your Circle?": "Een WhatsApp-groep voor je Circle?",
  "If you like, we’ll make a WhatsApp group for your Circle, next to the app. Answer in the app: only people who say yes are added.":
    "Als je wilt, maken we een WhatsApp-groep voor je Circle, naast de app. Antwoord in de app: alleen wie ja zegt, wordt toegevoegd.",
  "A WhatsApp group can be made": "Er kan een WhatsApp-groep worden gemaakt",
  "Still free at your times?": "Nog steeds vrij op je tijden?",
  "A quick check every four weeks, so we only match you when you can come. Confirm your times in your profile, or add more to be matched sooner.":
    "Een korte check elke vier weken, zodat we je alleen indelen als je kunt. Bevestig je tijden in je profiel, of voeg er meer toe om sneller ingedeeld te worden.",
  // Pay first (20261040)
  "We’ve found people for your times": "We hebben mensen gevonden voor jouw tijden",
  "Pay your €39 within 7 days to confirm your place. We’ll tell you the dates and introduce your group as soon as it’s booked.":
    "Betaal binnen 7 dagen je €39 om je plek te bevestigen. Zodra je groep is geboekt, laten we je de data weten en stellen we je groep aan je voor.",
  "We’ve received your €39, so your place is confirmed. We’ll tell you the dates and introduce your group as soon as it’s booked.":
    "We hebben je €39 ontvangen, dus je plek is bevestigd. Zodra je groep is geboekt, laten we je de data weten en stellen we je groep aan je voor.",
  "Your €39 from before covers this one, so your place is confirmed. We’ll tell you the dates and introduce your group as soon as it’s booked.":
    "Je eerdere €39 geldt ook hiervoor, dus je plek is bevestigd. Zodra je groep is geboekt, laten we je de data weten en stellen we je groep aan je voor.",
  "Your seat is open again": "Je plek is weer vrij",
  "Your €39 has arrived": "Je €39 is binnen",
  "Your Circle is booked": "Je Circle is geboekt",
  "Your group needs a little longer": "Je groep heeft wat meer tijd nodig",
  "We’re still finding the last people for your group. Your place is safe, and we’ll let you know as soon as it’s booked.":
    "We zoeken nog de laatste mensen voor je groep. Je plek is veilig, en we laten het je weten zodra je groep is geboekt.",
  "A group is ready to start": "Een groep is klaar om te starten",
  "A group is waiting": "Een groep wacht",
  "A seat is open": "Er is een plek vrij",
  // Members
  "You’re invited to a Circle": "Je bent uitgenodigd voor een Circle",
  "Meet your group and see all six dates. Accept and pay by the date shown in the app to keep your place.":
    "Maak kennis met je groep en bekijk alle zes de data. Accepteer en betaal vóór de datum in de app om je plek te houden.",
  "You’re in! Your place is confirmed": "Je bent erbij! Je plek is bevestigd",
  "We’ve received your €39. Say hello to your Circle in the chat and look at the details of your first meetup.":
    "We hebben je €39 ontvangen. Zeg hallo tegen je Circle in de chat en bekijk de details van je eerste meetup.",
  "Your €39 from your previous Circle covers this one. Say hello to your new Circle in the chat.":
    "Je €39 van je vorige Circle geldt ook voor deze. Zeg hallo tegen je nieuwe Circle in de chat.",
  "See your Circle tomorrow": "Morgen zie je je Circle",
  "How was your meetup?": "Hoe was je meetup?",
  "Pick how it felt and, if you like, who you’d enjoy seeing more of. It stays private: only you and the organiser see it.":
    "Kies hoe het voelde en, als je wilt, wie je vaker wilt zien. Het blijft privé: alleen jij en de organisator zien het.",
  "Six weeks together: well done!": "Zes weken samen: goed gedaan!",
  "Your Circle and its chat stay open, so keep making plans together. Want to meet new people as well? You can join a new Circle in the app.":
    "Je Circle en de chat blijven open, dus blijf samen plannen maken. Wil je ook nieuwe mensen ontmoeten? Je kunt je in de app aanmelden voor een nieuwe Circle.",
  "How is your Circle doing?": "Hoe gaat het met je Circle?",
  "It’s been three months since your Circle started. Answer four quick questions about whether you’re still in touch. It helps us make better groups.":
    "Je Circle begon drie maanden geleden. Beantwoord vier korte vragen over of jullie nog contact hebben. Zo maken we betere groepen.",
  "Cancellation received": "Annulering ontvangen",
  "Your cancellation is with the organiser. We’ll be in touch about your €39.":
    "Je annulering ligt bij de organisator. We nemen contact met je op over je €39.",
  "Your Circle has been cancelled": "Je Circle gaat niet door",
  "We’re sorry, this Circle can’t go ahead. If you paid, your €39 will be returned. Reply to this email if you have any questions.":
    "Het spijt ons, deze Circle kan niet doorgaan. Heb je betaald, dan krijg je je €39 terug. Heb je vragen? Beantwoord dan deze e-mail.",
  "New messages in your Circle": "Nieuwe berichten in je Circle",
  "Your Circle plan changed": "Het plan van je Circle is gewijzigd",
  "Open your Circle to see the updated activity, place, and time.":
    "Open je Circle om de nieuwe activiteit, plek en tijd te zien.",
  "Extra plan cancelled": "Extra plan geannuleerd",
  "Your Circle has a plan update": "Er is een update voor een plan van je Circle",
  "Open the plan to see the latest details.": "Open het plan voor de nieuwste details.",
  "Your refund is complete": "Je terugbetaling is afgerond",
  "The organiser has confirmed that your €39 has been returned. Contact us if it has not arrived.":
    "De organisator heeft bevestigd dat je €39 is teruggestort. Neem contact op als het niet is aangekomen.",
  "We’ll refund your €39": "We betalen je €39 terug",
  "We couldn’t find a new group in time, so the organiser will return your €39.":
    "We konden niet op tijd een nieuwe groep vinden, dus de organisator stort je €39 terug.",
  "Your €39 has not arrived yet": "Je €39 is nog niet binnen",
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
  "Your €39 carries over to your next Circle. We’ll invite you when a group fits your times.":
    "Je €39 gaat mee naar je volgende Circle. We nodigen je uit zodra er een groep bij je tijden past.",
  "You’re moving to a new group": "Je gaat naar een nieuwe groep",
  "We’ll match you with a new Circle. Your €39 carries over, so you won’t pay again.":
    "We koppelen je aan een nieuwe Circle. Je €39 gaat mee, dus je betaalt niet opnieuw.",
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
  "A place is overdue": "Een plek is over tijd",
  "A member is switching groups": "Een lid stapt over naar een andere groep",
  "A member wants to move to another group": "Een lid wil naar een andere groep",
  "A member is missing meetups": "Een lid mist meetups",
  "A member left a Circle": "Een lid heeft een Circle verlaten",
  "Circles can be formed": "Er kunnen Circles worden gevormd",
  "A meetup has no place yet": "Een meetup heeft nog geen plek",
  "Enjoy your free week": "Geniet van je vrije week",
  "Things to do in VriendTime": "Te doen in VriendTime",
  "Week 5 is your call": "Week 5 is jullie keuze",
  "Week 5 has no plan yet": "Week 5 heeft nog geen plan",
  "A week to book": "Een week om te reserveren",
  "Your invitation is waiting": "Je uitnodiging wacht op je",
  "Last chance to say yes": "Laatste kans om ja te zeggen",
  "Your €39 payment has been received, so your place is confirmed. Open your Circle to meet the group and see the six weeks.":
    "Je betaling van €39 is ontvangen, dus je plek is bevestigd. Open je Circle om de groep te ontmoeten en de zes weken te bekijken.",
  "A booking email failed": "Een reserveringsmail is niet aangekomen",
  "No one-to-one for you this time. See you with the whole group!": "Deze keer geen één-op-ééntje voor jou. Tot ziens met de hele groep!",
  "No one-to-one coffee for you this time. See you with the whole group!": "Deze keer geen één-op-ééntje voor jou. Tot ziens met de hele groep!",
  "Week 5 is planned": "Week 5 is gepland",
  "Week 5 changed": "Week 5 is aangepast",
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
  "Hello, new faces": "Hoi, nieuwe gezichten",
  "The rematch": "De revanche",
  "Your call": "Jullie keuze",
  "Graduation: a new beginning": "Afstuderen: een nieuw begin",
  "Say cheese": "Zeg eens kaas",
  "Brunch together": "Samen brunchen",
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
  [/^(.+) has people who’d like a WhatsApp group\. Their numbers are on the Circles tab\.$/, (m) =>
    `${m[1]} heeft mensen die graag een WhatsApp-groep willen. Hun nummers staan op het tabblad Circles.`],
  [/^We didn’t receive your €39 for (.+) within 7 days, so your seat is now open for someone else\. You’re back on the waiting list, and we’ll invite you when a group fits your times\.$/, (m) =>
    `We hebben je €39 voor ${m[1]} niet binnen 7 dagen ontvangen, dus je plek is nu vrij voor iemand anders. Je staat weer op de wachtlijst, en we nodigen je uit zodra een groep bij je tijden past.`],
  [/^(.+) filled up before your payment arrived, so your €39 holds your place in the next group for your times\. We’ll invite you as soon as one fits\.$/, (m) =>
    `${m[1]} was vol voordat je betaling binnenkwam, dus je €39 houdt je plek vast in de volgende groep voor jouw tijden. We nodigen je uit zodra er een past.`],
  [/^Your first meetup is on (.+)\. Open the app to meet your group and see all six dates\.$/, (m) =>
    `Je eerste meetup is op ${when(m[1])}. Open de app om je groep te ontmoeten en alle zes de data te zien.`],
  [/^(.+) has (\d+) paid places\. Choose the first date on the Circles tab\.$/, (m) =>
    `${m[1]} heeft ${m[2]} betaalde plekken. Kies de eerste datum op het tabblad Circles.`],
  [/^(.+) has had paid members for two weeks\. Fill the last seats, or start with who you have\.$/, (m) =>
    `${m[1]} heeft al twee weken betaalde leden. Vul de laatste plekken, of start met wie er is.`],
  [/^(.+) didn’t pay for (.+) within 7 days\. Their seat is open: invite someone from the waiting list\.$/, (m) =>
    `${m[1]} heeft niet binnen 7 dagen betaald voor ${m[2]}. De plek is vrij: nodig iemand van de wachtlijst uit.`],
  [/^(.+ at \d{2}:\d{2}) · (.+)\. Running late\? Let them know in the app\.$/s, (m) =>
    `${when(m[1])} · ${place(m[2])}. Ben je later? Laat het weten in de app.`],
  [/^(\d{2}:\d{2}) at (.+)\. Running late\? Let them know in the app\.$/, (m) =>
    `${m[1]} bij ${m[2]}. Ben je later? Laat het weten in de app.`],
  [/^(.+) is running late$/, (m) => `${m[1]} is later`],
  [/^About (\d+) minutes\. Your coffee at (\d{2}:\d{2}) at (.+)\.$/, (m) =>
    `Ongeveer ${m[1]} minuten. Jullie koffie om ${m[2]} bij ${m[3]}.`],
  [/^Coffee with (.+) today$/, (m) => `Koffie met ${m[1]} vandaag`],
  [/^A drink with (.+) tonight$/, (m) => `Een drankje met ${m[1]} vanavond`],
  [/^(.+?) (planned|changed) week 5: (.+?)(?: at (.+))?, starting (\d{2}:\d{2})\.$/, (m) =>
    `${m[1]} heeft week 5 ${m[2] === "planned" ? "gepland" : "aangepast"}: ${m[3]}${m[4] ? ` bij ${m[4]}` : ""}, vanaf ${m[5]}.`],
  [/^(\d{2}:\d{2}) at (.+)\. Running late\? Say so in the group chat\.$/, (m) =>
    `${m[1]} bij ${m[2]}. Ben je later? Laat het weten in de groepschat.`],
  [/^(\d+) payments? to confirm$/, (m) => `${m[1]} ${m[1] === "1" ? "betaling" : "betalingen"} om te bevestigen`],
  [/^(\d+) refund requests? to review$/, (m) => `${m[1]} ${m[1] === "1" ? "terugbetalingsverzoek" : "terugbetalingsverzoeken"} om te bekijken`],
  [/^(\d+) open reports?$/, (m) => `${m[1]} open ${m[1] === "1" ? "melding" : "meldingen"}`],
  [/^This week you could meet (.+)$/, (m) => `Deze week kun je ${m[1]} ontmoeten`],
  [/^(.+) is busy, but (.+) is free$/, (m) => `${m[1]} kan niet, maar ${m[2]} is vrij`],
  [/^(.+ at \d{2}:\d{2}) · (.+)\. Coffee or a drink, just the two of you\. Can you make it\? Answer in the app\.$/s, (m) =>
    `${when(m[1])} · ${place(m[2])}. Koffie of een drankje, alleen jullie twee. Kun je? Antwoord in de app.`],
  [/^(.+ at \d{2}:\d{2}) · (.+)\. A drink in the evening, just as friends: whatever you like to drink\. Can you make it\? Answer in the app\. Not for you\? No reason needed\.$/s, (m) =>
    `${when(m[1])} · ${place(m[2])}. Een drankje in de avond, gewoon als vrienden: wat je maar wilt drinken. Kun je? Antwoord in de app. Liever niet? Uitleg is niet nodig.`],
  [/^You’re meeting (.+)$/, (m) => `Je spreekt af met ${m[1]}`],
  [/^(.+ at \d{2}:\d{2}) · (.+)\. Running late\? Say so in the group chat\.$/s, (m) =>
    `${when(m[1])} · ${place(m[2])}. Ben je later? Laat het weten in de groepschat.`],
  [/^(.+) would love to meet$/, (m) => `${m[1]} wil je graag ontmoeten`],
  [/^(.+) said yes to (.+)\. If your plans changed, you can still say yes in the app\.$/, (m) =>
    `${m[1]} zei ja tegen ${when(m[2])}. Als je plannen veranderd zijn, kun je in de app alsnog ja zeggen.`],
  [/^(.+) can’t make it after all$/, (m) => `${m[1]} kan toch niet`],
  // Older wording, still sent until 20261038 runs.
  [/^(.+ at \d{2}:\d{2}) · (.+)\. An evening coffee or drink, just as friends\. Can you make it\? Answer in the app\. Not for you\? No reason needed\.$/s, (m) =>
    `${when(m[1])} · ${place(m[2])}. Een drankje in de avond, gewoon als vrienden. Kun je? Antwoord in de app. Liever niet? Uitleg is niet nodig.`],
  [/^Your coffee on (.+) is off\. See you with the whole group!$/, (m) =>
    `Je één-op-ééntje op ${when(m[1])} gaat niet door. Tot ziens met de hele groep!`],
  [/^Your one-to-one on (.+) is off\. See you with the whole group!$/, (m) =>
    `Je één-op-ééntje op ${when(m[1])} gaat niet door. Tot ziens met de hele groep!`],
  [/^(.+) · week (\d) on (.+): add the place so members can see it the day before\.$/, (m) =>
    `${m[1]} · week ${m[2]} op ${m[3]}: voeg de plek toe zodat leden die de dag ervoor zien.`],
  [/^(.+) · week (\d) on (.+): add the place so members know where to go\.$/, (m) =>
    `${m[1]} · week ${m[2]} op ${when(m[3])}: voeg de plek toe zodat leden weten waar ze heen moeten.`],
  [/^Your plan for week (\d)$/, (m) => `Jullie plan voor week ${m[1]}`],
  [/^Week 5 of (.+) is on (.+)\. Choose together what to do, where, and a start between (\d{2}:\d{2}) and (\d{2}:\d{2})\. Talk it over in the chat, then save it in the app\.$/, (m) =>
    `Week 5 van ${m[1]} is op ${when(m[2])}. Kies samen wat jullie doen, waar, en een begintijd tussen ${m[3]} en ${m[4]}. Overleg in de chat en sla het op in de app.`],
  [/^(.+) · week 5 on (.+): the group hasn’t planned it\. Check the chat, or book something for them\.$/, (m) =>
    `${m[1]} · week 5 op ${when(m[2])}: de groep heeft nog niets gepland. Kijk in de chat, of boek iets voor ze.`],
  [/^Accept and pay for (.+) by the end of tomorrow to keep your place\.$/, (m) =>
    `Accepteer en betaal voor ${m[1]} vóór morgen aan het eind van de dag om je plek te houden.`],
  [/^Reply to your invitation to (.+) by the end of tomorrow to keep your place\. Your fee is already paid\.$/, (m) =>
    `Reageer vóór morgen aan het eind van de dag op je uitnodiging voor ${m[1]} om je plek te houden. Je bijdrage is al betaald.`],
  [/^Saying yes to (.+) closes at the end of tomorrow, so the places can be booked for the group\.$/, (m) =>
    `Ja zeggen tegen ${m[1]} kan tot morgen aan het eind van de dag, zodat de plekken voor de groep gereserveerd kunnen worden.`],
  [/^(.+) has not said yes to (.+) by the pay-by date\. Send a reminder, or release the place to invite someone else\.$/, (m) =>
    `${m[1]} heeft vóór de betaaldatum geen ja gezegd tegen ${m[2]}. Stuur een herinnering, of geef de plek vrij om iemand anders uit te nodigen.`],
  [/^(.+) · week (\d) on (.+?) at (.+): not booked yet\.$/, (m) =>
    `${m[1]} · week ${m[2]} op ${when(m[3])} bij ${m[4]}: nog niet gereserveerd.`],
  [/^(.+) · week (\d): the booking email to (.+) could not be sent\. Book it another way\.$/, (m) =>
    `${m[1]} · week ${m[2]}: de reserveringsmail aan ${m[3]} kon niet worden verstuurd. Reserveer op een andere manier.`],
  [/^Week (\d) of (.+) is planned as (.+?)(?: at (.+))?\. Want to do something else\? Change it together in the app\.$/, (m) =>
    `Week ${m[1]} van ${m[2]} staat gepland als ${weekTitles[m[3]] ?? m[3]}${m[4] ? ` bij ${m[4]}` : ""}. Liever iets anders? Pas het samen aan in de app.`],
  [/^Week (\d) needs a plan$/, (m) => `Week ${m[1]} heeft nog geen plan`],
  [/^Nobody has planned week (\d) of (.+) yet\. Pick an activity and a place together in the app\.$/, (m) =>
    `Nog niemand heeft week ${m[1]} van ${m[2]} gepland. Kies samen een activiteit en plek in de app.`],
  [/^(.+) · Open the app for the time and place\.$/, (m) =>
    `${weekTitles[m[1]] ?? m[1]} · Open de app voor de tijd en plek.`],
  [/^(\d+) new messages? in (.+)\. Open VriendTime to read and reply\.$/, (m) =>
    `${m[1]} ${m[1] === "1" ? "nieuw bericht" : "nieuwe berichten"} in ${m[2]}. Open VriendTime om te lezen en te antwoorden.`],
  [/^Your place in (.+) is confirmed once your €39 arrives\. Pay by the end of tomorrow to keep it\.$/, (m) =>
    `Je plek in ${m[1]} is bevestigd zodra je €39 binnen is. Betaal uiterlijk morgen om je plek te houden.`],
  [/^We did not receive your €39 for (.+) by your pay-by date, so your place has been released\. That is the only reason\. You are back on the waiting list, keeping your place in the queue, and we will invite you to another Circle\.$/, (m) =>
    `We hebben je €39 voor ${m[1]} niet vóór de betaaldatum ontvangen, dus je plek is vrijgegeven. Dat is de enige reden. Je staat weer op de wachtlijst, op je oude plek, en we nodigen je uit voor een andere Circle.`],
  [/^You’re no longer in (.+)$/, (m) => `Je zit niet meer in ${m[1]}`],
  [/^(.+) left (.+) and asked for their €39 back\. Open the organiser panel to review it\.$/, (m) =>
    `${m[1]} heeft ${m[2]} verlaten en vraagt de €39 terug. Open het organisatorpaneel om het te bekijken.`],
  [/^(.+) is no longer joining (.+)\. Invite someone from the Circles tab\.$/, (m) =>
    `${m[1]} doet niet meer mee aan ${m[2]}. Nodig iemand uit via het tabblad Circles.`],
  [/^(.+) has not paid for (.+) by the pay-by date\. Check Tikkie, then confirm the payment or release the place\.$/, (m) =>
    `${m[1]} heeft niet op tijd betaald voor ${m[2]}. Controleer Tikkie en bevestig de betaling of geef de plek vrij.`],
  [/^(.+) left (.+) and keeps their €39 for a new group\. Reason: (.*)$/s, (m) =>
    `${m[1]} heeft ${m[2]} verlaten en houdt de €39 voor een nieuwe groep. Reden: ${m[3]}`],
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
    profile: ["Check your times", "Bekijk je tijden"],
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
