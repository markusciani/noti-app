abstract class RealtimeUpdates {
  Stream<T> watch<T>(String channel, T Function(dynamic payload) decode);
}
