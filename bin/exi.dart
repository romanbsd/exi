import 'dart:io';

import 'package:exi/exi.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run bin/exi.dart <input.exi>');
    exitCode = 64;
    return;
  }

  try {
    final bytes = await File(arguments.single).readAsBytes();
    stdout.writeln(ExiDecoder().decode(bytes).toXmlString());
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = 66;
  } on FormatException catch (error) {
    stderr.writeln('Invalid EXI stream: ${error.message}');
    exitCode = 65;
  } on UnsupportedError catch (error) {
    stderr.writeln(error.message);
    exitCode = 69;
  }
}
