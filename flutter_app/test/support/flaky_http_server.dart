import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// ما يفعله الخادم باتصال واحد. الافتراضي: يخدم الملف كاملاً (أو المدى المطلوب).
class Reply {
  /// يقطع الاتصال فجأة بعد إرسال هذا العدد من بايتات الجسم.
  final int? cutAfter;

  /// يرسل هذا العدد من البايتات ثم يصمت والاتصال مفتوح.
  final int? stallAfter;

  /// يرد بهذه الحالة بلا جسم (503، 404...).
  final int? status;

  /// يتجاهل ترويسة Range ويرسل الملف من أوله بحالة 200.
  final bool ignoreRange;

  /// يحوّل إلى هذا المسار (302).
  final String? redirectTo;

  const Reply({this.cutAfter, this.stallAfter, this.status, this.ignoreRange = false, this.redirectTo});

  static const Reply ok = Reply();
}

class SeenRequest {
  final String path;
  final Map<String, String> headers;
  SeenRequest(this.path, this.headers);

  String? get range => headers['range'];
}

/// خادم HTTP صغير على مقبس خام، ليتحكم الاختبار بكل بايت: يقطع الاتصال في
/// منتصف الملف، يصمت، يرد بأخطاء، يبدّل الملف.
class FlakyHttpServer {
  ServerSocket? _server;
  int port = 0;

  /// الملفات المخدومة: المسار ← (المحتوى، ETag).
  final Map<String, ({Uint8List body, String etag})> files = {};

  /// خطط الاتصالات القادمة بالترتيب؛ حين تفرغ يُخدم كل طلب كاملاً.
  final Queue<Reply> plan = Queue();

  final List<SeenRequest> requests = [];
  final List<Socket> _open = [];

  bool get isRunning => _server != null;

  Future<void> start({int? onPort}) async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, onPort ?? 0);
    port = _server!.port;
    _server!.listen(_handle);
  }

  Future<void> stop() async {
    for (final s in _open.toList()) {
      s.destroy();
    }
    _open.clear();
    await _server?.close();
    _server = null;
  }

  String url(String path) => 'http://127.0.0.1:$port$path';

  void serve(String path, Uint8List body, {String etag = '"v1"'}) => files[path] = (body: body, etag: etag);

  Future<void> _handle(Socket socket) async {
    _open.add(socket);
    final buffer = BytesBuilder();
    late StreamSubscription<Uint8List> sub;
    sub = socket.listen(
      (data) async {
        buffer.add(data);
        final text = latin1.decode(buffer.toBytes());
        final end = text.indexOf('\r\n\r\n');
        if (end < 0) return;
        await sub.cancel();
        try {
          await _respond(socket, text.substring(0, end));
        } catch (_) {
          socket.destroy();
        } finally {
          _open.remove(socket);
        }
      },
      onError: (_) => socket.destroy(),
      cancelOnError: true,
    );
  }

  Future<void> _respond(Socket socket, String head) async {
    final lines = head.split('\r\n');
    final path = lines.first.split(' ')[1];
    final headers = <String, String>{
      for (final line in lines.skip(1))
        if (line.contains(':')) line.substring(0, line.indexOf(':')).trim().toLowerCase(): line.substring(line.indexOf(':') + 1).trim(),
    };
    requests.add(SeenRequest(path, headers));
    final reply = plan.isEmpty ? Reply.ok : plan.removeFirst();

    Future<void> send(String statusLine, Map<String, String> h, [List<int> body = const []]) async {
      final out = StringBuffer('HTTP/1.1 $statusLine\r\n');
      ({...h, 'Connection': 'close'}).forEach((k, v) => out.write('$k: $v\r\n'));
      out.write('\r\n');
      socket.add(latin1.encode(out.toString()));
      if (body.isNotEmpty) socket.add(body);
      await socket.flush();
    }

    if (reply.redirectTo != null) {
      await send('302 Found', {'Location': reply.redirectTo!, 'Content-Length': '0'});
      await socket.close();
      return;
    }
    if (reply.status != null) {
      await send('${reply.status} Status', {'Content-Length': '0'});
      await socket.close();
      return;
    }
    final file = files[path];
    if (file == null) {
      await send('404 Not Found', {'Content-Length': '0'});
      await socket.close();
      return;
    }

    final total = file.body.length;
    var start = 0;
    final range = RegExp(r'bytes=(\d+)-').firstMatch(headers['range'] ?? '');
    final partial = range != null && !reply.ignoreRange;
    if (partial) {
      start = int.parse(range.group(1)!);
      if (start >= total) {
        await send('416 Range Not Satisfiable', {'Content-Range': 'bytes */$total', 'Content-Length': '0'});
        await socket.close();
        return;
      }
    }

    final remaining = total - start;
    final sendCount = reply.cutAfter ?? reply.stallAfter ?? remaining;
    final body = file.body.sublist(start, start + (sendCount < remaining ? sendCount : remaining));
    await send(
      partial ? '206 Partial Content' : '200 OK',
      {
        'Content-Length': '$remaining',
        'ETag': file.etag,
        'Accept-Ranges': 'bytes',
        if (partial) 'Content-Range': 'bytes $start-${total - 1}/$total',
      },
      body,
    );

    if (reply.stallAfter != null) {
      _open.add(socket); // يبقى مفتوحاً صامتاً إلى أن يُغلق الخادم أو العميل
      return;
    }
    if (reply.cutAfter != null && reply.cutAfter! < remaining) {
      socket.destroy();
      return;
    }
    await socket.close();
  }
}

/// بايتات شبه عشوائية ثابتة (نفس البذرة ← نفس المحتوى).
Uint8List pseudoRandomBytes(int length, {int seed = 7}) {
  final out = Uint8List(length);
  var x = seed * 2654435761 % 4294967296;
  for (var i = 0; i < length; i++) {
    x = (x * 1103515245 + 12345) % 4294967296;
    out[i] = (x >> 16) & 0xFF;
  }
  return out;
}
