import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:recase/recase.dart';

const outputDefault = './assets/l10n/';

void main(List<String> arguments) {
  final Directory outputDir = Directory(outputDefault);

  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  Map<String, String> allMessages = {};

  final skipFiles = ['generated'];

  recursiveFolderCopySync(source: './lib/', skipFiles: skipFiles, allMessages: allMessages);

  final outputFile = File(path.join(outputDir.path, "string_extractor.arb"));
  const encoder = JsonEncoder.withIndent("  ");

  outputFile.writeAsStringSync(encoder.convert(allMessages));
}

void recursiveFolderCopySync(
    {required String source,
    required List<String> skipFiles,
    required Map<String, String> allMessages}) {
  Directory directory = Directory(source);

  var skipWords = ['dart:ui', 'dart:io'];
  final finder = DartStringFinder(skipWords);
  directory.listSync().forEach((element) {
    final shouldSkip = skipWords.contains(path.basename(element.path));
    if (element is File) {
      if (path.extension(element.path) == ".dart" && !shouldSkip) {
        String content = element.readAsStringSync();
        final stringsFounded = finder.findHardCodedStrings(content);
        if (stringsFounded.isNotEmpty) {
          print(stringsFounded);

          if (content.contains("context")) {
            content += "package:path/path.dart;\n$content";
            for (final element in stringsFounded) {
              allMessages[element.camelCase] = element;

              content = content.replaceAll(
                  '"$element"', "S.of(context).${element.camelCase}");
              content = content.replaceAll(
                  "'$element'", "S.of(context).${element.camelCase}");
            }
          }
        }
      }
    } else if (element is Directory && !shouldSkip) {
      recursiveFolderCopySync(
          source: element.path, skipFiles: skipFiles, allMessages: allMessages);
    }
  });
}

class DartStringFinder {
  List<String> skipWords;

  DartStringFinder(this.skipWords);

  final regex = RegExp('".*?"');
  final regexDart = RegExp("'.*?'");

  String extractHardCodedString(String it, String input) =>
      it.replaceAll("\"", "").replaceAll("'", "");

  bool shouldInclude(String it) =>
      !it.contains("assets") && !it.contains(".png") && !it.contains(".jpeg");

  List<String> findHardCodedStrings(String content) {
    Iterable<RegExpMatch> result = regex.allMatches(content);

    final strings = <String>[];

    for (var element in result) {
      final string =
          extractHardCodedString(element.group(0) ?? "", element.input);

      final jsonParamAccessString =
          element.input.codeUnitAt(element.start - 1) == '['.codeUnits.first &&
              element.input.codeUnitAt(element.end) == ']'.codeUnits.first;
      final jsonParamSetString =
          element.input.codeUnitAt(element.end) == ':'.codeUnits.first;
      final uselessArgs = string.startsWith("\${") && string.endsWith("}");

      if (shouldInclude(string) &&
          !jsonParamSetString &&
          !jsonParamAccessString &&
          !uselessArgs) {
        strings.add(string);
      }
    }

    Iterable<RegExpMatch> res1 = regexDart.allMatches(content);

    for (final e in res1) {
      final string = extractHardCodedString(e.group(0) ?? "", e.input);

      final jsonParamAccessString =
          e.input.codeUnitAt(e.start - 1) == '['.codeUnits.first &&
              e.input.codeUnitAt(e.end) == ']'.codeUnits.first;
      final jsonParamSetString =
          e.input.codeUnitAt(e.end) == ':'.codeUnits.first;
      final uselessArgs = string.startsWith("\${") && string.endsWith("}");

      if (shouldInclude(string) &&
          !jsonParamSetString &&
          !jsonParamAccessString &&
          !uselessArgs) {
        strings.add(string);
      }
    }

    return strings;
  }
}
