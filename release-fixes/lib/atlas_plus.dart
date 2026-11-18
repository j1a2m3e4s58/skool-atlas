import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'student_journey.dart';

const plusHost = 'https://ghana-tertiary-atlas.ghana-tertiary-atlas-host.workers.dev';

class AtlasPlusClient {
  final http.Client client;
  final String host;
  String? workspace, key;
  int revision = 0;
  AtlasPlusClient({http.Client? client, this.host = plusHost}) : client = client ?? http.Client();
  String get accessCode => '$workspace.$key';
  bool get connected => workspace != null && key != null;
  void disconnect() { workspace = null; key = null; revision = 0; }
  void close() { disconnect(); client.close(); }
  Future<Map<String, dynamic>> request(String action, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$host/api/plus/$workspace/$action');
    final headers = {'Content-Type':'application/json', if (key != null) 'Authorization':'Bearer $key'};
    final response = await (body == null ? client.get(uri, headers:headers) : client.post(uri, headers:headers, body:jsonEncode(body))).timeout(const Duration(seconds:25));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) throw StateError(data['error'] as String? ?? 'Cloud request failed. Your device data is unchanged.');
    return data;
  }
  Future<void> create() async {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64; bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2,'0')).join();
    workspace = '${hex.substring(0,8)}-${hex.substring(8,12)}-${hex.substring(12,16)}-${hex.substring(16,20)}-${hex.substring(20)}';
    try { final data = await request('create', {'consent':true}); key = data['key'] as String; revision = 0; } catch (_) { disconnect(); rethrow; }
  }
  Future<Map<String,dynamic>> connect(String code) async {
    final parts = code.trim().split('.');
    if (parts.length != 2 || !RegExp(r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$').hasMatch(parts[0]) || !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(parts[1])) throw const FormatException('Enter the complete private access code.');
    workspace = parts[0]; key = parts[1];
    try { return await load(); } catch (_) { disconnect(); rethrow; }
  }
  Future<Map<String,dynamic>> load() async { final data = await request('snapshot'); revision = data['revision'] as int; return data; }
  Future<void> save(StudentJourney journey) async {
    final result = await request('snapshot', {'revision':revision,'snapshot':journeySnapshot(journey)});
    revision = result['revision'] as int;
  }
}

Map<String,dynamic> journeySnapshot(StudentJourney journey) => {
  'schemaVersion':1,
  'applications':journey.applications.map((a)=>a.toJson()).toList(),
  'comparison':journey.comparison,
};

Future<void> restoreJourney(StudentJourney journey, Map<String,dynamic> snapshot) async {
  if (snapshot['schemaVersion'] != 1 || snapshot['applications'] is! List || (snapshot['applications'] as List).length > 50 || snapshot['comparison'] is! List) throw const FormatException('Unsupported backup');
  final plans = [for (final row in snapshot['applications']) ApplicationPlan.fromJson(Map<String,dynamic>.from(row))];
  final comparison = List<String>.from(snapshot['comparison']);
  if (plans.map((a)=>a.id).toSet().length != plans.length || comparison.length > 4 || comparison.any((id)=>!plans.any((a)=>a.id==id))) throw const FormatException('Invalid backup');
  final oldPlans = journey.applications, oldComparison = journey.comparison;
  journey.applications = plans; journey.comparison = comparison;
  try { await journey.persist(); } catch (_) { journey.applications=oldPlans; journey.comparison=oldComparison; rethrow; }
}

List<Map<String,dynamic>> personalResources(StudentJourney journey, {DateTime? now}) {
  final schools = journey.applications.map((a)=>a.institutionId).toSet();
  if (schools.isEmpty) return [];
  final rows = <Map<String,dynamic>>[];
  for (final section in ['deadlines','scholarships']) {
    for (final raw in journey.resources[section] as List? ?? []) {
      final row = Map<String,dynamic>.from(raw);
      if (schools.contains(row['institutionId']) && !resourceIsClosed(row, now:now)) rows.add({...row,'kind':section});
    }
  }
  rows.sort((a,b)=>(a['date'] as String? ?? '9999').compareTo(b['date'] as String? ?? '9999'));
  return rows;
}

bool canRemindResource(Map<String,dynamic> row, {DateTime? now}) => row['date'] != null && row['status'] != 'needs_source_review' && !resourceIsClosed(row, now:now);
