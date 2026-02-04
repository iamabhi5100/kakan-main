import 'package:flutter/material.dart';
import 'package:kakan/config/theme.dart';

class BottomNavigationWidget extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String? profileImage;

  const BottomNavigationWidget({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.profileImage,
  });

  @override
  State<BottomNavigationWidget> createState() => _BottomNavigationWidgetState();
}

class _BottomNavigationWidgetState extends State<BottomNavigationWidget> {
  Widget _buildProfileIcon(bool isActive) {
    return Container(
      width: 23,
      height: 23,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: isActive
            ? Border.all(
                color: appTheme.primaryColor,
                width: 2,
              )
            : null,
        image: DecorationImage(
          image: widget.profileImage != null && widget.profileImage!.isNotEmpty
              ? NetworkImage(widget.profileImage!)
              : const AssetImage('assets/images/avataruser.png') as ImageProvider,
          fit: BoxFit.cover,
        ),
        color: Colors.grey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: widget.currentIndex,
        onTap: widget.onTap,
        backgroundColor: Colors.white,
        selectedItemColor: appTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/myfiles.png',
              width: 24,
              height: 24,
              color: widget.currentIndex == 1 ? appTheme.primaryColor : Colors.grey,
            ),
            label: 'Files',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/post.png',
              width: 24,
              height: 24,
              color: widget.currentIndex == 2 ? appTheme.primaryColor : Colors.grey,
            ),
            label: 'Post',
            backgroundColor: Colors.indigo,
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.video_library),
            label: 'Trims',
          ),
          BottomNavigationBarItem(
            icon: _buildProfileIcon(false),
            activeIcon: _buildProfileIcon(true),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}