/// Utilities for deriving display initials from a user's full name.
///
/// Examples:
///   "Vikas" -> "V"
///   "Vikas Nachireddy" -> "VN"
///   "  vikas   reddy  kumar " -> "VR" (first two words)
class AvatarUtils {
  /// Returns up to [maxLetters] initials, one per word, uppercased.
  /// Falls back to '?' when [fullName] is null/empty/whitespace-only.
  static String initialsFor(String? fullName, {int maxLetters = 2}) {
    if (fullName == null) return '?';
    final words = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    final letters = words
        .take(maxLetters)
        .map((w) => w[0].toUpperCase())
        .join();
    return letters.isEmpty ? '?' : letters;
  }
}
