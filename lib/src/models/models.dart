class EventSummary {
  const EventSummary({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.locality,
    required this.activity,
    required this.spotsFilled,
    required this.spotsTotal,
  });

  final String title;
  final String subtitle;
  final String time;
  final String locality;
  final String activity;
  final int spotsFilled;
  final int spotsTotal;
}

class FriendPreview {
  const FriendPreview({
    required this.name,
    required this.note,
    required this.lastSeen,
    required this.color,
  });

  final String name;
  final String note;
  final String lastSeen;
  final int color;
}
