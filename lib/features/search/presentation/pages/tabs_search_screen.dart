import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/features/search/presentation/bloc/combined_search/combined_search_bloc.dart';
import 'package:kakan/features/search/presentation/bloc/combined_search/combined_search_event.dart';
import '../widgets/people_list_search_screen.dart';
import '../widgets/songs_list_search_screen.dart';
import '../widgets/videos_search_screen.dart';

class TabsSearchScreen extends StatelessWidget {
  const TabsSearchScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CombinedSearchBloc>();
    return Column(
      children: [
        // ── unified search bar ─────────────────
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (q) => bloc.add(SearchAllEvent(q)),
          ),
        ),

        const TabBar(
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: 'People'),
            Tab(text: 'Songs'),
            Tab(text: 'Videos'),
          ],
        ),

        Expanded(
          child: TabBarView(
            children:  [
              PeopleListSearchScreen(),
              SongsListSearchScreen(),
              VideosSearchScreen(),
            ],
          ),
        ),
      ],
    );
  }
}
