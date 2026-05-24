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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(room: room)),
    );
  }

  void _showNewChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NewChatSheet(
        onDmSelected: (user) async {
          Navigator.pop(context);
          final room = await context.read<ChatProvider>().startDm(user.id);
          if (mounted) _openRoom(room);
        },
        onGroupCreate: (name, members) async {
          Navigator.pop(context);
          final room = await context.read<ChatProvider>().createGroup(name: name, memberIds: members.map((u) => u.id).toList());
          if (mounted) _openRoom(room);
        },
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final now = DateTime.now();
    final local = dt.toLocal();
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      return DateFormat('HH:mm').format(local);
    }
    return DateFormat('dd/MM').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final chat = context.watch<ChatProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SimpleChat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showLogoutDialog(context, auth),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewChat,
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.chat, color: Colors.white),
      ),
      body: chat.roomsLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => chat.loadRooms(),
              child: chat.rooms.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('No chats yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('Tap the chat button to start a conversation', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: chat.rooms.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                      itemBuilder: (ctx, i) {
                        final room = chat.rooms[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: UserAvatar(
                            name: room.name,
                            colorHex: room.avatarColor,
                            radius: 24,
                          ),
                          title: Text(
                            room.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          subtitle: room.lastMessage != null
                              ? Text(
                                  room.lastMessage!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                                )
                              : null,
                          trailing: room.lastMessageAt != null
                              ? Text(
                                  _formatTime(room.lastMessageAt),
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                )
                              : null,
                          onTap: () => _openRoom(room),
                        );
                      },
                    ),
            ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              auth.logout();
            },
            child: const Text('Sign out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _NewChatSheet extends StatefulWidget {
  final void Function(User user) onDmSelected;
  final void Function(String name, List<User> members) onGroupCreate;

  const _NewChatSheet({required this.onDmSelected, required this.onGroupCreate});

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<User>? _users;
  String _search = '';
  final Set<User> _selectedForGroup = {};
  final _groupNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await context.read<ChatProvider>().getAllUsers();
    if (mounted) setState(() => _users = users);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _groupNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = (_users ?? []).where((u) => u.username.toLowerCase().contains(_search.toLowerCase())).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          TabBar(
            controller: _tabController,
            tabs: const [Tab(text: 'New Chat'), Tab(text: 'New Group')],
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Direct message tab
                _users == null
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final user = filtered[i];
                          return ListTile(
                            leading: UserAvatar(name: user.username, colorHex: user.avatarColor),
                            title: Text(user.username),
                            onTap: () => widget.onDmSelected(user),
                          );
                        },
                      ),

                // Group creation tab
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: TextField(
                        controller: _groupNameCtrl,
                        decoration: InputDecoration(
                          hintText: 'Group name',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    if (_selectedForGroup.isNotEmpty)
                      SizedBox(
                        height: 56,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: _selectedForGroup.map((u) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text(u.username),
                              onDeleted: () => setState(() => _selectedForGroup.remove(u)),
                              avatar: UserAvatar(name: u.username, colorHex: u.avatarColor, radius: 12),
                            ),
                          )).toList(),
                        ),
                      ),
                    Expanded(
                      child: _users == null
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final user = filtered[i];
                                final selected = _selectedForGroup.contains(user);
                                return CheckboxListTile(
                                  value: selected,
                                  onChanged: (_) => setState(() {
                                    if (selected) {
                                      _selectedForGroup.remove(user);
                                    } else {
                                      _selectedForGroup.add(user);
                                    }
                                  }),
                                  title: Text(user.username),
                                  secondary: UserAvatar(name: user.username, colorHex: user.avatarColor),
                                  activeColor: AppColors.primary,
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _selectedForGroup.isEmpty || _groupNameCtrl.text.trim().isEmpty
                              ? null
                              : () => widget.onGroupCreate(
                                    _groupNameCtrl.text.trim(),
                                    _selectedForGroup.toList(),
                                  ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          child: Text(
                            'Create Group (${_selectedForGroup.length} member${_selectedForGroup.length == 1 ? '' : 's'})',
                          ),
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
    );
  }
}
