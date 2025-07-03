import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> users = [
    {'name': 'Ruffles', 'image': 'assets/images/avatars/avatar2.png'},
    {'name': 'Ruffles', 'image': 'assets/images/avatars/avatar3.png'},
    {'name': 'Ruffles', 'image': 'assets/images/avatars/avatar4.png'},
    {'name': 'SJ', 'image': 'assets/images/avatars/avatar5.png'},
    {'name': 'Ruffles', 'image': 'assets/images/avatars/avatar6.png'},
    {'name': 'Ruffles', 'image': 'assets/images/avatars/avatar7.png'},
    {'name': 'Ruffles', 'image': 'assets/images/avatars/avatar8.png'},
    {'name': 'SJ', 'image': 'assets/images/avatars/avatar9.png'},
    {'name': 'Ruffles', 'image': 'assets/images/avatars/avatar10.png'},
    {'name': 'Ruffles', 'image': 'assets/images/avatars/avatar11.png'},
    {'name': 'Ruffles', 'image': 'assets/images/avatars/avatar12.png'},
    {'name': 'SJ', 'image': 'assets/images/avatars/avatar10.png'},
  ];

  // Track selected users
  final Set<int> _selectedUsers = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Toggle user selection
  void _toggleUserSelection(int index) {
    setState(() {
      if (_selectedUsers.contains(index)) {
        _selectedUsers.remove(index);
      } else {
        _selectedUsers.add(index);
      }
    });
  }

  // Handle send action
  void _handleSend() {
    if (_selectedUsers.isNotEmpty) {
      // Perform the send action (e.g., share content with selected users)
      print(
        'Sharing with users: ${_selectedUsers.map((index) => users[index]['name']).toList()}',
      );
      Navigator.pop(context); // Close the bottom sheet after sending
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6, // Adjust height as needed
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search users...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[200],
            ),
            onChanged: (value) {
              // Implement search logic here if needed
            },
          ),
          const Gap(16),
          // Title
          const Text(
            'Share to',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Gap(16),
          // Grid of Users
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedUsers.contains(index);
                return GestureDetector(
                  onTap: () => _toggleUserSelection(index),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: AssetImage(users[index]['image']!),
                            backgroundColor: const Color.fromARGB(
                              179,
                              231,
                              231,
                              231,
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withOpacity(0.4),
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.blue,
                                size: 30,
                              ),
                            ),
                          if (users[index]['name'] == 'SJ')
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Colors.purple,
                                  child: Icon(
                                    Icons.sunny,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Gap(4),
                      Text(
                        users[index]['name']!,
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Gap(16),
          // Send Button
          _selectedUsers.isNotEmpty
              ? SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedUsers.isNotEmpty ? _handleSend : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedUsers.isNotEmpty ? Colors.blue : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Send',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                )
              : Container(),
          const Gap(16),
        ],
      ),
    );
  }
}