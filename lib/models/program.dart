class Program {
  final String id;
  final String stationId;
  final String title;
  final String hostName;
  final String hostAvatarUrl;
  final String category;
  final String startTime; // e.g. "08:00"
  final String endTime;   // e.g. "10:00"
  final bool isLiveNow;

  Program({
    required this.id,
    required this.stationId,
    required this.title,
    required this.hostName,
    required this.hostAvatarUrl,
    required this.category,
    required this.startTime,
    required this.endTime,
    this.isLiveNow = false,
  });

  factory Program.fromJson(Map<String, dynamic> json) {
    return Program(
      id: json['id'] ?? '',
      stationId: json['stationId'] ?? '',
      title: json['title'] ?? 'Programa sin título',
      hostName: json['hostName'] ?? 'Locutor',
      hostAvatarUrl: json['hostAvatarUrl'] ?? '',
      category: json['category'] ?? 'General',
      startTime: json['startTime'] ?? '00:00',
      endTime: json['endTime'] ?? '01:00',
      isLiveNow: json['isLiveNow'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'stationId': stationId,
        'title': title,
        'hostName': hostName,
        'hostAvatarUrl': hostAvatarUrl,
        'category': category,
        'startTime': startTime,
        'endTime': endTime,
        'isLiveNow': isLiveNow,
      };
}
