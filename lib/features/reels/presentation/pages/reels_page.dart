import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:kakan/config/constant_api.dart';
import 'package:kakan/features/reels/presentation/bloc/reel_lists/reels_bloc.dart';
import 'package:kakan/features/reels/presentation/widgets/reel_item.dart';
import 'package:kakan/injection_container.dart' as di;

class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key});

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> with WidgetsBindingObserver {
  late PageController _pageController;
  late ReelsBloc _reelsBloc;
  int _currentIndex = 0;
  final int _preloadRange = 0; // Only preload current reel to reduce memory usage
  final int _fetchThreshold = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _currentIndex);
    _reelsBloc = di.sl<ReelsBloc>()..add(FetchReelsEvent());
    _pageController.addListener(_onPageScroll);
    print('DEBUG: ReelsPage initState, ReelsBloc: $_reelsBloc');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('DEBUG: App resumed, refreshing reels');
      _reelsBloc.add(FetchReelsEvent());
    } else if (state == AppLifecycleState.paused) {
      print('DEBUG: App paused, pausing all reels');
      _reelsBloc.add(PauseAllReelsEvent());
    }
  }

  void _onPageScroll() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentIndex) {
      setState(() {
        _currentIndex = page;
      });
      print('DEBUG: Page changed to index $_currentIndex');
      _checkForMoreReels();
    }
  }

  void _checkForMoreReels() {
    final state = _reelsBloc.state;
    if (state is ReelsLoaded) {
      if (_currentIndex >= state.reels.length - _fetchThreshold && state.hasMore) {
        print('DEBUG: Fetching more reels at index $_currentIndex');
        _reelsBloc.add(FetchMoreReelsEvent());
      }
    }
  }

  Future<void> _refreshReels() async {
    final cacheManager = di.sl<DefaultCacheManager>();
    await cacheManager.emptyCache();
    print('DEBUG: Cleared entire cache');
    _reelsBloc.add(FetchReelsEvent());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _reelsBloc.close();
    print('DEBUG: ReelsPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: Building ReelsPage');
    return BlocProvider(
      create: (_) => _reelsBloc,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshReels,
            child: BlocBuilder<ReelsBloc, ReelsState>(
              builder: (context, state) {
                print('DEBUG: ReelsBloc state: $state');
                if (state is ReelsLoading && state.reels.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                } else if (state is ReelsEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'No Trims Available',
                          style: TextStyle(color: Colors.white),
                        ),
                        ElevatedButton(
                          onPressed: () => context.read<ReelsBloc>().add(FetchReelsEvent()),
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  );
                } else if (state is ReelsLoaded ||
                    state is ReelsLikeUpdating ||
                    state is ReelsRepostUpdating ||
                    state is ReelsLikeError ||
                    state is ReelsShareTargetsLoaded) {
                  final reels = state is ReelsLoaded
                      ? state.reels
                      : state is ReelsLikeUpdating
                          ? state.reels
                          : state is ReelsRepostUpdating
                              ? state.reels
                              : state is ReelsShareTargetsLoaded
                                  ? state.reels
                                  : (state as ReelsLikeError).reels;
                  final hasMore = state is ReelsLoaded
                      ? state.hasMore
                      : state is ReelsLikeUpdating
                          ? state.hasMore
                          : state is ReelsRepostUpdating
                              ? state.hasMore
                              : state is ReelsShareTargetsLoaded
                                  ? state.hasMore
                                  : (state as ReelsLikeError).hasMore;
                  return PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount: reels.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == reels.length) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }
                      final isPlaying = index == _currentIndex;
                      final isPreload = (index - _currentIndex).abs() <= _preloadRange;
                      print('DEBUG: Rendering ReelItem for index $index, isPlaying: $isPlaying, isPreload: $isPreload');
                      return ReelItem(
                        reel: reels[index],
                        isPlaying: isPlaying,
                        isPreload: isPreload,
                      );
                    },
                  );
                } else if (state is ReelsError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          state.message,
                          style: const TextStyle(color: Colors.white),
                        ),
                        ElevatedButton(
                          onPressed: () => context.read<ReelsBloc>().add(FetchReelsEvent()),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                return const Center(
                  child: Text(
                    'Initializing Trims...',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}