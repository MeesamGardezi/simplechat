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

  void _openRoom(Room room) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(room: room)));
  }

  String _fmtTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('HH:mm').format(dt);
    }
    if (now.difference(dt).inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('dd/MM/yy').format(dt);
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
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
            onSelected: (v) {
              if (v == 'logout') {
                context.read<AuthProvider>().logout();
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewChat(context),
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
                      itemBuilder: (ctx, i) {
                        final room = chat.rooms[i];
                        return _RoomTile(
                          room: room,
                          timeStr: _fmtTime(room.lastMessageAt),
                          onTap: () => _openRoom(room),
                        );
                      },
                    ),
            ),
    );
  }

  void _showNewChat(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _NewChatSheet(
        onDm: (user) async {
          Navigator.pop(ctx);
          final room = await ctx.read<ChatProvider>().startDm(user.id);
          if (ctx.mounted) _openRoom(room);
        },
        onGroup: (name, ids) async {
          Navigator.pop(ctx);
          final room = await ctx.read<ChatProvider>().createGroup(name, ids);
          if (ctx.mounted) _openRoom(room);
        },
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final Room room;
  final String timeStr;
  final VoidCallback onTap;

  const _RoomTile({required this.room, required this.timeStr, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            UserAvatar(name: room.name, colorHex: room.avatarColor, radius: 26),
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
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: const TextStyle(fontSize: 12, color: Colors.black38),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    room.lastMessage ?? 'No messages yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: room.lastMessage != null ? Colors.black45 : Colors.black26,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: C.divider),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String name;
  const _EmptyState({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: C.teal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded, size: 40, color: C.teal),
            ),
            const SizedBox(height: 20),
            Text(
              'Hey $name 👋',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the chat button below\nto start a conversation',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black38, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── New Chat Bottom Sheet ──────────────────────────────────────────────

class _NewChatSheet extends StatefulWidget {
  final void Function(User) onDm;
  final void Function(String name, List<String> ids) onGroup;

  const _NewChatSheet({required this.onDm, required this.onGroup});

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<User>? _users;
  String _q = '';
  final Set<User> _selected = {};
  final _groupCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    context.read<ChatProvider>().allUsers().then((u) {
      if (mounted) setState(() => _users = u);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _groupCtrl.dispose();
    super.dispose();
  }

  List<User> get _filtered =>
      (_users ?? []).where((u) => u.username.toLowerCase().contains(_q.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      expand: false,
      builder: (_, sc) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 4),
          TabBar(
            controller: _tabs,
            labelColor: C.teal,
            unselectedLabelColor: Colors.black38,
            indicatorColor: C.teal,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: const [Tab(text: 'New Chat'), Tab(text: 'New Group')],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                prefixIcon: const Icon(Icons.search, size: 20, color: Colors.black38),
                filled: true,
                fillColor: C.inputBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _dmList(sc),
                _groupBuilder(sc),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dmList(ScrollController sc) {
    if (_users == null) return const Center(child: CircularProgressIndicator(color: C.teal));
    if (_filtered.isEmpty) {
      return const Center(child: Text('No users found', style: TextStyle(color: Colors.black38)));
    }
    return ListView.builder(
      controller: sc,
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final u = _filtered[i];
        return ListTile(
          leading: UserAvatar(name: u.username, colorHex: u.avatarColor),
          title: Text(u.username, style: const TextStyle(fontWeight: FontWeight.w500)),
          onTap: () => widget.onDm(u),
        );
      },
    );
  }

  Widget _groupBuilder(ScrollController sc) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _groupCtrl,
            decoration: InputDecoration(
              hintText: 'Group name',
              hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
              filled: true,
              fillColor: C.inputBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (_selected.isNotEmpty)
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: _selected.map((u) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Chip(
                  label: Text(u.username, style: const TextStyle(fontSize: 12)),
                  avatar: UserAvatar(name: u.username, colorHex: u.avatarColor, radius: 10),
                  deleteIconColor: Colors.black38,
                  onDeleted: () => setState(() => _selected.remove(u)),
                  backgroundColor: C.teal.withOpacity(0.08),
                  padding: EdgeInsets.zero,
                ),
              )).toList(),
            ),
          ),
        Expanded(
          child: _users == null
              ? const Center(child: CircularProgressIndicator(color: C.teal))
              : ListView.builder(
                  controller: sc,
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final u = _filtered[i];
                    return CheckboxListTile(
                      value: _selected.contains(u),
                      onChanged: (_) => setState(() {
                        _selected.contains(u) ? _selected.remove(u) : _selected.add(u);
                      }),
                      secondary: UserAvatar(name: u.username, colorHex: u.avatarColor),
                      title: Text(u.username),
                      activeColor: C.teal,
                      controlAffinity: ListTileControlAffinity.trailing,
                    );
                  },
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _selected.isNotEmpty && _groupCtrl.text.trim().isNotEmpty
                    ? () => widget.onGroup(
                          _groupCtrl.text.trim(),
                          _selected.map((u) => u.id).toList(),
                        )
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: Text(
                  _selected.isEmpty
                      ? 'Select members'
                      : 'Create group (${_selected.length})',
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
