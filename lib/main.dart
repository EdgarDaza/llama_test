import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Llama Local Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, String>> chatMessages = [
    {"role": "system", "content": "You are a helpful assistant."},
  ];

  Future<void> query(String prompt) async {
    final message = {
      "role": "user",
      "content": prompt,
    };

    chatMessages.add(message);

    final data = {
      "model": "llama3.2",
      "messages": chatMessages,
      "stream": false,
    };

    try {
      final response = await http.post(
        Uri.parse("http://localhost:11434/api/chat"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        chatMessages.add(
          {
            "role": "system",
            "content": responseData["message"]["content"],
          },
        );

        _controller.clear();
        setState(() {});
      } else {
        chatMessages.remove(message);
        setState(() {});
      }
    } catch (e) {
      chatMessages.remove(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Llama Chat"),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: chatMessages.length,
                  itemBuilder: (context, index) {
                    if (index == 0) return SizedBox.shrink();
                    final message = chatMessages[index];
                    return Align(
                      alignment: message["role"] == 'system'
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: message["role"] == 'system'
                              ? Colors.grey[900]
                              : Colors.deepPurple[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(message["content"] ?? ''),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: "Enter your prompt",
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      if (_controller.text.isNotEmpty) {
                        query(_controller.text);
                      }
                    },
                    icon: Icon(
                      Icons.send,
                      color: Colors.lightGreen,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}