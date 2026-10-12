/// Placard (O4): a big line of text, held up sideways, with a count of
/// how many times it was shown. The user sets both (five taps in the
/// corner); a fresh one says [defaultText] with a count of 1.
class Placard {
  static const defaultText = 'Add text here!';
  static const defaultCount = 1;

  final String text;
  final int count;

  const Placard({this.text = defaultText, this.count = defaultCount});

  static const initial = Placard();

  /// Whether anything was changed from a fresh one.
  bool get isSet => text != defaultText || count != defaultCount;

  Placard copyWith({String? text, int? count}) =>
      Placard(text: text ?? this.text, count: count ?? this.count);

  Map<String, dynamic> toJson() => {'text': text, 'count': count};

  factory Placard.fromJson(Map<String, dynamic> json) => Placard(
        text: json['text'] as String? ?? defaultText,
        count: (json['count'] as num?)?.toInt() ?? defaultCount,
      );
}
