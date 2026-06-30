import 'package:flutter/foundation.dart';

import '../models/journal_model.dart';
import '../repositories/journal_repository.dart';

class JournalProvider extends ChangeNotifier {
  JournalProvider(this._repository);

  final JournalRepository _repository;

  List<JournalModel> _journals = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<JournalModel> get journals => List.unmodifiable(_journals);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadRecentJournals(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _journals = await _repository.fetchRecentJournals(userId);
    } catch (_) {
      _errorMessage = 'Unable to load journals.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createJournal({
    required String userId,
    required String content,
    int? moodLevel,
    List<String> tags = const [],
  }) async {
    try {
      final id = await _repository.createJournal(
        userId: userId,
        content: content,
        moodLevel: moodLevel,
        tags: tags,
      );
      _journals = [
        JournalModel(
          id: id,
          userId: userId,
          content: content,
          moodLevel: moodLevel,
          tags: tags,
          createdAt: DateTime.now(),
        ),
        ..._journals,
      ];
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Unable to save journal.';
      notifyListeners();
      return false;
    }
  }
}
