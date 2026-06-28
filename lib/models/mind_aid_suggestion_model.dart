class MindAidSuggestionModel {
  final String id;
  final String label;
  final String? iconAsset;

  MindAidSuggestionModel({
    required this.id,
    required this.label,
    this.iconAsset,
  });

  factory MindAidSuggestionModel.fromMap(Map<String, dynamic> map) {
    return MindAidSuggestionModel(
      id: map['id'],
      label: map['label'],
      iconAsset: (map['iconAsset'] as String?)?.trim().isEmpty ?? true
          ? null
          : (map['iconAsset'] as String).trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'label': label, 'iconAsset': iconAsset};
  }
}
