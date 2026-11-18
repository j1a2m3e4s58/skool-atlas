import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skoolatlas/atlas_plus.dart';
import 'package:skoolatlas/student_journey.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  test('snapshot exports application data but excludes grades and resource rules',(){
    final journey=StudentJourney()..applications=[ApplicationPlan(id:'one',institutionId:'school',programme:'Course')];
    final data=journeySnapshot(journey);
    expect(data.keys,unorderedEquals(['schemaVersion','applications','comparison']));
    expect(data['applications'],hasLength(1));
  });
  test('restore preserves local grades-independent state and persists plans',()async{
    final journey=StudentJourney()..followChanges=true..baseline={'kept':true};
    final source=StudentJourney()..applications=[ApplicationPlan(id:'one',institutionId:'school',programme:'Course',note:'My note')]..comparison=['one'];
    await restoreJourney(journey,journeySnapshot(source));
    expect(journey.applications.single.note,'My note');
    expect(journey.followChanges,isTrue);expect(journey.baseline,{'kept':true});
    final saved=jsonDecode((await SharedPreferences.getInstance()).getString(StudentJourney.preferenceKey)!);
    expect(saved['comparison'],['one']);
  });
  test('malformed restore leaves current journey untouched',()async{
    final journey=StudentJourney()..applications=[ApplicationPlan(id:'kept',institutionId:'school',programme:'Keep')];
    await expectLater(restoreJourney(journey,{'schemaVersion':1,'applications':[],'comparison':['missing']}),throwsFormatException);
    expect(journey.applications.single.id,'kept');
  });
  test('failed persistence rolls back restored plans',()async{
    final journey=StudentJourney()..applications=[ApplicationPlan(id:'kept',institutionId:'school',programme:'Keep')]..storageError='Storage blocked';
    await expectLater(restoreJourney(journey,{'schemaVersion':1,'applications':[],'comparison':[]}),throwsStateError);
    expect(journey.applications.single.id,'kept');
  });
  test('private access code is sent only in authorization header',()async{
    const id='12345678-1234-1234-1234-123456789abc';final key='a'*43;
    final api=AtlasPlusClient(client:MockClient((request)async{
      expect(request.url.toString(),endsWith('/$id/snapshot'));
      expect(request.url.toString(),isNot(contains(key)));
      expect(request.headers['Authorization'],'Bearer $key');
      return http.Response(jsonEncode({'revision':3,'snapshot':null}),200);
    }));
    await api.connect('$id.$key');expect(api.revision,3);api.close();expect(api.connected,isFalse);
  });
  test('conflict preserves revision and invalid codes make no request',()async{
    var calls=0;
    final api=AtlasPlusClient(client:MockClient((_)async{calls++;return http.Response('{"error":"Newer cloud backup"}',409);}));
    await expectLater(api.connect('wrong'),throwsFormatException);expect(calls,0);
    api.workspace='12345678-1234-1234-1234-123456789abc';api.key='a'*43;api.revision=2;
    await expectLater(api.save(StudentJourney()),throwsStateError);expect(api.revision,2);api.close();
  });
  test('opportunities match saved schools, exclude closed dates and retain unconfirmed dates',(){
    final journey=StudentJourney()..applications=[ApplicationPlan(id:'a',institutionId:'school',programme:'Course')];
    journey.resources={'deadlines':[
      {'id':'future','institutionId':'school','date':'2027-03-01','checkedAt':'2026-11-18'},
      {'id':'past','institutionId':'school','date':'2026-01-01'},
      {'id':'other','institutionId':'other','date':'2027-02-01'},
      {'id':'closed','institutionId':'school','date':'2027-02-01','availability':'closed'},
    ],'scholarships':[{'id':'unknown','institutionId':'school','date':null,'checkedAt':'2026-11-18'}]};
    final rows=personalResources(journey,now:DateTime(2026,11,18));
    expect(rows.map((r)=>r['id']),['future','unknown']);expect(rows.first['checkedAt'],'2026-11-18');
  });
}
