import 'package:postgres/postgres.dart';

/// Postgres Listen/Notify extension
extension PostgreSQLConnectionListenNotify on Connection {
  Future<void> listen(String channel) async {
    if (isOpen) {
      await execute('LISTEN $channel;');
    }
  }

  Future<void> unlisten(String channel) async {
    if (isOpen) {
      await execute('UNLISTEN $channel;');
    }
  }

  Future<void> notify(String channel, String message) async {
    if (isOpen) {
      await execute("NOTIFY $channel, '$message';");
    }
  }
}
