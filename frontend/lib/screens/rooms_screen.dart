import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/room.dart';
import '../models/user.dart';
import '../services/auth_provider.dart';
import '../services/chat_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import 'chat_screen.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadRooms();
    });
  }

  void _open(Room room) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(room: room)),
    ).then((_) {
      // Refresh room list when returning so last message is up to date
      if (mounted) context.read<ChatProvider>().loadRooms();
    });
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('HH:mm').format(dt);
    }
    if (now.difference(dt).inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('d/M/yy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final myName = context.read<AuthProvider>().user?.username ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('SimpleChat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
            tooltip: 'Search',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'new_group',
                child: const Row(
                  children: [
                    Icon(Icons.group_add_outlined, size: 20, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('New group'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: const Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('Log out'),
                  ],
                ),
              ),
            ],
            onSelected: (v) {
              if (v == 'logout') {
                context.read<AuthProvider>().logout();
              } else if (v == 'new_group') {
                _showNewChat(context, startOnGroup: true);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewChat(context),
        tooltip: 'New chat',
        child: const Icon(Icons.chat_rounded, size: 26),
      ),
      body: chat.roomsLoading
          ? const Center(child: CircularProgressIndicator(color: C.teal))
          : RefreshIndicator(
              color: C.teal,
              onRefresh: chat.loadRooms,
              child: chat.rooms.isEmpty
                  ? _EmptyState(name: myName)
                  : ListView.builder(
                      itemCount: chat.rooms.length,
                      itemBuilder: (_, i) {
                        final room = chat.rooms[i];
                        return _RoomTile(
                          room: room,
                          time: _formatTime(room.lastMessageAt),
                          onTap: () => _open(room),
                        );
                      },
                    ),
            ),
    );
  }

  void _showNewChat(BuildContext context, {bool startOnGroup = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _NewChatSheet(
        initialTab: startOnGroup ? 1 : 0,
        onDm: (user) async {
          Navigator.pop(context);
          try {
            final room = await context.read<ChatProvider>().startDm(user.id);
            if (context.mounted) _open(room);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not open chat: $e')),
              );
            }
          }
        },
        onGroup: (name, ids) async {
          Navigator.pop(context);
          try {
            final room = await context.read<ChatProvider>().createGroup(name, ids);
            if (context.mounted) _open(room);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not create group: $e')),
              );
            }
          }
        },
      ),
    );
  }
}

// ─── Room list tile ────────────────────────────────────────────────────────

class _RoomTile extends StatelessWidget {
  final Room room;
  final String time;
  final VoidCallback onTap;

  const _RoomTile({required this.room, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                UserAvatar(name: room.name, colorHex: room.avatarColor, radius: 27),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              room.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111B21),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF8696A0),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        room.lastMessage ?? 'No messages yet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: room.lastMessage != null
                              ? const Color(0xFF8696A0)
                              : const Color(0xFFB0BAC3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 0.5,
            indent: 74,
            color: Color(0xFFE9EDEF),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String name;

  const _EmptyState({required this.name});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F8F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded,
                    size: 44, color: C.teal),
              ),
              const SizedBox(height: 20),
              Text(
                'Hey, $name!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111B21),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the  button to start chatting',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF8696A0),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── New chat / group bottom sheet ────────────────────────────────────────

class _NewChatSheet extends StatefulWidget {
  final int initialTab;
  final void Function(User) onDm;
  final void Function(String name, List<String> ids) onGroup;

  const _NewChatSheet({
    required this.initialTab,
    required this.onDm,
    required this.onGroup,
  });

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<User>? _users;
  String _filter = '';
  final _groupNameCtrl = TextEditingController();
  final Set<User> _selected = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await context.read<ChatProvider>().allUsers();
      if (mounted) setState(() { _users = users; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _groupNameCtrl.dispose();
    super.dispose();
  }

  List<User> get _filtered => (_users ?? [])
      .where((u) => u.username.toLowerCase().contains(_filter.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      expand: false,
      builder: (_, sc) => Column(
        children: [
          // Handle
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 6),

          // Tabs
          TabBar(
            controller: _tabs,
            labelColor: C.teal,
            unselectedLabelColor: const Color(0xFF8696A0),
            indicatorColor: C.teal,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: const [Tab(text: 'New Chat'), Tab(text: 'New Group')],
          ),

          // Search box
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search name…',
                hintStyle: const TextStyle(color: Color(0xFFADB5BC), fontSize: 15),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFADB5BC), size: 22),
                filled: true,
                fillColor: const Color(0xFFF0F2F5),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _dmTab(sc),
                _groupTab(sc),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dmTab(ScrollController sc) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: C.teal));
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    if (_filtered.isEmpty) {
      return const Center(
        child: Text('No users found', style: TextStyle(color: Color(0xFF8696A0))),
      );
    }
    return ListView.builder(
      controller: sc,
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final u = _filtered[i];
        return ListTile(
          leading: UserAvatar(name: u.username, colorHex: u.avatarColor),
          title: Text(
            u.username,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
          ),
          onTap: () => widget.onDm(u),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        );
      },
    );
  }

  Widget _groupTab(ScrollController sc) {
    return Column(
      children: [
        // Group name field
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: TextField(
            controller: _groupNameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Group name',
              hintStyle: const TextStyle(color: Color(0xFFADB5BC)),
              prefixIcon: const Icon(Icons.group_outlined, color: Color(0xFFADB5BC)),
              filled: true,
              fillColor: const Color(0xFFF0F2F5),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),

        // Selected chips
        if (_selected.isNotEmpty)
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _selected.map((u) => Padding(
                padding: const EdgeInsets.only(right: 6, top: 4),
                child: Chip(
                  avatar: UserAvatar(name: u.username, colorHex: u.avatarColor, radius: 11),
                  label: Text(u.username, style: const TextStyle(fontSize: 13)),
                  deleteIconColor: const Color(0xFF8696A0),
                  onDeleted: () => setState(() => _selected.remove(u)),
                  backgroundColor: const Color(0xFFE7F8F5),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              )).toList(),
            ),
          ),

        // User list with checkboxes
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: C.teal))
              : ListView.builder(
                  controller: sc,
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final u = _filtered[i];
                    final sel = _selected.contains(u);
                    return InkWell(
                      onTap: () => setState(() {
                        sel ? _selected.remove(u) : _selected.add(u);
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            UserAvatar(name: u.username, colorHex: u.avatarColor),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                u.username,
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: sel ? C.teal : Colors.transparent,
                                border: Border.all(
                                  color: sel ? C.teal : const Color(0xFFCDD5DB),
                                  width: 2,
                                ),
                              ),
                              child: sel
                                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Create button
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _selected.isNotEmpty && _groupNameCtrl.text.trim().isNotEmpty
                    ? () => widget.onGroup(
                          _groupNameCtrl.text.trim(),
                          _selected.map((u) => u.id).toList(),
                        )
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.green,
                  disabledBackgroundColor: const Color(0xFFB0D5C0),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: Text(
                  _selected.isEmpty
                      ? 'Select at least one member'
                      : 'Create "${_groupNameCtrl.text.trim()}" (${_selected.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
