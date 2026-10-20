import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/widgets/low_handles.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/internet.dart';
import 'package:the_app/providers/weather_provider.dart';

/// Finding a place for the weather (Round 70): its name typed, then one
/// picked from the matches (name, region, country), since many towns
/// share a name. Resolves to the place picked, or null.
Future<WeatherPlace?> showPlaceSearchSheet(BuildContext context) =>
    showModalBottomSheet<WeatherPlace>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PlaceSearchSheet(),
    );

class _PlaceSearchSheet extends ConsumerStatefulWidget {
  const _PlaceSearchSheet();

  @override
  ConsumerState<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends ConsumerState<_PlaceSearchSheet> {
  final _name = TextEditingController();
  bool _busy = false;

  /// The last search's places; null before one.
  List<WeatherPlace>? _found;
  String? _failed;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final name = _name.text.trim();
    if (name.length < 2 || _busy) return;
    setState(() {
      _busy = true;
      _failed = null;
    });
    try {
      final found = await ref.read(weatherApiProvider).search(name);
      if (!mounted) return;
      setState(() => _found = found);
    } on WeatherFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _found = null;
        _failed = e.message;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final found = _found;
    final height = MediaQuery.sizeOf(context).height;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                // A few places to pick from, above the field: already at
                // the bottom, by the thumb.
                child: SingleChildScrollView(
                  reverse: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (found != null && found.isEmpty)
                        Padding(
                          key: const Key('placeNotFound'),
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No place found. Check the spelling, or try a '
                            'bigger town nearby.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        ),
                      if (_failed case final failed?)
                        Padding(
                          key: const Key('placeSearchFailed'),
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            '$failed. Check the connection and try again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.danger),
                          ),
                        ),
                      for (final place in found ?? const <WeatherPlace>[])
                        ListTile(
                          key: Key('place-${place.id}'),
                          leading: const Icon(Icons.place_outlined),
                          title: Text(place.name),
                          subtitle: place.where.isEmpty
                              ? null
                              : Text(
                                  place.where,
                                  style: TextStyle(color: colors.textSecondary),
                                ),
                          onTap: () => Navigator.of(context).pop(place),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        selectionControls: lowHandles,
                        key: const Key('placeSearchField'),
                        controller: _name,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'Town or city',
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    _busy
                        ? const SizedBox(
                            width: 48,
                            height: 48,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            key: const Key('placeSearch'),
                            tooltip: 'Search',
                            onPressed: _search,
                            icon: const Icon(Icons.search),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
