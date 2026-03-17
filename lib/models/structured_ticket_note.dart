class StructuredTicketNoteSection {
  const StructuredTicketNoteSection({
    required this.key,
    required this.label,
    required this.value,
  });

  final String key;
  final String label;
  final String value;
}

class StructuredTicketNote {
  const StructuredTicketNote({
    this.diagnosis,
    this.workPerformed,
    this.usedParts,
    this.result,
    this.additionalNote,
    this.generalNote,
  });

  static const String diagnosisKey = 'diagnosis';
  static const String workPerformedKey = 'work_performed';
  static const String usedPartsKey = 'used_parts';
  static const String resultKey = 'result';
  static const String additionalNoteKey = 'additional_note';

  static const Map<String, List<String>> _headers = {
    diagnosisKey: ['Ariza Tespiti', 'Arıza Tespiti'],
    workPerformedKey: ['Yapilan Islem', 'Yapılan İşlem'],
    usedPartsKey: ['Kullanilan Parca', 'Kullanılan Parça'],
    resultKey: ['Sonuc', 'Sonuç'],
    additionalNoteKey: ['Ek Not'],
  };

  final String? diagnosis;
  final String? workPerformed;
  final String? usedParts;
  final String? result;
  final String? additionalNote;
  final String? generalNote;

  bool get hasStructuredContent =>
      _normalize(diagnosis).isNotEmpty ||
      _normalize(workPerformed).isNotEmpty ||
      _normalize(usedParts).isNotEmpty ||
      _normalize(result).isNotEmpty ||
      _normalize(additionalNote).isNotEmpty;

  bool get hasAnyContent =>
      hasStructuredContent || _normalize(generalNote).isNotEmpty;

  String get summary {
    final candidates = [
      result,
      workPerformed,
      diagnosis,
      additionalNote,
      generalNote,
    ];
    for (final candidate in candidates) {
      final normalized = _normalize(candidate);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return 'Guncelleme eklendi.';
  }

  List<StructuredTicketNoteSection> get sections {
    final items = <StructuredTicketNoteSection>[];
    void addSection(String key, String label, String? value) {
      final normalized = _normalize(value);
      if (normalized.isEmpty) return;
      items.add(
        StructuredTicketNoteSection(key: key, label: label, value: normalized),
      );
    }

    addSection(diagnosisKey, 'Ariza Tespiti', diagnosis);
    addSection(workPerformedKey, 'Yapilan Islem', workPerformed);
    addSection(usedPartsKey, 'Kullanilan Parca', usedParts);
    addSection(resultKey, 'Sonuc', result);
    addSection(additionalNoteKey, 'Ek Not', additionalNote);
    if (items.isEmpty) {
      addSection('general', 'Not', generalNote);
    }
    return items;
  }

  String toStorageText() {
    if (!hasStructuredContent) {
      return _normalize(generalNote);
    }

    final blocks = <String>[];
    for (final section in sections) {
      if (section.key == 'general') continue;
      blocks.add('${section.label}:\n${section.value}');
    }
    return blocks.join('\n\n').trim();
  }

  factory StructuredTicketNote.fromRaw(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return const StructuredTicketNote();
    }

    final buffers = <String, List<String>>{};
    final general = <String>[];
    String? currentKey;

    for (final line in normalized.split('\n')) {
      final trimmed = line.trimRight();
      final matched = _matchHeader(trimmed);
      if (matched != null) {
        currentKey = matched.$1;
        final inlineValue = matched.$2;
        if (inlineValue.isNotEmpty) {
          buffers.putIfAbsent(currentKey, () => []).add(inlineValue);
        } else {
          buffers.putIfAbsent(currentKey, () => []);
        }
        continue;
      }

      if (currentKey == null) {
        general.add(trimmed);
      } else {
        buffers.putIfAbsent(currentKey, () => []).add(trimmed);
      }
    }

    final diagnosis = _join(buffers[diagnosisKey]);
    final workPerformed = _join(buffers[workPerformedKey]);
    final usedParts = _join(buffers[usedPartsKey]);
    final result = _join(buffers[resultKey]);
    final additionalNote = _join(buffers[additionalNoteKey]);
    final generalNote = _join(general);

    if ([
      diagnosis,
      workPerformed,
      usedParts,
      result,
      additionalNote,
    ].every((item) => _normalize(item).isEmpty)) {
      return StructuredTicketNote(generalNote: normalized);
    }

    return StructuredTicketNote(
      diagnosis: diagnosis,
      workPerformed: workPerformed,
      usedParts: usedParts,
      result: result,
      additionalNote: additionalNote,
      generalNote: generalNote,
    );
  }

  static (String, String)? _matchHeader(String line) {
    for (final entry in _headers.entries) {
      for (final label in entry.value) {
        if (line == '$label:') {
          return (entry.key, '');
        }

        final prefix = '$label:';
        if (line.startsWith(prefix)) {
          return (entry.key, line.substring(prefix.length).trim());
        }
      }
    }
    return null;
  }

  static String _join(List<String>? lines) {
    if (lines == null || lines.isEmpty) return '';
    return lines.join('\n').trim();
  }

  static String _normalize(String? value) {
    return value?.trim() ?? '';
  }
}
