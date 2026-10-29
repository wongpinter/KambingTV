class EpgProgramme {
  const EpgProgramme({
    required this.channelId,
    required this.title,
    required this.start,
    required this.stop,
    this.description,
  });

  final String channelId;
  final String title;
  final DateTime start;
  final DateTime stop;
  final String? description;

  factory EpgProgramme.fromMap(Map<String, Object?> map) {
    return EpgProgramme(
      channelId: map['channelId']! as String,
      title: map['title']! as String,
      start: DateTime.fromMillisecondsSinceEpoch(
        map['start']! as int,
        isUtc: true,
      ),
      stop: DateTime.fromMillisecondsSinceEpoch(
        map['stop']! as int,
        isUtc: true,
      ),
      description: map['description'] as String?,
    );
  }
}
