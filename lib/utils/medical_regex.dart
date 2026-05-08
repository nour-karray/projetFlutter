class MedicalRegex {
  static final RegExp number = RegExp(r'(?<!\d)(\d{1,4}(?:[.,]\d+)?)(?!\d)');
  static final RegExp range = RegExp(
    r'(\d{1,3}(?:[.,]\d+)?)\s*(?:-|a|à)\s*(\d{1,3}(?:[.,]\d+)?)',
    caseSensitive: false,
  );
  static final RegExp lowerThan = RegExp(
    r'(?:<|inferieur\s*a)\s*(\d+(?:[.,]\d+)?)',
    caseSensitive: false,
  );
  static final RegExp greaterThan = RegExp(
    r'(?:>|superieur\s*a)\s*(\d+(?:[.,]\d+)?)',
    caseSensitive: false,
  );
  static final RegExp date = RegExp(r'\b\d{2}[/-]\d{2}[/-]\d{2,4}\b');
  static final RegExp pageNumber = RegExp(
    r'page\s*[:#]?\s*(\d+)',
    caseSensitive: false,
  );
  static final RegExp dossier = RegExp(
    r'dossier\s*(?:n|no|n°|numero)?\s*[:#]?\s*([a-z0-9\-/.]+)',
    caseSensitive: false,
  );
  static final RegExp codePatient = RegExp(
    r'code\s*patient\s*[:#]?\s*([a-z0-9\-/.]+)',
    caseSensitive: false,
  );
  static final RegExp examNumber = RegExp(
    r'examen\s*(?:n|no|n°|numero)?\s*[:#]?\s*([a-z0-9\-/.]+)',
    caseSensitive: false,
  );
  static final RegExp unit = RegExp(
    r'\b(g/l|mg/l|mmol/l|umol/l|ui/l|mui/l|ug/l|ng/ml|pg/ml|%|g/dl|mg/dl|mui/ml|iu/l|fl|fL|giga/l|10\^?\d+/l|/mm3)\b',
    caseSensitive: false,
  );
}
