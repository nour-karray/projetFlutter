class MedicalOcrPostprocessor {
  static String normalize(String input) {
    if (input.trim().isEmpty) return input;

    var text = input
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    final replacements = <Pattern, String>{
      RegExp(r'\bCHOLESTER0L\b', caseSensitive: false): 'CHOLESTEROL',
      RegExp(r'\bTRIGLYCER1DES\b', caseSensitive: false): 'TRIGLYCERIDES',
      RegExp(r'\bV1TAMINE\b', caseSensitive: false): 'VITAMINE',
      RegExp(r'\bTHYRE0STIMULINE\b', caseSensitive: false): 'THYREOSTIMULINE',
      RegExp(r'\bRESULIAT\b', caseSensitive: false): 'RESULTAT',
      RegExp(r'\bmuI/l\b', caseSensitive: false): 'mUI/l',
      RegExp(r'(\d)\s*,\s*(\d)'): r'$1.$2',
    };

    replacements.forEach((pattern, replacement) {
      text = text.replaceAll(pattern, replacement);
    });

    return text;
  }

  static String normalizeForAi(String input) {
    if (input.trim().isEmpty) return input;

    var text = normalize(input);
    text = text
        .replaceAll(RegExp(r'[|¦]'), ' ')
        .replaceAll(RegExp(r'[•·]'), ' ')
        .replaceAll(RegExp(r'(?<=\d)\s*[oO](?=\s*(?:/|l|L|I)\b)'), '0')
        .replaceAll(RegExp(r'(?<=\d)\s*[oO](?=\b)'), '0')
        .replaceAll(RegExp(r'(?<=\d)\s*[lI](?=\b)'), '1')
        .replaceAll(RegExp(r'\bmg\s*dl\b', caseSensitive: false), 'mg/dL')
        .replaceAll(RegExp(r'\bmmol\s*l\b', caseSensitive: false), 'mmol/L')
        .replaceAll(RegExp(r'\bui\s*l\b', caseSensitive: false), 'UI/L')
        .replaceAll(RegExp(r'\bmui\s*l\b', caseSensitive: false), 'mUI/L')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) => line.length >= 2)
        .toList(growable: false);

    return lines.join('\n');
  }
}
