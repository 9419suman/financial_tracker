import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/message_provider.dart';
import '../widgets/message_tile.dart';
import 'message_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load messages when the screen is first built
    Future.microtask(() {
      context.read<MessageProvider>().loadMessages();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Financial Tracker',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterBar(context),
          _buildSearchBar(context),
          Expanded(
            child: _buildMessageList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final provider = Provider.of<MessageProvider>(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Filter Messages',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ChoiceChip(
            label: Text('All Messages'),
            selected: provider.currentFilter == MessageFilter.all,
            onSelected: (selected) {
              if (selected) {
                provider.setFilter(MessageFilter.all);
              }
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text('With Amount'),
            selected: provider.currentFilter == MessageFilter.withAmount,
            onSelected: (selected) {
              if (selected) {
                provider.setFilter(MessageFilter.withAmount);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search messages...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              context.read<MessageProvider>().setSearchQuery('');
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade200,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        onChanged: (value) {
          context.read<MessageProvider>().setSearchQuery(value);
        },
      ),
    );
  }

  Widget _buildMessageList(BuildContext context) {
    final provider = Provider.of<MessageProvider>(context);
    
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (provider.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.message,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No messages found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            if (provider.currentFilter == MessageFilter.withAmount)
              Text(
                'Try changing the filter to "All Messages"',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                provider.loadMessages();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () => provider.loadMessages(),
      child: ListView.builder(
        itemCount: provider.messages.length,
        padding: const EdgeInsets.only(bottom: 16),
        itemBuilder: (context, index) {
          final message = provider.messages[index];
          return MessageTile(
            message: message,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MessageDetailScreen(message: message),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
