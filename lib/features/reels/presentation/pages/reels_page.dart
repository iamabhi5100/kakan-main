import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
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
  final int _preloadRange = 0;
  final int _fetchThreshold = 3;
  static const double _pullToRefreshThreshold = 140;
  double _pullDownTotal = 0;
  double? _lastPointerY;
  bool _isRefreshing = false;

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
    // FIX: Check against ReelsActionState to be more robust
    if (state is ReelsActionState) {
      if (_currentIndex >= state.reels.length - _fetchThreshold && state.hasMore) {
        print('DEBUG: Fetching more reels at index $_currentIndex');
        _reelsBloc.add(FetchMoreReelsEvent());
      }
    }
  }

  Future<void> _refreshReels() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    final cacheManager = di.sl<DefaultCacheManager>();
    await cacheManager.emptyCache();
    print('DEBUG: Cleared entire cache');
    _reelsBloc.add(FetchReelsEvent());
    try {
      await _reelsBloc.stream
          .where((s) => s is ReelsLoaded || s is ReelsEmpty || s is ReelsError)
          .first
          .timeout(const Duration(seconds: 30));
    } catch (_) {}
    if (mounted) setState(() => _isRefreshing = false);
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
        body: Stack(
          children: [
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                if (_currentIndex == 0) {
                  _pullDownTotal = 0;
                  _lastPointerY = event.position.dy;
                }
              },
              onPointerMove: (event) {
                if (_currentIndex != 0 || _isRefreshing || _lastPointerY == null) return;
                final dy = event.position.dy - _lastPointerY!;
                _lastPointerY = event.position.dy;
                if (dy > 0) {
                  setState(() => _pullDownTotal += dy);
                }
              },
              onPointerUp: (_) {
                if (_currentIndex == 0 &&
                    !_isRefreshing &&
                    _pullDownTotal >= _pullToRefreshThreshold) {
                  setState(() => _pullDownTotal = 0);
                  _refreshReels();
                } else {
                  if (_pullDownTotal > 0) setState(() => _pullDownTotal = 0);
                }
                _lastPointerY = null;
              },
              onPointerCancel: (_) {
                _lastPointerY = null;
                if (_pullDownTotal > 0) setState(() => _pullDownTotal = 0);
              },
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return BlocBuilder<ReelsBloc, ReelsState>(
                      buildWhen: (previous, current) {
                        return current is! ReelCommentsLoading &&
                            current is! ReelCommentsLoaded &&
                            current is! ReelCommentsError;
                      },
                      builder: (context, state) {
                        print('DEBUG: ReelsBloc state: $state');
                        if (state is ReelsLoading && state.reels.isEmpty) {
                          return SizedBox(
                            height: constraints.maxHeight,
                            child: const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          );
                        } else if (state is ReelsEmpty) {
                          return SizedBox(
                            height: constraints.maxHeight,
                            child: Center(
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
                            ),
                          );
                        } else if (state is ReelsActionState) {
                          final reels = state.reels;
                          final hasMore = state.hasMore;
                          return SizedBox(
                            height: constraints.maxHeight,
                            child: PageView.builder(
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
                            ),
                          );
                        } else if (state is ReelsError) {
                          return SizedBox(
                            height: constraints.maxHeight,
                            child: Center(
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
                            ),
                          );
                        }
                        return SizedBox(
                          height: constraints.maxHeight,
                          child: const Center(
                            child: Text(
                              'Initializing Trims...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            if (_isRefreshing || (_currentIndex == 0 && _pullDownTotal > 0))
              Positioned(
                top: MediaQuery.of(context).padding.top + 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(32),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: _isRefreshing
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  )
                                : CustomPaint(
                                    size: const Size(36, 36),
                                    painter: _PullProgressPainter(
                                      progress: (_pullDownTotal / _pullToRefreshThreshold).clamp(0.0, 1.0),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        _pullDownTotal >= _pullToRefreshThreshold
                                            ? Icons.refresh
                                            : Icons.keyboard_arrow_down,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _isRefreshing
                                ? 'Refreshing...'
                                : _pullDownTotal >= _pullToRefreshThreshold
                                    ? 'Release to refresh'
                                    : 'Pull down to refresh',
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PullProgressPainter extends CustomPainter {
  final double progress;

  _PullProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 3.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - strokeWidth;
    final paint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, paint);
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.25 * math.pi,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PullProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}