import '../core/utils/firestore_mapper.dart';

enum JournalMode {
  freeWrite,
  understandFeelings,
  letItOut,
  findSomethingGood,
  sortOutThoughts,
  reflectOnDay;

  String get label => switch (this) {
    freeWrite => 'Write Freely',
    understandFeelings => 'Understand My Feelings',
    letItOut => 'Let It Out',
    findSomethingGood => 'Find Something Good',
    sortOutThoughts => 'Sort Out My Thoughts',
    reflectOnDay => 'Reflect on My Day',
  };

  static JournalMode fromValue(Object? value) => values.firstWhere(
    (mode) => mode.name == value?.toString(),
    orElse: () => JournalMode.freeWrite,
  );
}

enum JournalFeelingAfter { better, same, harder, skipped }

class JournalPromptResponse {
  const JournalPromptResponse({required this.promptId, required this.response});
  final String promptId;
  final String response;

  factory JournalPromptResponse.fromJson(Map<String, dynamic> json) =>
      JournalPromptResponse(
        promptId: json['promptId']?.toString() ?? '',
        response: json['response']?.toString() ?? '',
      );
  Map<String, dynamic> toJson() => {'promptId': promptId, 'response': response};
}

class JournalModel {
  const JournalModel({
    required this.id,
    required this.content,
    required this.createdAt,
    this.userId,
    this.mode = JournalMode.freeWrite,
    this.title,
    this.moodLevel,
    this.moodLabel,
    this.feelingAfter = JournalFeelingAfter.skipped,
    this.category,
    this.tags = const [],
    this.promptIds = const [],
    this.responses = const [],
    this.isFavorite = false,
    this.isArchived = false,
    this.updatedAt,
  });

  final String id;
  final String content;
  final DateTime createdAt;
  final String? userId;
  final JournalMode mode;
  final String? title;
  final int? moodLevel;
  final String? moodLabel;
  final JournalFeelingAfter feelingAfter;
  final String? category;
  final List<String> tags;
  final List<String> promptIds;
  final List<JournalPromptResponse> responses;
  final bool isFavorite;
  final bool isArchived;
  final DateTime? updatedAt;

  factory JournalModel.fromJson(Map<String, dynamic> json, {String? id}) {
    final mood = json['moodBefore'];
    final after = json['feelingAfter'];
    return JournalModel(
      id: (json['id'] ?? id ?? '').toString(),
      userId: json['userId']?.toString(),
      mode: JournalMode.fromValue(json['mode']),
      title: _optional(json['title']),
      content: (json['content'] ?? '').toString(),
      moodLevel: mood is Map
          ? _optionalInt(mood['level'])
          : _optionalInt(json['moodLevel']),
      moodLabel: mood is Map ? _optional(mood['label']) : null,
      feelingAfter: JournalFeelingAfter.values.firstWhere(
        (value) =>
            value.name == (after is Map ? after['state'] : after)?.toString(),
        orElse: () => JournalFeelingAfter.skipped,
      ),
      category: _optional(json['category']),
      tags: _strings(json['tags'], limit: 5),
      promptIds: _strings(json['promptIds']),
      responses: (json['responses'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                JournalPromptResponse.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      isFavorite: json['isFavorite'] == true,
      isArchived: json['isArchived'] == true,
      createdAt: dateTimeFromFirestoreOrNow(json['createdAt']),
      updatedAt: dateTimeFromFirestore(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson({String? userId}) => {
    'userId': userId ?? this.userId,
    'mode': mode.name,
    'entryType': mode == JournalMode.freeWrite ? 'free' : 'guided',
    'title': title,
    'content': content.trim(),
    'moodLevel': moodLevel,
    'moodBefore': moodLevel == null && moodLabel == null
        ? null
        : {'level': moodLevel, 'label': moodLabel},
    'feelingAfter': {'state': feelingAfter.name},
    'category': category,
    'tags': tags.take(5).toList(),
    'promptIds': promptIds,
    'responses': responses.map((item) => item.toJson()).toList(),
    'isFavorite': isFavorite,
    'isArchived': isArchived,
    'safety': {'classification': 'not_screened', 'interventionShown': false},
    'sharing': {'sharedWithCounselor': false, 'sharedAt': null},
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  JournalModel copyWith({
    String? id,
    String? userId,
    JournalMode? mode,
    String? title,
    String? content,
    int? moodLevel,
    String? moodLabel,
    JournalFeelingAfter? feelingAfter,
    String? category,
    List<String>? tags,
    List<String>? promptIds,
    List<JournalPromptResponse>? responses,
    bool? isFavorite,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => JournalModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    mode: mode ?? this.mode,
    title: title ?? this.title,
    content: content ?? this.content,
    moodLevel: moodLevel ?? this.moodLevel,
    moodLabel: moodLabel ?? this.moodLabel,
    feelingAfter: feelingAfter ?? this.feelingAfter,
    category: category ?? this.category,
    tags: tags ?? this.tags,
    promptIds: promptIds ?? this.promptIds,
    responses: responses ?? this.responses,
    isFavorite: isFavorite ?? this.isFavorite,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  static String? _optional(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static int? _optionalInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  static List<String> _strings(Object? value, {int? limit}) {
    final items = value is List
        ? value
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
        : const Iterable<String>.empty();
    return (limit == null ? items : items.take(limit)).toList(growable: false);
  }
}
