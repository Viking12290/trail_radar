import "dart:io";
import "dart:convert";

class P2PService {
  RawDatagramSocket? _discoverySocket;
  RawDatagramSocket? _dmSocket;
  int myDmPort = 0;
 
  Function(String peer, InternetAddress address, int port)? onPeerDiscovered;
  Function(String message, InternetAddress address, int replyPort)? onMessageReceived;
 
  Future<void> startService() async {
    try {
      _dmSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      myDmPort = _dmSocket!.port;
     
      _dmSocket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? datagram = _dmSocket?.receive();
          if (datagram != null) {
            String msg = utf8.decode(datagram.data);
            if (onMessageReceived != null) {
              // Pass datagram.port as the exact return reply port
              onMessageReceived!(msg, datagram.address, datagram.port);
            }
          }
        }
      });

      _discoverySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        45454,
        reuseAddress: true,
        reusePort: true,
      );
      _discoverySocket?.broadcastEnabled = true;
     
      _discoverySocket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? datagram = _discoverySocket?.receive();
          if (datagram != null) {
            String dataStr = utf8.decode(datagram.data);
            final parts = dataStr.split("|");
            if (parts.length == 2) {
              String handle = parts[0];
              int peerDmPort = int.tryParse(parts[1]) ?? 0;
              if (peerDmPort != myDmPort && onPeerDiscovered != null) {
                onPeerDiscovered!(handle, datagram.address, peerDmPort);
              }
            }
          }
        }
      });
    } catch (e) {
      print("P2P Service Error: $e");
    }
  }

  void broadcastPresence(String handle) {
    if (_discoverySocket == null) return;
    String payload = "$handle|$myDmPort";
    List<int> data = utf8.encode(payload);
    try {
      _discoverySocket?.send(data, InternetAddress("255.255.255.255"), 45454);
      _discoverySocket?.send(data, InternetAddress("127.0.0.1"), 45454);
    } catch (e) {
      print("Broadcast Error: $e");
    }
  }

  void sendDirectMessage(InternetAddress address, int port, String message) {
    if (_dmSocket == null || port == 0) return;
    List<int> data = utf8.encode(message);
    try {
      _dmSocket?.send(data, address, port);
    } catch (e) {
      print("DM Send Error: $e");
    }
  }

  void stop() {
    _discoverySocket?.close();
    _dmSocket?.close();
  }
}
