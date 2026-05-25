import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/room.dart';
import '../models/user.dart';
import '../services/auth_provider.dart';
import '../services/chat_provider.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/connection_banner.dart';
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
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => ChatScreen(room: room),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 280),
      ),
    ).then((_) {
      if (mounted) context.read<ChatProvider>().loadRooms();
    });
  }

  String _fmtTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    if (_sameDay(dt, now)) return DateFormat('HH:mm').format(dt);
    if (now.difference(dt).inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('d/M/yy').format(dt);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final chat   = context.watch<ChatProvider>();
    final socket = context.read<SocketService>();
    final myName = context.read<AuthProvider>().user?.username ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('SimpleChat'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'group', child: Text('New group')),
              const PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
            onSelected: (v) {
              if (v == 'logout') context.read<AuthProvider>().logout();
              if (v == 'group')  _showNewChat(context, startOnGroup: true);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewChat(context),
        child: const Icon(Icons.chat_rounded, size: 26),
      ),
      body: Column(
        children: [
          ConnectionBanner(socket: socket),
          Expanded(
            child: chat.roomsLoading
                ? const Center(child: CircularProgressIndicator(color: C.teal))
                : RefreshIndicator(
                    color: C.teal,
                    onRefresh: chat.loadRooms,
                    child: chat.rooms.isEmpty
                        ? _EmptyState(name: myName)
                        : ListView.builder(
                            itemCount: chat.rooms.length,
                            itemBuilder: (_, i) => _RoomTile(
                              room: chat.rooms[i],
                              time: _fmtTime(chat.rooms[i].lastMessageAt),
                              onTap: () => _openRoom(chat.rooms[i]),
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showNewChat(BuildContext ctx, {bool startOnGroup = false}) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _NewChatSheet(
        initialTab: startOnGroup ? 1 : 0,
        onDm: (user) async {
          Navigator.pop(ctx);
          try {
            final room = await ctx.read<ChatProvider>().startDm(user.id);
            if (ctx.mounted) _openRoom(room);
          } catch (e) {
            if (ctx.mounted) _snack(ctx, 'Could not open chat: $e');
          }
        },
        onGroup: (name, ids) async {
          Navigator.pop(ctx);
          try {
            final room = await ctx.read<ChatProvider>().createGroup(name, ids);
            if (ctx.mounted) _openRoom(room);
          } catch (e) {
            if (ctx.mounted) _snack(ctx, 'Could not create group: $e');
          }
        },
      ),
    );
  }

  void _snack(BuildContext ctx, String msg) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
}

// ─── Room tile ─────────────────────────────────────────────────────────────

class _RoomTile extends StatelessWidget {
  final Room room;
  final String time;
  final VoidCallback onTap;
  const _RoomTile({required this.room, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasUnread = room.unreadCount > 0;
    final preview   = _preview();

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
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                                color: const Color(0xFF111B21),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: hasUnread ? C.green : const Color(0xFF8696A0),
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                color: hasUnread
                                    ? const Color(0xFF111B21)
                                    : const Color(0xFF8696A0),
                                fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (hasUnread)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: C.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                room.unreadCount > 99 ? '99+' : '${room.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, indent: 74, color: Color(0xFFE9EDEF)),
        ],
      ),
    );
  }

  String _preview() {
    if (room.lastMessage == null) return 'No messages yet';
    if (room.isGroup && room.lastMessageSender != null) {
      return '${room.lastMessageSender}: ${room.lastMessage}';
    }
    return room.lastMessage!;
  }
}

// ─── Empty state ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String name;
  const _EmptyState({required this.name});

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.22),
          Center(
            child: Column(children: [
              Container(
                width: 88, height: 88,
                decoration: const BoxDecoration(
                  color: Color(0xFFE7F8F5), shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded,
                    size: 44, color: C.teal),
              ),
              const SizedBox(height: 20),
              Text('Hey, $name!',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF111B21))),
              const SizedBox(height: 8),
              const Text('Tap  to start chatting',
                  style: TextStyle(fontSize: 15, color: Color(0xFF8696A0))),
            ]),
          ),
        ],
      );
}

// ─── New chat sheet ─────────────────────────────────────────────────────────

class _NewChatSheet extends StatefulWidget {
  final int initialTab;
  final void Function(User) onDm;
  final void Function(String, List<String>) onGroup;
  const _NewChatSheet({required this.initialTab, required this.onDm, required this.onGroup});

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<User>? _users;
  String _q = '';
  final _groupCtrl = TextEditingController();
  final Set<User> _sel = {};
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    context.read<ChatProvider>().allUsers().then((u) {
      if (mounted) setState(() { _users = u; _loading = false; });
    }).catchError((e) {
      if (mounted) setState(() { _err = e.toString(); _loading = false; });
    });
  }

  @override
  void dispose() { _tabs.dispose(); _groupCtrl.dispose(); super.dispose(); }

  List<User> get _filtered => (_users ?? [])
      .where((u) => u.username.toLowerCase().contains(_q.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92, minChildSize: 0.5, expand: false,
      builder: (_, sc) => Column(children: [
        const SizedBox(height: 10),
        Container(
          width: 38, height: 4,
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 6),
        TabBar(
          controller: _tabs,
          labelColor: C.teal,
          unselectedLabelColor: const Color(0xFF8696A0),
          indicatorColor: C.teal, indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [Tab(text: 'New Chat'), Tab(text: 'New Group')],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search name…',
              hintStyle: const TextStyle(color: Color(0xFFADB5BC), fontSize: 15),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFADB5BC), size: 22),
              filled: true, fillColor: const Color(0xFFF0F2F5),
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            _dmTab(sc),
            _groupTab(sc),
          ]),
        ),
      ]),
    );
  }

  Widget _dmTab(ScrollController sc) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: C.teal));
    if (_err != null) return Center(child: Text(_err!, style: const TextStyle(color: Colors.red)));
    if (_filtered.isEmpty) return const Center(
      child: Text('No users found', style: TextStyle(color: Color(0xFF8696A0))));
    return ListView.builder(
      controller: sc, itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final u = _filtered[i];
        return ListTile(
          leading: UserAvatar(name: u.username, colorHex: u.avatarColor),
          title: Text(u.username, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
          onTap: () => widget.onDm(u),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        );
      },
    );
  }

  Widget _groupTab(ScrollController sc) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: TextField(
          controller: _groupCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Group name',
            hintStyle: const TextStyle(color: Color(0xFFADB5BC)),
            prefixIcon: const Icon(Icons.group_outlined, color: Color(0xFFADB5BC)),
            filled: true, fillColor: const Color(0xFFF0F2F5),
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      if (_sel.isNotEmpty)
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: _sel.map((u) => Padding(
              padding: const EdgeInsets.only(right: 6, top: 4),
              child: Chip(
                avatar: UserAvatar(name: u.username, colorHex: u.avatarColor, radius: 11),
                label: Text(u.username, style: const TextStyle(fontSize: 13)),
                deleteIconColor: const Color(0xFF8696A0),
                onDeleted: () => setState(() => _sel.remove(u)),
                backgroundColor: const Color(0xFFE7F8F5),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            )).toList(),
          ),
        ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: C.teal))
            : ListView.builder(
                controller: sc, itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final u = _filtered[i];
                  final sel = _sel.contains(u);
                  return InkWell(
                    onTap: () => setState(() => sel ? _sel.remove(u) : _sel.add(u)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      child: Row(children: [
                        UserAvatar(name: u.username, colorHex: u.avatarColor),
                        const SizedBox(width: 14),
                        Expanded(child: Text(u.username,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16))),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sel ? C.teal : Colors.transparent,
                            border: Border.all(color: sel ? C.teal : const Color(0xFFCDD5DB), width: 2),
                          ),
                          child: sel ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                        ),
                      ]),
                    ),
                  );
                },
              ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _sel.isNotEmpty && _groupCtrl.text.trim().isNotEmpty
                  ? () => widget.onGroup(
                        _groupCtrl.text.trim(),
                        _sel.map((u) => u.id).toList(),
                      )
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: C.green,
                disabledBackgroundColor: const Color(0xFFB0D5C0),
                foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: Text(
                _sel.isEmpty
                    ? 'Select at least one member'
                    : 'Create group · ${_sel.length} member${_sel.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
