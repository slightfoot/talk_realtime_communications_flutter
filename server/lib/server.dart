import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:server/extensions.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class Server {
  Server(this.address, this.port);

  final InternetAddress address;
  final int port;

  HttpServer? httpServer;

  Connection? _dbConnection;

  Connection get db => _dbConnection!;

  StreamSubscription<String>? _notificationsSub;

  final _clientWebSockets = <WebSocketChannel>[];

  Future<void> start() async {
    if (httpServer != null) {
      return;
    }

    final handler = Pipeline() //
        .addMiddleware(logRequests())
        .addHandler(_router.call);

    httpServer = await shelf_io.serve(handler, address, port);
    print('Server listening on http://${address.address}:$port');

    _dbConnection = await Connection.open(
      Endpoint(
        host: 'localhost',
        database: 'postgres',
        username: 'postgres',
        password: 'monkey',
      ),
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );

    _notificationsSub = db.channels['event_channel'].listen(
      _onDatabaseNotification,
      onError: (error, stackTrace) {
        print('Notifications stream errored: $error\n$stackTrace');
      },
      cancelOnError: true,
      onDone: () async {
        // attempt reconnection if the server is not shutting down
        print('notifications stream closed');
      },
    );

    await db.listen('event_channel');
  }

  Future<void> stop() async {
    if (httpServer == null) {
      return;
    }
    for (final socket in _clientWebSockets) {
      socket.sink.close();
    }
    _clientWebSockets.clear();
    await db.unlisten('event_channel');
    await _notificationsSub!.cancel();
    await db.close();
    await httpServer!.close();
    httpServer = null;
  }

  void _onDatabaseNotification(String payload) {
    final data = json.decode(payload);
    // do processing with data, iterate WebSocketChannels to find matching clients
    print('notification: $data');
    for (final socket in _clientWebSockets) {
      socket.sink.add(json.encode(data['record']));
    }
  }

  // Configure routes.
  late final _router = Router()
    ..mount('/ws', _webSocketHandler)
    ..get('/', _rootHandler)
    ..get('/messages', _getMessages)
    ..post('/send', _postMessage);

  late final _webSocketHandler = webSocketHandler(
    (WebSocketChannel webSocket) {
      _clientWebSockets.add(webSocket);
    },
  );

  Response _rootHandler(Request req) {
    return Response.ok('I am the server! Fear Me!\n');
  }

  Future<Response> _getMessages(Request request) async {
    final messages = await db.execute(
      Sql.named('SELECT * FROM messages'),
    );
    return Response.ok(json.encode({
      'messages': messages,
    }));
  }

  Future<Response> _postMessage(Request request) async {
    final data = json.decode(await request.readAsString());

    final id = Uuid().v4();
    final result = await db.execute(
      Sql.named(
        'INSERT INTO messages VALUES(@id, @message);',
      ),
      parameters: {
        'id': id,
        'message': data['message'],
      },
    );
    if (result.affectedRows != 1) {
      throw 'something bad';
    }
    return Response.ok('');
  }
}
