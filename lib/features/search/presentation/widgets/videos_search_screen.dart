import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/features/search/presentation/bloc/combined_search/combined_search_bloc.dart';
import 'package:kakan/features/search/presentation/bloc/combined_search/combined_search_state.dart';
import 'package:kakan/features/search/domain/entities/search_result.dart';
import 'package:kakan/features/search/presentation/pages/video_content_screen.dart';

class VideosSearchScreen extends StatelessWidget {
  const VideosSearchScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CombinedSearchBloc, CombinedSearchState>(
      builder: (context, state) {
        if (state is SearchLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is SearchLoaded) {
          final videos = state.videos;
          if (videos.isEmpty) {
            return const Center(child: Text('No videos found'));
          }
          return ListView.builder(
            itemCount: videos.length,
            itemBuilder: (ctx, index) {
              final r = videos[index];
              return ListTile(
                leading: r.thumbnail != null
                    ? Image.network(r.thumbnail!, width: 50, height: 50, fit: BoxFit.cover)
                    : const Icon(Icons.videocam),
                title: Text(r.name ?? ''),
                subtitle: Text(r.description ?? ''),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoContentScreen(video: r),
                    ),
                  );
                },
              );
            },
          );
        } else if (state is SearchError) {
          return Center(child: Text(state.message));
        }
        return const Center(child: Text('Type to search'));
      },
    );
  }
}
