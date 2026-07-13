import 'package:flutter/foundation.dart';

import '../models/journal_model.dart';
import '../repositories/journal_repository.dart';

class JournalProvider extends ChangeNotifier {
  JournalProvider(this._repository);

  final JournalRepository _repository;

  List<JournalModel> _journals = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  List<JournalModel> get journals => List.unmodifiable(_journals);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
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

  Future<bool> saveEntry(JournalModel entry) async {
    if (_isSaving) return false;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (entry.id.isEmpty) {
        final id = await _repository.createEntry(entry);
        _journals = [
          entry.copyWith(
            id: id,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          ..._journals,
        ];
      } else {
        await _repository.updateEntry(entry);
        _journals = [
          for (final item in _journals)
            if (item.id == entry.id)
              entry.copyWith(updatedAt: DateTime.now())
            else
              item,
        ];
      }
      return true;
    } catch (_) {
      _errorMessage = 'Unable to save journal.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteEntry(String id) async {
    if (_isSaving) return false;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.deleteJournal(id);
      _journals = _journals.where((item) => item.id != id).toList();
      return true;
    } catch (_) {
      _errorMessage = 'Unable to delete journal.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> toggleFavorite(JournalModel entry) {
    return saveEntry(entry.copyWith(isFavorite: !entry.isFavorite));
  }
}
