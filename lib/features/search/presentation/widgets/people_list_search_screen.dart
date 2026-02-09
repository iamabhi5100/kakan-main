import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kakan/features/search/domain/entities/search_result.dart';
import 'package:kakan/features/search/presentation/bloc/combined_search/combined_search_bloc.dart';
import 'package:kakan/features/search/presentation/bloc/combined_search/combined_search_state.dart';
import 'package:kakan/features/search/presentation/theme/search_theme.dart';
import 'package:kakan/features/followsuggestions/presentation/bloc/suggestion_bloc.dart';
import 'package:kakan/features/followsuggestions/presentation/bloc/suggestion_event.dart';

class PeopleListSearchScreen extends StatelessWidget {
  const PeopleListSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CombinedSearchBloc, CombinedSearchState>(
      builder: (context, state) {
        if (state is SearchLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(SearchTheme.spacingXXl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: SearchTheme.primary,
                    ),
                  ),
                  SizedBox(height: SearchTheme.spacingLg),
                  Text('Searching…', style: SearchTheme.emptySubtitle),
                ],
              ),
            ),
          );
        }
        if (state is SearchLoaded) {
          final people = state.people;
          if (people.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(SearchTheme.spacingXXl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_search_rounded,
                      size: 64,
                      color: SearchTheme.textMuted,
                    ),
                    const SizedBox(height: SearchTheme.spacingLg),
                    Text('No people found', style: SearchTheme.emptyTitle),
                    const SizedBox(height: SearchTheme.spacingSm),
                    Text(
                      'Try a different search term',
                      style: SearchTheme.emptySubtitle,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: SearchTheme.spacingLg,
              vertical: SearchTheme.spacingSm,
            ),
            itemCount: people.length,
            separatorBuilder: (_, __) => const SizedBox(height: SearchTheme.spacingSm),
            itemBuilder: (_, i) => _PersonTile(user: people[i]),
          );
        }
        if (state is SearchError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(SearchTheme.spacingXXl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, size: 48, color: SearchTheme.likeRed),
                  const SizedBox(height: SearchTheme.spacingLg),
                  Text(state.message, style: SearchTheme.errorText, textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(SearchTheme.spacingXXl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_rounded, size: 64, color: SearchTheme.textMuted),
                const SizedBox(height: SearchTheme.spacingLg),
                Text('Type to search', style: SearchTheme.emptyTitle),
                const SizedBox(height: SearchTheme.spacingSm),
                Text(
                  'Find people, videos, and songs',
                  style: SearchTheme.emptySubtitle,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PersonTile extends StatefulWidget {
  final SearchResult user;

  const _PersonTile({required this.user});

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
    final u = widget.user;
    return Material(
      color: SearchTheme.cardBg,
      borderRadius: BorderRadius.circular(SearchTheme.radiusLg),
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(SearchTheme.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(SearchTheme.spacingMd),
          child: Row(
            children: [
              CircleAvatar(
                radius: SearchTheme.avatarSize / 2,
                backgroundColor: SearchTheme.divider,
                backgroundImage: u.profileImage != null && u.profileImage!.isNotEmpty
                    ? NetworkImage(u.profileImage!)
                    : null,
                child: u.profileImage == null || u.profileImage!.isEmpty
                    ? Icon(Icons.person_rounded, color: SearchTheme.textMuted, size: 28)
                    : null,
              ),
              const SizedBox(width: SearchTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.username ?? 'Unknown',
                      style: SearchTheme.titleCard,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: SearchTheme.spacingXs),
                    Text(
                      '${u.name ?? ''} • ${u.followersCount ?? 0} Followers',
                      style: SearchTheme.caption.copyWith(color: SearchTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SearchTheme.spacingSm),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleFollow,
                  borderRadius: BorderRadius.circular(SearchTheme.radiusFull),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SearchTheme.spacingLg,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _followed
                          ? SearchTheme.chipUnselectedBg
                          : SearchTheme.primary,
                      borderRadius: BorderRadius.circular(SearchTheme.radiusFull),
                    ),
                    child: Text(
                      _followed ? 'Following' : 'Follow',
                      style: SearchTheme.labelChip.copyWith(
                        color: _followed ? SearchTheme.textSecondary : Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
