import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late Future<void> _connecting;

  final _messages = <List<String>>[];

  StreamSubscription? _sub;

  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _connecting = startConnection();
  }

  Future<void> startConnection() async {
    final response = await http.get(
      Uri.parse('http://localhost:8080/messages'),
    );
    if (response.statusCode != HttpStatus.ok) {
      throw 'error: ${response.statusCode}';
    }
    final data = json.decode(response.body);
    final messages = (data['messages'] as List).cast();
    for (final message in messages) {
      print('message: $message');
      _messages.add((message as List).cast<String>());
    }

    final wsUrl = Uri.parse('ws://localhost:8080/ws');
    final channel = WebSocketChannel.connect(wsUrl);

    await channel.ready;

    _sub = channel.stream.listen(_onMessageReceived);
  }

  void _onMessageReceived(message) {
    setState(() {
      _messages.add((json.decode(message) as Map) //
          .cast<String, String>()
          .values
          .toList());
    });
  }

  Future<void> _send() async {
    final message = _messageController.text;
    _messageController.clear();
    final response = await http.post(
      Uri.parse('http://localhost:8080/send'),
      body: json.encode({'message': message}),
    );
    if (response.statusCode != HttpStatus.ok) {
      throw 'error: ${response.statusCode}';
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Material(
        child: FutureBuilder(
            future: _connecting,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: _messages.length,
                      itemBuilder: (BuildContext context, int index) {
                        final message = _messages[index];
                        return ListTile(
                          key: Key(message[0]),
                          title: Text(message[1]),
                        );
                      },
                    ),
                  ),
                  Material(
                    color: Colors.grey,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _messageController,
                            onFieldSubmitted: (_) {
                              _send();
                            },
                            textInputAction: TextInputAction.send,
                          ),
                        ),
                        IconButton(
                          onPressed: _send,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
      ),
    );
  }
}
