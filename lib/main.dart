import 'dart:io';
import 'package:flutter/material.dart';
import 'services/p2p_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:url_launcher/url_launcher.dart';


void main() => runApp(const TrailRadarApp());

class TrailRadarApp extends StatelessWidget {
  const TrailRadarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trail Radar',
      theme: ThemeData.dark(useMaterial3: true),
      home: const EulaScreen(),
    );
  }
}

class EulaScreen extends StatefulWidget {
  const EulaScreen({super.key});

  @override
  State<EulaScreen> createState() => _EulaScreenState();
}

class _EulaScreenState extends State<EulaScreen> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trail Radar - Mandatory EULA')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: SingleChildScrollView(
                child: Text(
                  'END USER LICENSE AGREEMENT\n\n'
                  'By using Trail Radar, you agree this software is provided as-is, '
                  'using local P2P discovery for cyclists. You are solely responsible '
                  'for your safety. No central tracking occurs.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
            CheckboxListTile(
              title: const Text('I accept the terms'),
              value: _accepted,
              onChanged: (v) => setState(() => _accepted = v ?? false),
            ),
            ElevatedButton(
              onPressed: _accepted
                  ? () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const P2PRadarScreen()),
                      )
                  : null,
              child: const Text('Continue to P2P Radar'),
            ),
            SizedBox(height: 20),
            GestureDetector(
              onDoubleTap: () async {
                final Uri url = Uri.parse('https://buymeacoffee.com/Viking12290');
                if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                  // Fallback if launch fails silently
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.withOpacity(0.6), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.coffee, color: Colors.amber, size: 16),
                    SizedBox(width: 6),
                    Text(
                      "Double-tap to support development",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ]
                  ),
                ),
              ),
	    ]
	  ),
        ),
      );
    }
  }
  class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime timestamp;
  ChatMessage({required this.text, required this.isMe, required this.timestamp});
}

class PeerNode {
  final String handle;
  final InternetAddress address;
  final int port;
  final List<ChatMessage> messages = [];
 
  PeerNode({required this.handle, required this.address, required this.port});
 
  String get display => '$handle (${address.address}:$port)';
}

class P2PRadarScreen extends StatefulWidget {
  const P2PRadarScreen({super.key});

  @override
  State<P2PRadarScreen> createState() => _P2PRadarScreenState();
}

class _P2PRadarScreenState extends State<P2PRadarScreen> {
  final P2PService _p2p = P2PService();
  final List<PeerNode> _peers = [];
  String _myHandle = 'Rider';
  final TextEditingController _handleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _myHandle = 'Rider-${DateTime.now().second % 1000}';
    _handleController.text = _myHandle;
    _initP2P();
  }

  void _initP2P() async {
    _p2p.onPeerDiscovered = (handle, address, port) {
      setState(() {
        if (!_peers.any((p) => p.address == address && p.port == port)) {
          _peers.add(PeerNode(handle: handle, address: address, port: port));
        }
      });
    };

    _p2p.onMessageReceived = (msg, address, replyPort) {
      setState(() {
        PeerNode? peer = _peers.firstWhere(
          (p) => p.address == address && p.port == replyPort,
          orElse: () {
            final newPeer = PeerNode(handle: 'Rider-Peer', address: address, port: replyPort);
            _peers.add(newPeer);
            return newPeer;
          },
        );
        peer.messages.add(ChatMessage(text: msg, isMe: false, timestamp: DateTime.now()));
      });
    };

    await _p2p.startService();
    _p2p.broadcastPresence(_myHandle);
  }

  void _updateHandle(String newHandle) {
    setState(() {
      _myHandle = newHandle.isNotEmpty ? newHandle : 'Rider';
    });
    _p2p.broadcastPresence(_myHandle);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Handle updated and broadcasted!')),
    );
  }

  void _openChatScreen(BuildContext context, PeerNode peer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(p2p: _p2p, peer: peer),
      ),
    );
  }

  @override
  void dispose() {
    _p2p.stop();
    _handleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trail Radar Map - Local P2P Active')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.blueGrey,
                  child: Icon(Icons.directions_bike, color: Colors.greenAccent, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _handleController,
                    decoration: const InputDecoration(
                      labelText: 'Cyclist Handle',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _updateHandle(_handleController.text),
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Scanning local network for nearby riders...',
              style: TextStyle(color: Colors.greenAccent, fontSize: 14),
            ),
          ),
          Expanded(
            child: _peers.isEmpty
                ? const Center(
                    child: Text(
                      'No other cyclists found on subnet yet...\nBroadcasting presence on port 45454',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _peers.length,
                    itemBuilder: (context, index) {
                      final peer = _peers[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.blueGrey,
                          child: Icon(Icons.directions_bike, color: Colors.greenAccent),
                        ),
                        title: Text(peer.display),
                        subtitle: Text(
                          peer.messages.isNotEmpty ? peer.messages.last.text : 'No messages yet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (peer.messages.isNotEmpty)
                              Badge(label: Text('${peer.messages.length}')),
                            const SizedBox(width: 8),
                            const Icon(Icons.chat_bubble_outline, color: Colors.greenAccent),
                          ],
                        ),
                        onTap: () => _openChatScreen(context, peer),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final P2PService p2p;
  final PeerNode peer;
  const ChatScreen({super.key, required this.p2p, required this.peer});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();

  void _sendMessage() {
    if (_msgController.text.trim().isEmpty) return;
    String text = _msgController.text.trim();
   
    widget.p2p.sendDirectMessage(widget.peer.address, widget.peer.port, text);
   
    setState(() {
      widget.peer.messages.add(ChatMessage(text: text, isMe: true, timestamp: DateTime.now()));
    });
    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(title: Text('Chat with ${widget.peer.handle}')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.peer.messages.length,
              itemBuilder: (context, index) {
                final msg = widget.peer.messages[index];
                final timeStr = '${twoDigits(msg.timestamp.hour)}:${twoDigits(msg.timestamp.minute)}';
                return Align(
                  alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: msg.isMe ? Colors.blueGrey.shade700 : Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(msg.text, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                          timeStr,
                          style: const TextStyle(fontSize: 10, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.black26,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.greenAccent),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
