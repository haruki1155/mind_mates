import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../models/mind_aid_suggestion_model.dart';
import '../domain/mind_aid_dataset_models.dart';

class MindAidDatasetLoader {
  MindAidDatasetLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const intentsPath = 'assets/data/mind_aid/intents.json';
  static const crisisPath = 'assets/data/mind_aid/crisis_triggers.json';
  static const suggestionsPath = 'assets/data/mind_aid/quick_suggestions.json';
  static const copingPath = 'assets/data/mind_aid/coping_exercises.json';
  static const resourcesPath = 'assets/data/mind_aid/resource_mappings.json';

  final AssetBundle _bundle;
  MindAidDatasetBundle? _cache;

  Future<MindAidDatasetBundle> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final bundle = MindAidDatasetBundle(
      records: await _loadRecords(intentsPath),
      crisisRecords: await _loadRecords(crisisPath),
      suggestions: await _loadSuggestions(suggestionsPath),
      copingExercises: await _loadCoping(copingPath),
      resources: await _loadResources(resourcesPath),
    );

    _validate(bundle);
    _cache = bundle;
    return bundle;
  }

  Future<List<MindAidDatasetRecord>> _loadRecords(String path) async {
    final records = await _loadRecordMaps(path);
    return records.map(MindAidDatasetRecord.fromMap).toList(growable: false);
  }

  Future<List<MindAidSuggestionModel>> _loadSuggestions(String path) async {
    final records = await _loadRecordMaps(path);
    return records.map(MindAidSuggestionModel.fromMap).toList(growable: false);
  }

  Future<List<MindAidCopingExercise>> _loadCoping(String path) async {
    final records = await _loadRecordMaps(path);
    return records.map(MindAidCopingExercise.fromMap).toList(growable: false);
  }

  Future<List<MindAidResource>> _loadResources(String path) async {
    final records = await _loadRecordMaps(path);
    return records.map(MindAidResource.fromMap).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _loadRecordMaps(String path) async {
    final raw = await _bundle.loadString(path);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> || decoded['records'] is! List) {
      throw FormatException('MindAid dataset file "$path" is invalid.');
    }

    return (decoded['records'] as List)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  void _validate(MindAidDatasetBundle bundle) {
    if (bundle.records.isEmpty) {
      throw const FormatException('MindAid intent dataset is empty.');
    }
    if (bundle.crisisRecords.isEmpty) {
      throw const FormatException('MindAid crisis dataset is empty.');
    }
    for (final record in bundle.allRecords) {
      if (record.responses.isEmpty) {
        throw FormatException(
          'MindAid record "${record.id}" needs at least one response.',
        );
      }
      if (record.keywords.isEmpty && record.phrases.isEmpty) {
        throw FormatException(
          'MindAid record "${record.id}" needs keywords or phrases.',
        );
      }
    }
  }
}
