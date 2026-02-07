import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/features/search/presentation/bloc/combined_search/combined_search_bloc.dart';
import 'package:kakan/features/search/presentation/bloc/combined_search/combined_search_state.dart';
import 'package:kakan/features/search/domain/entities/search_result.dart';
import 'package:kakan/features/followsuggestions/presentation/bloc/suggestion_bloc.dart';
import 'package:kakan/features/followsuggestions/presentation/bloc/suggestion_event.dart';

class PeopleListSearchScreen extends StatelessWidget {
  const PeopleListSearchScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CombinedSearchBloc, CombinedSearchState>(
      builder: (context, state) {
        if (state is SearchLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is SearchLoaded) {
          final people = state.people;
          if (people.isEmpty) {
            return const Center(child: Text('No people found'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: people.length,
            itemBuilder: (ctx, i) => _PersonTile(user: people[i]),
          );
        }
        if (state is SearchError) {
          return Center(child: Text(state.message));
        }
        return const Center(child: Text('Type to search'));
      },
    );
  }
}

class _PersonTile extends StatefulWidget {
  final SearchResult user;
  const _PersonTile({Key? key, required this.user}) : super(key: key);

  @override
  State<_PersonTile> createState() => _PersonTileState();
}

class _PersonTileState extends State<_PersonTile> {
  late bool _followed;

  @override
  void initState() {
    super.initState();
    _followed = widget.user.isFollowed ?? false;
  }

  void _toggleFollow() {
    setState(() => _followed = !_followed);
    final bloc = context.read<SuggestionBloc>();
    if (_followed) {
      bloc.add(FollowUserEvent(userId: widget.user.id));
    } else {
      bloc.add(UnfollowUserEvent(userId: widget.user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          widget.user.profileImage != null
              ? CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(widget.user.profileImage!),
                )
              : const CircleAvatar(radius: 20, child: Icon(Icons.person)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user.username ?? '',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.user.name} • ${widget.user.followersCount} Followers',
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black54, height: 1.2),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: _toggleFollow,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: primary, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              minimumSize: const Size(0, 32),
            ),
            child: Text(
              _followed ? 'Unfollow' : 'Follow',
              style: TextStyle(
                color: _followed ? Colors.black54 : primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
