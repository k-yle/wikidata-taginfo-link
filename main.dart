import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

extension MapPut on Map {
  void put(String key, String? value) {
    if (value != null) this[key] = value;
  }
}

final REPO_URL = 'https://github.com/k-yle/wikidata-taginfo-link';

Future<void> main() async {
  final query = await File('query.sparql').readAsString();

  final response = await http.get(
    Uri.parse(
      'https://qlever.cs.uni-freiburg.de/api/wikidata?query=${Uri.encodeComponent(query)}',
    ),
    headers: {
      'Accept': 'application/sparql-results+json',
      'User-Agent': REPO_URL,
    },
  );

  if (!response.body.startsWith("{")) {
    print(response.body);
    exit(1);
  }

  final tags = (jsonDecode(response.body)['results']['bindings'] as List)
      .map((item) {
        final kv = (item['value']['value'] as String).split('=');
        final qID = (item['item']['value'] as String).split('/').last;
        final pID = (item['prop']['value'] as String).split('/').last;

        final struct = <String, String>{};
        struct.put('key', kv[0]);
        struct.put('value', kv.length == 2 ? kv[1] : null);
        struct.put('description',
            '[${qID}] ${item['itemLabel']?['value'] ?? ''}'.trim());
        struct.put('doc_url', '${item['item']['value']}#$pID');
        struct.put('icon_url',
            item['logoo']?['value'] ?? item['flagg']?['value'] ?? null);
        return struct;
      })
      .whereType<Map<String, dynamic>>()
      .toList();

  final output = {
    'data_format': 1,
    'data_url': REPO_URL + '/raw/gh-pages/taginfo.json',
    'project': {
      'name': 'Wikidata',
      'description':
          'This list contains all Wikidata items and properties which are linked to an OSM tag or OSM key using properties P13786 or P1282',
      'project_url': 'https://wikidata.org',
      'doc_url': 'https://wikidata.org/wiki/Property_talk:P1282',
      'contact_name': REPO_URL,
      'contact_email': REPO_URL + '/issues',
      'icon_url': 'https://wikidata.org/static/favicon/wikidata.ico',
    },
    'tags': tags,
  };

  final outDir = Directory('out');
  if (!await outDir.exists()) await outDir.create(recursive: true);
  await File(
    'out/taginfo.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(output));
}
