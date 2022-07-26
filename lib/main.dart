import 'package:flutter/material.dart';
import 'package:socket/ws.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const title = 'WebSocket Demo';
    return const MaterialApp(
      title: title,
      home: MyHomePage(
        title: title,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
  });

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var incomingMessage = "";
  final TextEditingController _controller = TextEditingController();
  WebSocketChannel? _channel;

  WS? ws;


  @override
  void initState() {
    super.initState();
    ws = WS(
        'wss://sockettest.v-xplore.com',
      true,
      onData: (_,data){
          print(data);
          setState(() {
            if(data is String){
              incomingMessage = data;
            }
          });
      }
    )..connect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Form(
              child: TextFormField(
                controller: _controller,
                decoration: const InputDecoration(labelText: 'Send a message'),
              ),
            ),
            ElevatedButton(
                onPressed: (){
                  ws?.disconnect();
                },
                child: Text("Disconnect")
            ),
            const SizedBox(height: 24),
            Text(incomingMessage)
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendMessage,
        tooltip: 'Send message',
        child: const Icon(Icons.send),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  void _sendMessage() {
    /*if (_controller.text.isNotEmpty) {
      _channel?.sink.add(_controller.text);
    }*/
    ws?.send(_controller.text);
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _controller.dispose();
    super.dispose();
  }
}