import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:http/http.dart' as http;
import 'package:kakan/config/theme.dart';
import 'package:kakan/features/myfiles/domain/entities/download_entity.dart';
import 'package:kakan/features/myfiles/presentation/bloc/delete_download/delete_download_bloc.dart';
import 'package:kakan/features/myfiles/presentation/bloc/delete_download/delete_download_event.dart';
import 'package:kakan/features/myfiles/presentation/bloc/delete_download/delete_download_state.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_bloc.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_event.dart';
import 'package:kakan/features/myfiles/presentation/bloc/downloads/downloads_state.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:toastification/toastification.dart';
import 'package:kakan/injection_container.dart' as di;

// contacts picker from your YouTube module
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:kakan/features/youtube/presentation/pages/contact_picker_page.dart';

enum AudioMenuOption { setRingtone, delete }

class AudioMyfilesWidget extends StatefulWidget {
  final ValueChanged<bool>? onOperationStateChanged;

  const AudioMyfilesWidget({super.key, this.onOperationStateChanged});

  @override
  State<AudioMyfilesWidget> createState() => _AudioMyfilesWidgetState();
}

class _AudioMyfilesWidgetState extends State<AudioMyfilesWidget> {
  static const MethodChannel _ringtoneChannel =
      MethodChannel('com.example.kakan/ringtone_channel');

  bool _isSettingRingtone = false;

  void _setBusy(bool v) {
    if (!mounted) return;
    setState(() => _isSettingRingtone = v);
    widget.onOperationStateChanged?.call(v);
  }

  // ---------- Public entry ----------
  Future<void> _setAsRingtone(BuildContext context, DownloadEntity download) async {
    // Offer choices (Default / Contacts)
    await _showRingtoneOptions(download);
  }

  // ---------- Flow: options sheet ----------
  Future<void> _showRingtoneOptions(DownloadEntity d) async {
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final textPrimary = Colors.black87;
        final textMuted = Colors.grey[600]!;
        final border = Border.all(color: Colors.grey.shade300);

        Widget option({
          required IconData icon,
          required String title,
          required String subtitle,
          required VoidCallback onTap,
        }) {
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: border,
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: border,
                    ),
                    child: Icon(icon, color: textPrimary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: appTheme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            )),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: appTheme.textTheme.bodySmall
                                ?.copyWith(color: textMuted)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: textMuted),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.ring_volume, color: Colors.black87),
                  const SizedBox(width: 8),
                  Text('Set as Ringtone',
                      style: appTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      )),
                ],
              ),
              const SizedBox(height: 16),
              option(
                icon: Icons.phone_android,
                title: 'Default (All Calls)',
                subtitle: 'Use this audio for all incoming calls',
                onTap: () async {
                  Navigator.pop(ctx);
                  await _setAsDefaultRingtone(d);
                },
              ),
              const SizedBox(height: 12),
              option(
                icon: Icons.person,
                title: 'Specific Contacts',
                subtitle: 'Choose people to assign this ringtone',
                onTap: () async {
                  Navigator.pop(ctx);
                  await _setForContacts(d);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // ---------- Action: Default ringtone ----------
  Future<void> _setAsDefaultRingtone(DownloadEntity d) async {
    try {
      // Check "modify system settings" first so we don't waste a download.
      final canWrite = await _ringtoneChannel.invokeMethod<bool>('canWriteSettings') ?? false;
      if (!canWrite) {
        await _ringtoneChannel.invokeMethod('openWriteSettings');
        _snack('Please allow “Modify system settings”, then try again.');
        return;
      }

      _setBusy(true);
      final local = await _ensureLocalFile(d);
      if (local == null) {
        _snack('Could not download audio.');
        return;
      }

      final ok = await _ringtoneChannel.invokeMethod<bool>(
            'setGlobalRingtone',
            {'filePath': local},
          ) ??
          false;

      if (ok) {
        await _showSuccessSheet(
          title: 'Ringtone set!',
          subtitle: 'Applied as default for all calls (both SIMs where supported).',
        );
      } else {
        _snack('Failed to set default ringtone.');
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      _setBusy(false);
    }
  }

  // ---------- Action: Contacts ringtone ----------
  Future<void> _setForContacts(DownloadEntity d) async {
    try {
      // Contacts permission
      if (!await Permission.contacts.isGranted) {
        final st = await Permission.contacts.request();
        if (!st.isGranted) {
          _snack('Contacts permission is required.');
          return;
        }
      }

      // Let user pick
      final picked = await Navigator.of(context).push<List<Contact>>(
        MaterialPageRoute(builder: (_) => const ContactPickerPage()),
      );
      if (picked == null || picked.isEmpty) return;

      // Also ensure "modify settings" is allowed
      final canWrite = await _ringtoneChannel.invokeMethod<bool>('canWriteSettings') ?? false;
      if (!canWrite) {
        await _ringtoneChannel.invokeMethod('openWriteSettings');
        _snack('Please allow “Modify system settings”, then try again.');
        return;
      }

      _setBusy(true);
      final local = await _ensureLocalFile(d);
      if (local == null) {
        _snack('Could not download audio.');
        return;
      }

      bool allSuccess = true;
      for (final c in picked) {
        final ok = await _ringtoneChannel.invokeMethod<bool>(
              'setContactRingtone',
              {'contactId': c.id, 'filePath': local},
            ) ??
            false;
        if (!ok) allSuccess = false;
      }

      if (allSuccess) {
        await _showSuccessSheet(
          title: 'Ringtone set!',
          subtitle:
              'Assigned to ${picked.length} contact${picked.length == 1 ? '' : 's'}.',
        );
      } else {
        _snack('Failed to set for some contacts.');
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      _setBusy(false);
    }
  }

  // ---------- Helpers ----------
  Future<String?> _ensureLocalFile(DownloadEntity d) async {
    try {
      // If it already looks like a local file path and exists, use it.
      final maybeFile = File(d.mediaFile ?? '');
      if ((d.mediaFile?.startsWith('/') ?? false) && await maybeFile.exists()) {
        return maybeFile.path;
      }

      // Otherwise download to temp.
      final url = d.mediaFile;
      if (url == null || url.isEmpty) return null;

      final tmpDir = await getTemporaryDirectory();
      final uri = Uri.parse(url);
      final ext = p.extension(uri.path).isNotEmpty ? p.extension(uri.path) : '.mp3';
      final name = 'ringtone_${d.id}_${DateTime.now().millisecondsSinceEpoch}$ext';
      final outPath = p.join(tmpDir.path, name);

      final resp = await http.get(uri);
      if (resp.statusCode != 200) return null;

      final f = File(outPath);
      await f.writeAsBytes(resp.bodyBytes);
      if (!await f.exists() || await f.length() < 1024) return null;
      return outPath;
    } catch (e) {
      if (kDebugMode) print('Download error: $e');
      return null;
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    toastification.show(
      context: context,
      title: Text(msg),
      type: ToastificationType.info,
      style: ToastificationStyle.fillColored,
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  Future<void> _openSoundSettings() async {
    try {
      await _ringtoneChannel.invokeMethod('openSoundSettings');
    } catch (_) {}
  }

  Future<void> _showSuccessSheet({
    required String title,
    required String subtitle,
  }) async {
    if (!mounted) return;
    final primary = const Color(0xFF4C82FB);
    final secondary = const Color(0xFF00E5A8);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          minimum: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 14),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1.0),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [primary, secondary]),
                    boxShadow: [
                      BoxShadow(
                        color: secondary.withOpacity(0.25),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded,
                      size: 40, color: Colors.white),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: appTheme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: appTheme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openSoundSettings();
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('Sound settings'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('Done',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSettingRingtone,
      child: Stack(
        children: [
          BlocProvider(
            create: (_) => di.sl<DeleteDownloadBloc>(),
            child: BlocListener<DeleteDownloadBloc, DeleteDownloadState>(
              listener: (context, state) {
                if (state is DeleteDownloadLoading) {
                  toastification.show(
                    context: context,
                    title: const Text('Deleting...'),
                    type: ToastificationType.info,
                    autoCloseDuration: const Duration(seconds: 2),
                  );
                } else if (state is DeleteDownloadSuccess) {
                  toastification.show(
                    context: context,
                    title: const Text('Deleted successfully'),
                    type: ToastificationType.success,
                    autoCloseDuration: const Duration(seconds: 2),
                  );
                  // refresh list
                  context.read<DownloadsBloc>().add(
                        GetDownloadsEvent(mediaType: 'audio'),
                      );
                } else if (state is DeleteDownloadError) {
                  toastification.show(
                    context: context,
                    title: Text(state.message),
                    type: ToastificationType.error,
                    autoCloseDuration: const Duration(seconds: 3),
                  );
                }
              },
              child: BlocBuilder<DownloadsBloc, DownloadsState>(
                builder: (context, state) {
                  if (state is DownloadsInitial || state is DownloadsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is DownloadsError) {
                    return Center(
                        child: Text('Failed to load songs: ${state.message}'));
                  } else if (state is DownloadsLoaded) {
                    if (state.downloads.isEmpty) {
                      return const Center(child: Text('No songs found'));
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.downloads.length,
                      itemBuilder: (context, index) {
                        final download = state.downloads[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 120,
                                height: 80,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: Image.network(
                                    download.thumbnail ?? '',
                                    width: 120,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Image.asset('assets/images/youtubeicon.png'),
                                  ),
                                ),
                              ),
                              const Gap(12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      download.title ?? 'Untitled Song',
                                      style: appTheme.textTheme.titleSmall
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Gap(4),
                                    Text(
                                      download.created,
                                      style: appTheme.textTheme.bodySmall?.copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const Gap(4),
                                    Text(
                                      download.duration ?? '00:00',
                                      style: appTheme.textTheme.bodySmall?.copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<AudioMenuOption>(
                                icon: const Icon(Icons.more_horiz_rounded,
                                    color: Colors.grey),
                                enabled: !_isSettingRingtone,
                                onSelected: (option) {
                                  switch (option) {
                                    case AudioMenuOption.setRingtone:
                                      _setAsRingtone(context, download);
                                      break;
                                    case AudioMenuOption.delete:
                                      context.read<DeleteDownloadBloc>().add(
                                            DeleteDownloadEvent(
                                                mediaId: download.id),
                                          );
                                      break;
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: AudioMenuOption.setRingtone,
                                    child: Text('Set as ringtone'),
                                  ),
                                  PopupMenuItem(
                                    value: AudioMenuOption.delete,
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }
                  return const Center(child: Text('Loading songs...'));
                },
              ),
            ),
          ),
          if (_isSettingRingtone)
            Container(
              color: Colors.black.withOpacity(0.15),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
