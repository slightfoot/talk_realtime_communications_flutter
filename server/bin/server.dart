import 'dart:io';

import 'package:server/server.dart';

void main(List<String> args) async {
  final ip = InternetAddress.loopbackIPv4; // or InternetAddress.anyIPv4;
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = Server(ip, port);
  server.start();
}
