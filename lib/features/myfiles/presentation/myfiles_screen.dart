import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kakan/config/theme.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_bloc.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_event.dart';
import 'package:kakan/features/myfiles/presentation/widgets/tabs_myfiles_widger.dart';
import 'package:kakan/features/myfiles/presentation/widgets/video_myfiles_widget.dart';
import 'package:kakan/features/myfiles/presentation/widgets/audio_myfiles_widget.dart';
import 'package:kakan/injection_container.dart' as di;

class MyfilesScreen extends StatefulWidget {
  const MyfilesScreen({super.key});

  @override
  State<MyfilesScreen> createState() => _MyfilesScreenState();
}

class _MyfilesScreenState extends State<MyfilesScreen> {
  bool _isVideoTabActive = true;
  bool _isOperationInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DownloadsBloc>().add(
          GetDownloadsEvent(mediaType: 'video'),
        );
      }
    });
  }

  void _handleTabChange(bool isVideoActive) {
    if (_isOperationInProgress) {
      if (kDebugMode) {
        print('Tab change blocked: Operation in progress');
      }
      return;
    }
    if (_isVideoTabActive != isVideoActive) {
      setState(() {
        _isVideoTabActive = isVideoActive;
      });
      final mediaType = isVideoActive ? 'video' : 'audio';
      if (mounted) {
        context.read<DownloadsBloc>().add(
          GetDownloadsEvent(mediaType: mediaType),
        );
      }
    }
  }

  void _onOperationStateChanged(bool isInProgress) {
    if (mounted) {
      setState(() {
        _isOperationInProgress = isInProgress;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isOperationInProgress,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'My Files',
            style: appTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          // backgroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              children: [
                SearchBar(
                  padding: MaterialStateProperty.all(const EdgeInsets.all(8)),
                  leading: const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.search),
                  ),
                  hintText: 'Search',
                  trailing: const [
                    Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(Icons.clear),
                    ),
                  ],
                ),
                const Gap(10),
                TabsMyfilesWidget(
                  isVideoActive: _isVideoTabActive,
                  onTabChanged: _handleTabChange,
                ),
                const Gap(20),
                _isVideoTabActive
                    ? const VideoMyfilesWidget()
                    : AudioMyfilesWidget(
                      onOperationStateChanged: _onOperationStateChanged,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print('MyfilesScreen: Disposed');
    }
    super.dispose();
  }
}
