import 'package:flutter/material.dart';

class SearchbarYoutubeWidget extends StatefulWidget {
  final Function(String) onSearch;

  const SearchbarYoutubeWidget({Key? key, required this.onSearch})
      : super(key: key);

  @override
  State<SearchbarYoutubeWidget> createState() => _SearchbarYoutubeWidgetState();
}

class _SearchbarYoutubeWidgetState extends State<SearchbarYoutubeWidget> {
  final TextEditingController _controller = TextEditingController();

  void _submitSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    widget.onSearch(query);
    print('SearchbarYoutubeWidget: Search triggered for query: $query');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? Colors.cyanAccent : Colors.blue[300]!;
    final cardColor = isDark ? Colors.grey[850]! : Colors.white;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          colors: [
            accentColor.withOpacity(0.2),
            accentColor.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SearchBar(
        controller: _controller,
        hintText: 'Search for videos',
        // show “Search” on the keyboard
        textInputAction: TextInputAction.search,
        // handle keyboard “Search”/Enter
        onSubmitted: _submitSearch,
        backgroundColor: MaterialStateProperty.all(cardColor),
        elevation: MaterialStateProperty.all(0),
        shape: MaterialStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: accentColor.withOpacity(0.5),
              width: 1,
            ),
          ),
        ),
        hintStyle: MaterialStateProperty.all(
          TextStyle(
            fontFamily: 'Product Sans',
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 16,
          ),
        ),
        textStyle: MaterialStateProperty.all(
          TextStyle(
            fontFamily: 'Product Sans',
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        ),
        trailing: [
          IconButton(
            icon: Icon(
              Icons.search,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            onPressed: () {
              if (_controller.text.isNotEmpty) {
                widget.onSearch(_controller.text);
                print('SearchbarYoutubeWidget: Search triggered for query: ${_controller.text}');
              }
            },
          ),
        ],
      ),
    );
  }
}
