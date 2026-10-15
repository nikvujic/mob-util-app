import 'package:flutter_riverpod/flutter_riverpod.dart';

/// When a recipe was last looked at, open for [recipeReadAfter] or more
/// (Round 53): Pip eats the next time he's seen within the hour
/// (`PipBrain.eatsWithin`).
/// Kept in memory only.
final recipeReadProvider = StateProvider<DateTime?>((ref) => null);

/// How long a recipe is open before it counts as read.
const recipeReadAfter = Duration(minutes: 5);
