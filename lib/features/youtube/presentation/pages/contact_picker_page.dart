// lib/features/youtube/presentation/pages/contact_picker_page.dart
import 'dart:async';
import 'package:azlistview/azlistview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

// Theming
const _bg       = Color(0xFF0F1115);
const _card     = Color(0xFF171A20);
const _muted    = Color(0xFF9AA4B2);
const _text     = Color(0xFFE6EAF2);
const _accent   = Color(0xFF00E5A8);
const _accent2  = Color(0xFF4C82FB);
const _fieldBg  = Color(0xFF141821);
const _trimBg   = Color(0xFF131720);

class _ContactInfo extends ISuspensionBean {
  final Contact contact;
  String tag;

  _ContactInfo({required this.contact, required this.tag});

  @override
  String getSuspensionTag() => tag;
}

class ContactPickerPage extends StatefulWidget {
  const ContactPickerPage({Key? key}) : super(key: key);

  @override
  State<ContactPickerPage> createState() => _ContactPickerPageState();
}

class _ContactPickerPageState extends State<ContactPickerPage> {
  List<Contact> _allContacts = [];
  List<_ContactInfo> _contactList = [];
  final Set<String> _selectedIds = <String>{};
  final List<Contact> _selectedContacts = [];
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        setState(() {
          _permissionDenied = true;
          _loading = false;
        });
        return;
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withThumbnail: true,
      );

      setState(() {
        _allContacts = contacts;
        _applyFilter('');
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      _applyFilter(_searchController.text);
    });
  }

  void _applyFilter(String query) {
    List<Contact> filtered = _allContacts;
    if (query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      filtered = _allContacts.where((c) {
        final dn = c.displayName.toLowerCase();
        final phones = c.phones.map((p) => p.normalizedNumber ?? p.number).join(' ').toLowerCase();
        return dn.contains(q) || phones.contains(q);
      }).toList();
    }

    final list = filtered.map((c) {
      String tag = c.displayName.isNotEmpty
          ? c.displayName.substring(0, 1).toUpperCase()
          : '#';
      if (!RegExp(r'^[A-Z]$').hasMatch(tag)) tag = '#';
      return _ContactInfo(contact: c, tag: tag);
    }).toList();

    SuspensionUtil.sortListBySuspensionTag(list);
    SuspensionUtil.setShowSuspensionStatus(list);

    setState(() => _contactList = list);
  }

  void _toggleSelection(Contact contact) {
    setState(() {
      if (_selectedIds.contains(contact.id)) {
        _selectedIds.remove(contact.id);
        _selectedContacts.removeWhere((c) => c.id == contact.id);
      } else {
        _selectedIds.add(contact.id);
        _selectedContacts.add(contact);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _selectedContacts.clear();
    });
  }

  ThemeData _theme(BuildContext context) {
    return Theme.of(context).copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _bg,
      colorScheme: const ColorScheme.dark(
        primary: _accent,
        secondary: _accent2,
        surface: _card,
        background: _bg,
        onPrimary: _bg,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _bg,
        foregroundColor: _text,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: Theme.of(context).textTheme.apply(
            bodyColor: _text,
            displayColor: _text,
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _fieldBg,
        hintStyle: const TextStyle(color: _muted),
        labelStyle: const TextStyle(color: _muted),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF30384A)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _accent),
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme(context);
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: Row(
            children: [
              const Text('Pick Contacts', overflow: TextOverflow.ellipsis),
              const SizedBox(width: 8),
              if (_selectedIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _accent, width: 1),
                  ),
                  child: Text(
                    '${_selectedIds.length} selected',
                    style: const TextStyle(color: _text, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          actions: [
            if (_selectedIds.isNotEmpty)
              TextButton.icon(
                onPressed: _clearSelection,
                icon: const Icon(Icons.clear, color: _muted, size: 18),
                label: const Text('Clear', style: TextStyle(color: _muted)),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search name or number…',
                    prefixIcon: const Icon(Icons.search, color: _muted),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _applyFilter('');
                            },
                            icon: const Icon(Icons.close, color: _muted),
                          )
                        : null,
                  ),
                  style: const TextStyle(color: _text),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                ),
              ),

              // Selected tray
              if (_selectedIds.isNotEmpty)
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (_, i) {
                      final c = _selectedContacts[i];
                      return SizedBox(
                        width: 74,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const SizedBox(height: 38, width: 38),
                                Positioned.fill(
                                  child: _Avatar(contact: c, size: 38),
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: InkWell(
                                    onTap: () => _toggleSelection(c),
                                    customBorder: const CircleBorder(),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _accent2,
                                      ),
                                      padding: const EdgeInsets.all(2),
                                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              c.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, height: 1.1, color: _muted),
                            ),
                          ],
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemCount: _selectedContacts.length,
                  ),
                ),

              // List
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: _accent))
                    : _permissionDenied
                        ? _NoPermission(onOpenSettings: openAppSettings)
                        : _contactList.isEmpty
                            ? const _EmptyState()
                            : _buildAZList(),
              ),
            ],
          ),
        ),

        // Bottom action
        bottomNavigationBar: _selectedIds.isNotEmpty
            ? SafeArea(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 12,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Set Ringtone for ${_selectedIds.length} contact${_selectedIds.length == 1 ? '' : 's'}',
                          style: const TextStyle(color: _text, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, List<Contact>.from(_selectedContacts)),
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text('Continue',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent2,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildAZList() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: NotificationListener<UserScrollNotification>(
            onNotification: (n) {
              FocusScope.of(context).unfocus();
              return false;
            },
            child: AzListView(
              data: _contactList,
              itemCount: _contactList.length,
              physics: const BouncingScrollPhysics(),

              itemBuilder: (BuildContext context, int index) {
                final info = _contactList[index];
                final c = info.contact;
                final isSelected = _selectedIds.contains(c.id);

                return InkWell(
                  onTap: () => _toggleSelection(c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: isSelected ? _card.withOpacity(0.7) : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: const Color(0xFF2A3242).withOpacity(0.6),
                          width: 0.8,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            _Avatar(contact: c),
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 150),
                              opacity: isSelected ? 1.0 : 0.0,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _accent2.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            c.displayName,
                            style: const TextStyle(
                              color: _text,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: () => _toggleSelection(c),
                          icon: Icon(
                            isSelected ? Icons.check_circle : Icons.add_circle_outline,
                            color: isSelected ? _accent : _muted,
                          ),
                          splashRadius: 22,
                        ),
                      ],
                    ),
                  ),
                );
              },

              susItemBuilder: (BuildContext context, int index) {
                final info = _contactList[index];
                if (!info.isShowSuspension) return const SizedBox.shrink();

                return LayoutBuilder(
                  builder: (ctx, c) {
                    final w = c.hasBoundedWidth ? c.maxWidth : MediaQuery.sizeOf(ctx).width;

                    return SizedBox(
                      width: w,
                      height: 32,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: _trimBg,
                          border: Border(
                            bottom: BorderSide(
                              color: const Color(0xFF2A3242).withOpacity(0.6),
                              width: 0.8,
                            ),
                          ),
                        ),
                        child: Text(
                          info.getSuspensionTag(),
                          style: const TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },

              indexBarData: SuspensionUtil.getTagIndexList(_contactList),
              indexBarMargin: const EdgeInsets.only(right: 6, top: 8, bottom: 8),
              indexBarOptions: const IndexBarOptions(
                needRebuild: true,
                hapticFeedback: true,
                selectTextStyle: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                selectItemDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent2,
                ),
                indexHintAlignment: Alignment.centerRight,
                indexHintWidth: 72,
                indexHintHeight: 72,
                indexHintDecoration: BoxDecoration(
                  color: Color(0xCC1E2330),
                  shape: BoxShape.circle,
                ),
                indexHintTextStyle: TextStyle(
                  color: _text,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  final Contact contact;
  final double size;
  const _Avatar({required this.contact, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final tag = contact.displayName.isNotEmpty
        ? contact.displayName.substring(0, 1).toUpperCase()
        : '#';
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFF222937),
      backgroundImage:
          contact.thumbnail != null ? MemoryImage(contact.thumbnail!) : null,
      child: contact.thumbnail == null
          ? Text(tag, style: const TextStyle(color: _muted, fontWeight: FontWeight.bold))
          : null,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search_off, size: 42, color: _muted),
        SizedBox(height: 10),
        Text('No contacts found', style: TextStyle(color: _muted)),
      ]),
    );
  }
}

class _NoPermission extends StatelessWidget {
  final VoidCallback onOpenSettings;
  const _NoPermission({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_person, size: 48, color: _muted),
            const SizedBox(height: 12),
            const Text(
              'Contacts permission is required to pick people.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings, color: Colors.white),
              label: const Text('Open settings',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent2,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
