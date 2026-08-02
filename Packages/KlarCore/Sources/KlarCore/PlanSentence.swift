import Foundation

/// Users type situation and action as standalone phrases ("Auf einer Party"), but the app shows
/// them inside one sentence: "Wenn …, dann …". Dropped in verbatim they leave capital letters
/// mid-sentence.
public enum PlanSentence {
    /// The phrase as it should read inside a "Wenn …, dann …" sentence.
    ///
    /// Lowercases the first letter only when the rest of the first word is lowercase — so a
    /// deliberately capitalised first word survives ("AA-Meeting", "U-Bahn", "McDonalds"), as do
    /// single-letter words ("S Bahn"). Everything after the first word stays verbatim, which keeps
    /// German nouns capitalised.
    public static func fragment(_ text: String) -> String {
        guard let first = text.first, first.isUppercase else { return text }

        let rest = text.dropFirst().prefix { !$0.isWhitespace }
        guard !rest.isEmpty, !rest.contains(where: { $0.isUppercase }) else { return text }

        return first.lowercased() + text.dropFirst()
    }
}
