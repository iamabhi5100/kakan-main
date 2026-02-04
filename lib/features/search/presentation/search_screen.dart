import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/injection_container.dart';
import 'package:kakan/features/search/presentation/bloc/combined_search/combined_search_bloc.dart';
import 'package:kakan/features/search/presentation/bloc/combined_search/combined_search_event.dart';
import 'package:kakan/features/search/presentation/widgets/people_list_search_screen.dart';
import 'package:kakan/features/search/presentation/widgets/songs_list_search_screen.dart';
import 'package:kakan/features/search/presentation/widgets/videos_search_screen.dart';
import 'package:kakan/features/followsuggestions/presentation/bloc/suggestion_bloc.dart';
import 'package:kakan/features/followsuggestions/presentation/bloc/suggestion_event.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // unified search
        BlocProvider(
          create: (_) => sl<CombinedSearchBloc>(),
        ),
        // follow suggestions
        BlocProvider(
          create: (_) =>
              sl<SuggestionBloc>()..add(FetchSuggestionsEvent()),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: const BackButton(color: Colors.black),
          title: const Text('Search', style: TextStyle(color: Colors.black)),
        ),
        body: const TabsSearchScreen(),
      ),
    );
  }
}

class TabsSearchScreen extends StatefulWidget {
  const TabsSearchScreen({Key? key}) : super(key: key);

  @override
  State<TabsSearchScreen> createState() => _TabsSearchScreenState();
}

class _TabsSearchScreenState extends State<TabsSearchScreen> {
  late TextEditingController _controller;
  late CombinedSearchBloc _searchBloc;
  int _currentIndex = 0;

  final List<_Segment> _segments = const [
    _Segment(icon: Icons.person, label: 'People'),
    _Segment(icon: Icons.videocam, label: 'Videos'),
    _Segment(icon: Icons.music_note, label: 'Songs'),
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
    setState(() {}); // update clear icon
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
        // ── Search Bar ─────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: TextField(
            controller: _controller,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search',
              filled: true,
              fillColor: const Color(0xFFF2F5F8),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : GestureDetector(
                      onTap: () {
                        _controller.clear();
                        _onSearchChanged('');
                      },
                      child: const Icon(Icons.close, size: 20),
                    ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // ── Segmented Control ───────────────────
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_segments.length, (i) {
              final seg = _segments[i];
              final selected = i == _currentIndex;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _currentIndex = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? Colors.black : Colors.grey[800],
                      border: Border.all(
                          color: selected ? Colors.black : Colors.grey[600]!),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          seg.icon,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          seg.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        // ── Content ────────────────────────────
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