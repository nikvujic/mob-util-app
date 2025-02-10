import 'package:flutter/material.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  List<Map<String, String>> notes = [
    {'title': 'First Note', 'date': '2024-02-10'},
    {'title': 'Second Note', 'date': '2024-02-11'},
    {'title': 'Meeting Notes', 'date': '2024-02-12'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text('Notes', style: TextStyle(color: Colors.white)),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            color: Colors.grey[800],
            iconColor: Colors.white,
            onSelected: (value) {
              if (value == 'export') {
                // Handle export
              } else if (value == 'import') {
                // Handle import
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'export',
                  child: Text('Export Notes', style: TextStyle(color: Colors.white)),
                ),
                const PopupMenuItem(
                  value: 'import',
                  child: Text('Import Notes', style: TextStyle(color: Colors.white)),
                ),
              ];
            },
          ),
        ],
      ),
      body: notes.isEmpty
        ? const Center(
          child: Text('No notes', style: TextStyle(color: Colors.white54, fontSize: 16)),
        )
      : Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListView.builder(
          itemCount: notes.length,
          physics: RangeMaintainingScrollPhysics(),
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Card(
                color: Colors.grey[850],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
                margin: EdgeInsets.zero,
                child: ListTile(
                  title: Text(notes[index]['title']!, style: TextStyle(color: Colors.white)),
                  subtitle: Text(notes[index]['date']!, style: TextStyle(color: Colors.grey[400])),
                  onTap: () {
                    // Navigate to note details page
                  },
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        shape: const CircleBorder(),
        onPressed: () {
          // Navigate to add note page
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}