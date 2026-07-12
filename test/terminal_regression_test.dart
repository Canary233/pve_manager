import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

void main() {
  test(
    'terminal survives scroll-region reverse index followed by line feeds',
    () {
      final terminal = Terminal(maxLines: 10000);

      terminal
        ..resize(56, 27)
        ..resize(105, 35)
        ..write('\x1b[?2026h\x1b[1;35r\x1b[1;1H')
        ..write('\x1bM\x1bM\x1bM\x1bM\x1bM\x1bM\x1bM\x1bM\x1bM')
        ..write('\x1b[r\x1b[1;9r\x1b[1;1H\r\n');

      for (var i = 0; i < 12; i++) {
        terminal.write('\x1b[;m\x1b[K\x1b[m\x1b[m\x1b[0m\r\n');
      }
    },
  );
}
