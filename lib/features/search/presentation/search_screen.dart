import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/features/search/presentation/bloc/combined_search/combined_search_bloc.dart';
import 'package:kakan/features/search/presentation/bloc/combined_search/combined_search_event.dart';
import 'package:kakan/features/search/presentation/theme/search_theme.dart';
import 'package:kakan/features/search/presentation/widgets/people_list_search_screen.dart';
import 'package:kakan/features/search/presentation/widgets/songs_list_search_screen.dart';
import 'package:kakan/features/search/presentation/widgets/videos_search_screen.dart';
import 'package:kakan/features/followsuggestions/presentation/bloc/suggestion_bloc.dart';
import 'package:kakan/features/followsuggestions/presentation/bloc/suggestion_event.dart';
import 'package:kakan/injection_container.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<CombinedSearchBloc>()),
        BlocProvider(
          create: (_) => sl<SuggestionBloc>()..add(FetchSuggestionsEvent()),
        ),
      ],
      child: Scaffold(
        backgroundColor: SearchTheme.surfaceBg,
        appBar: AppBar(
          backgroundColor: SearchTheme.cardBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: SearchTheme.textPrimary,
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Search',
            style: SearchTheme.titleAppBar.copyWith(fontSize: 20),
          ),
          centerTitle: false,
        ),
        body: const TabsSearchScreen(),
      ),
    );
  }
}

class TabsSearchScreen extends StatefulWidget {
  const TabsSearchScreen({super.key});

  @override
  State<TabsSearchScreen> createState() => _TabsSearchScreenState();
}

class _TabsSearchScreenState extends State<TabsSearchScreen> {
  late TextEditingController _controller;
  late CombinedSearchBloc _searchBloc;
  int _currentIndex = 0;

  static const List<_Segment> _segments = [
    _Segment(icon: Icons.person_outline_rounded, label: 'People'),
    _Segment(icon: Icons.videocam_outlined, label: 'Videos'),
    _Segment(icon: Icons.music_note_rounded, label: 'Songs'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _searchBloc = context.read<CombinedSearchBloc>();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _searchBloc.add(SearchAllEvent(q));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    switch (_currentIndex) {
      case 0:
        content = const PeopleListSearchScreen();
        break;
      case 1:
        content = const VideosSearchScreen();
        break;
      default:
        content = const SongsListSearchScreen();
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SearchTheme.spacingLg,
            SearchTheme.spacingMd,
            SearchTheme.spacingLg,
            SearchTheme.spacingSm,
          ),
          child: TextField(
            controller: _controller,
            onChanged: _onSearchChanged,
            style: SearchTheme.titleCard.copyWith(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search people, videos, songs…',
              hintStyle: SearchTheme.subtitle.copyWith(color: SearchTheme.textMuted),
              filled: true,
              fillColor: SearchTheme.searchBarFill,
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 22,
                color: SearchTheme.textMuted,
              ),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close_rounded, size: 20, color: SearchTheme.textMuted),
                      onPressed: () {
                        _controller.clear();
                        _onSearchChanged('');
                      },
                    ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: SearchTheme.spacingLg,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SearchTheme.radiusXl),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SearchTheme.radiusXl),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SearchTheme.radiusXl),
                borderSide: const BorderSide(color: SearchTheme.primary, width: 1.5),
              ),
            ),
          ),
        ),

        // Segment chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SearchTheme.spacingLg),
          child: Row(
            children: List.generate(_segments.length, (i) {
              final seg = _segments[i];
              final selected = i == _currentIndex;
              return Padding(
                padding: EdgeInsets.only(right: i < _segments.length - 1 ? SearchTheme.spacingSm : 0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _currentIndex = i),
                    borderRadius: BorderRadius.circular(SearchTheme.radiusFull),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SearchTheme.spacingMd,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? SearchTheme.chipSelectedBg : SearchTheme.chipUnselectedBg,
                        borderRadius: BorderRadius.circular(SearchTheme.radiusFull),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: SearchTheme.primary.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            seg.icon,
                            size: 18,
                            color: selected ? Colors.white : SearchTheme.chipUnselectedText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            seg.label,
                            style: selected ? SearchTheme.labelChip : SearchTheme.labelChipUnselected,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: SearchTheme.spacingMd),

        Expanded(child: content),
      ],
    );
  }
}

class _Segment {
  final IconData icon;
  final String label;
  const _Segment({required this.icon, required this.label});
}
