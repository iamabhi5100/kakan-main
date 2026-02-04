import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_bloc.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_event.dart';
import 'package:kakan/features/myfiles/presentation/widgets/tabs_myfiles_widger.dart';
import 'package:kakan/features/myfiles/presentation/widgets/video_myfiles_widget.dart';
import 'package:kakan/features/myfiles/presentation/widgets/audio_myfiles_widget.dart';

class MyfilesScreen extends StatefulWidget {
  const MyfilesScreen({super.key});

  @override
  State<MyfilesScreen> createState() => _MyfilesScreenState();
}

class _MyfilesScreenState extends State<MyfilesScreen> {
  // Two tabs (videos / audios)
  bool _isVideoTabActive = true;

  // Prevent back during long ops (like ringtone/export)
  bool _isOperationInProgress = false;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  static const _debounceDuration = Duration(milliseconds: 350);
  static const _minSearchLen = 4;

  @override
  void initState() {
    super.initState();
    // initial load (videos)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DownloadsBloc>().add(
            GetDownloadsEvent(
              mediaType: 'video',
              search: null, // initial: no filter
            ),
          );
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _currentMediaType() => _isVideoTabActive ? 'video' : 'audio';

  void _dispatchSearch({String? search}) {
    context.read<DownloadsBloc>().add(
          GetDownloadsEvent(
            mediaType: _currentMediaType(),
            search: (search != null && search.trim().isNotEmpty) ? search.trim() : null,
          ),
        );
  }

  void _runSearchNow() {
    // Only search when >= 4 characters OR when cleared (0)
    if (_searchQuery.isEmpty) {
      _dispatchSearch(search: null); // reset listing
    } else if (_searchQuery.length >= _minSearchLen) {
      _dispatchSearch(search: _searchQuery);
    }
    // if 1..3 chars, do nothing (no network call yet)
  }

  void _onTyped(String value) {
    _searchQuery = value;
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, _runSearchNow);
    setState(() {}); // refresh trailing clear/arrow state
  }

  void _onSubmit(String _) {
    // pressing enter should also respect the 4-char rule
    _debounce?.cancel();
    _runSearchNow();
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    _searchQuery = '';
    _dispatchSearch(search: null); // reset to full list
    setState(() {});
  }

  void _handleTabChange(bool isVideoActive) {
    if (_isOperationInProgress) return;
    if (_isVideoTabActive == isVideoActive) return;

    setState(() => _isVideoTabActive = isVideoActive);

    // When switching tabs, carry the search if it's >=4; else fetch full list for that tab
    if (_searchQuery.isEmpty) {
      _dispatchSearch(search: null);
    } else if (_searchQuery.length >= _minSearchLen) {
      _dispatchSearch(search: _searchQuery);
    } else {
      _dispatchSearch(search: null);
    }
  }

  // Child widgets can lock pop/back during long operations
  void _onOperationStateChanged(bool isInProgress) {
    if (!mounted) return;
    setState(() => _isOperationInProgress = isInProgress);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isOperationInProgress,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'My Files',
            style: appTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const Gap(10),
                SearchBar(
                  controller: _searchController,
                  elevation: MaterialStateProperty.all(0),
                  backgroundColor: MaterialStateProperty.all(Colors.grey[200]),
                  padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 16)),
                  leading: const Icon(Icons.search, color: Colors.grey),
                  hintText: 'Search',
                  hintStyle: MaterialStateProperty.all(
                    const TextStyle(color: Colors.grey),
                  ),
                  onChanged: _onTyped,
                  onSubmitted: _onSubmit,
                  trailing: [
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      ),
                  ],
                ),
                const Gap(8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'Showing all ${_currentMediaType()}s'
                        : (_searchQuery.length < _minSearchLen
                            ? 'Type ${_minSearchLen - _searchQuery.length} more character(s) to search'
                            : 'Searching "${_searchQuery}" in ${_currentMediaType()}s'),
                    style: appTheme.textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                  ),
                ),
                const Gap(20),
                TabsMyfilesWidget(
                  isVideoActive: _isVideoTabActive,
                  onTabChanged: _handleTabChange,
                ),
                const Gap(20),
                _isVideoTabActive
                    ? VideoMyfilesWidget(onSwitchToAudioTab: () => _handleTabChange(false))
                    : AudioMyfilesWidget(onOperationStateChanged: _onOperationStateChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
