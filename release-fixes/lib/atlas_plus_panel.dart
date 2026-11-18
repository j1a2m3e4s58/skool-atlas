import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'atlas_plus.dart';
import 'atlas_controls.dart';
import 'tertiary_app.dart' show GlassPanel, ink, gold;
import 'tertiary_data.dart';
import 'student_journey.dart';
import 'local_export.dart';

class AtlasPlusPanel extends StatefulWidget {
  final TertiaryStore store;
  final Future<void> Function() onReport;
  const AtlasPlusPanel({super.key, required this.store, required this.onReport});
  @override State<AtlasPlusPanel> createState() => _AtlasPlusPanelState();
}
class _AtlasPlusPanelState extends State<AtlasPlusPanel> {
  final api=AtlasPlusClient();
  final code=TextEditingController();
  bool busy=false, consent=false;
  String status='Your journey stays on this phone until you choose cloud backup.';
  String? sharedLink;
  StudentJourney get journey=>widget.store.journey;
  String schoolName(String id)=>widget.store.institutions.where((school)=>school.id==id).firstOrNull?.name ?? 'Institution not in this catalogue ($id)';
  @override void dispose(){api.close();code.dispose();super.dispose();}
  Future<void> run(Future<void> Function() task) async {
    setState(()=>busy=true);
    try {await task();} catch(e) {if(mounted)setState(()=>status=e.toString().replaceFirst('Bad state: ','').replaceFirst('FormatException: ',''));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<bool> confirm(String title,String description) async => await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(title),content:Text(description),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Confirm'))])) ?? false;
  Future<void> showCode() async {
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Keep your private access code'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[const Text('This code opens your workspace on another phone. Anyone with it can access or delete your cloud plans. Save it in a password manager. We cannot recover a lost code. Never use it as a family sharing link.'),const SizedBox(height:16),SelectableText(api.accessCode),const SizedBox(height:16),OutlinedButton.icon(onPressed:()async{await Clipboard.setData(ClipboardData(text:api.accessCode));},icon:const Icon(Icons.copy),label:const Text('Copy private code'))])),actions:[FilledButton(onPressed:()=>Navigator.pop(ctx),child:const Text('I have saved my code'))]));
  }
  Widget card(String eyebrow,String heading,String description,List<Widget> children)=>Padding(padding:const EdgeInsets.only(bottom:18),child:GlassPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(eyebrow,style:const TextStyle(color:gold,fontSize:11,letterSpacing:2,fontWeight:FontWeight.bold)),const SizedBox(height:8),Text(heading,style:const TextStyle(fontFamily:'AtlasSerif',fontSize:28,color:ink)),const SizedBox(height:10),Text(description,style:const TextStyle(height:1.6)),const SizedBox(height:18),...children])));
  Future<void> share() async {
    Map<String,dynamic>? cloud;
    await run(()async{cloud=await api.load();});
    if(cloud==null||!mounted)return;
    final snapshot=cloud!['snapshot'] as Map?;
    final plans=[for(final a in snapshot?['applications'] ?? []) ApplicationPlan.fromJson(Map<String,dynamic>.from(a))];
    if(plans.isEmpty){setState(()=>status='Save applications to cloud before sharing.');return;}
    final selected=<String>{};
    bool permission=false;
    final accepted=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(title:const Text('Share a family shortlist'),content:SizedBox(width:520,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('Choose up to six saved applications. Share only programme, institution, application stage and your target date. Grades, notes and budgets stay private.'),for(final plan in plans)CheckboxListTile(value:selected.contains(plan.id),title:Text(plan.programme),subtitle:Text(schoolName(plan.institutionId)),onChanged:(value)=>update((){if(value==true&&selected.length<6){selected.add(plan.id);}else if(value!=true){selected.remove(plan.id);}})),CheckboxListTile(value:permission,title:const Text('I agree to share these selected details'),subtitle:const Text('Anyone with the link can read this snapshot for seven days. A new link replaces the previous one. Copies already saved cannot be revoked.'),onChanged:(v)=>update(()=>permission=v??false))]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:permission&&selected.isNotEmpty?()=>Navigator.pop(ctx,true):null,child:const Text('Create private link'))])));
    if(accepted!=true)return;
    await run(()async{final result=await api.request('share',{'ids':selected.toList(),'consent':true});sharedLink='$plusHost/family#${api.workspace}.${result['key']}';status='Read-only snapshot created. Expires ${result['expiresAt']}. The snapshot uses your last cloud save.';});
  }
  @override Widget build(BuildContext context){
    final resources=personalResources(journey);
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      card('ATLAS PLUS · PREVIEW','Your plans. More connected.','A private space for your next chapter, with thoughtful family sharing and source-dated planning. No payment is collected in this preview.',[const Text('Core grade checks, admission explanations and existing exports remain free. No advertisements are included in the app.',style:TextStyle(height:1.5))]),
      if(busy)const LinearProgressIndicator(),
      Padding(padding:const EdgeInsets.symmetric(vertical:14),child:Semantics(liveRegion:true,child:Text(status,style:const TextStyle(height:1.5,fontWeight:FontWeight.w600)))),
      card('01 · PRIVATE CLOUD','Pick up on another phone','Save and restore your application plans, notes, budgets and comparisons. Grades stay on your device. Sync is manual: save on one phone, then restore on the other. No background upload.',[
        if(!api.connected)...[
          CheckboxListTile(contentPadding:EdgeInsets.zero,value:consent,onChanged:busy?null:(v)=>setState(()=>consent=v??false),title:const Text('I agree to store my journey in the cloud'),subtitle:const Text('Cloudflare hosts the cloud copy. This is access-controlled storage, not end-to-end encryption. Your plans may contain personal information.')),
          FilledButton.icon(onPressed:busy||!consent?null:()=>run(()async{await api.create();status='Workspace created. Save your access code before backing up.';if(mounted)await showCode();}),icon:const Icon(Icons.cloud_outlined),label:const Text('Create private workspace')),
          const SizedBox(height:24),TextField(controller:code,obscureText:true,autocorrect:false,enableSuggestions:false,decoration:const InputDecoration(labelText:'Private access code',hintText:'Reconnect an existing workspace',border:OutlineInputBorder())),const SizedBox(height:12),
          OutlinedButton(onPressed:busy?null:()=>run(()async{final result=await api.connect(code.text);code.clear();status='Connected. Cloud revision ${result['revision']}. Last saved: ${result['updatedAt']??'No backup yet'}. Device plans have not changed.';}),child:const Text('Connect existing workspace')),
        ]else ...[
          Text('Connected · Cloud revision ${api.revision}'),const SizedBox(height:14),
          AtlasActionRow(children:[FilledButton.icon(onPressed:busy?null:()=>run(()async{if(!await confirm('Save this phone to cloud?','This replaces the previous cloud backup with ${journey.applications.length} applications from this phone, including their notes and budgets. It does not merge plans.'))return;await api.save(journey);status='Saved successfully · Cloud revision ${api.revision}. Restore on your other phone to receive these changes.';}),icon:const Icon(Icons.cloud_upload_outlined),label:const Text('Save to cloud')),OutlinedButton.icon(onPressed:busy?null:()=>run(()async{final result=await api.load();if(result['snapshot']==null){status='No cloud backup yet. Save from your first phone.';return;}final snapshot=Map<String,dynamic>.from(result['snapshot']);if(!mounted||!await confirm('Restore cloud journey?','This replaces ${journey.applications.length} device applications with ${(snapshot['applications'] as List).length} cloud applications. Export your current journey first if you want to keep it. Grades remain unchanged.'))return;await restoreJourney(journey,snapshot);status='Cloud journey restored on this phone. Device notification permission is managed separately.';}),icon:const Icon(Icons.cloud_download_outlined),label:const Text('Restore from cloud'))]),
          const SizedBox(height:12),OutlinedButton(onPressed:busy?null:showCode,child:const Text('View my private access code')),
          TextButton(onPressed:busy?null:(){setState((){api.disconnect();sharedLink=null;status='Disconnected. Your device plans and cloud backup remain saved.';});},child:const Text('Disconnect this session')),
          TextButton(onPressed:busy?null:()=>run(()async{if(!await confirm('Delete cloud workspace?','Permanently remove the cloud backup and revoke family access. Your device plans remain. Your private access code will stop working.'))return;await api.request('delete',{'confirm':true});api.disconnect();sharedLink=null;status='Cloud workspace deleted. Device plans were kept.';}),child:const Text('Delete cloud workspace')),
        ]
      ]),
      card('02 · FAMILY, WITH PERMISSION','Share only what you choose','Create a read-only snapshot from your last cloud save. A parent can open it without installing the app. Save changes to cloud before making a new link.',[
        FilledButton.icon(onPressed:busy||!api.connected||journey.applications.isEmpty?null:share,icon:const Icon(Icons.people_outline),label:const Text('Choose applications to share')),
        if(sharedLink!=null)...[const SizedBox(height:12),SelectableText(sharedLink!),const SizedBox(height:12),OutlinedButton.icon(onPressed:()=>run(()async{await Clipboard.setData(ClipboardData(text:sharedLink!));status='Family link copied. Send it only to your intended recipient.';}),icon:const Icon(Icons.copy),label:const Text('Copy family link'))],
        const SizedBox(height:12),OutlinedButton(onPressed:busy||!api.connected?null:()=>run(()async{await api.request('revoke',{});sharedLink=null;status='Family link revoked. Previously downloaded copies cannot be removed.';}),child:const Text('Revoke family link')),
      ]),
      card('03 · STAY AHEAD','Your dated opportunities','Application deadlines and scholarship notices for schools in your journey. These are published resources, not a guarantee of eligibility. Source dates remain visible; unconfirmed dates stay unconfirmed.',[
        if(resources.isEmpty)const Text('No open published opportunities currently match your saved schools. This does not mean no opportunities exist. Check your institution’s official website.'),
        for(final row in resources)...[
          Text(schoolName(row['institutionId'] as String),style:const TextStyle(color:ink,fontWeight:FontWeight.w600)),const SizedBox(height:6),
          Text(row['title'] as String,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17)),const SizedBox(height:8),
          if(row['status']=='needs_source_review')const Text('Pending source review. The source changed or could not be reached; reminder export is paused.',style:TextStyle(color:Colors.deepOrange,fontWeight:FontWeight.bold,height:1.5)),
          Text('${row['status']=='needs_source_review'?'Date pending re-verification':row['date']??'Date not confirmed'} · ${row['cycle']}\nSource checked: ${row['checkedAt']}',style:const TextStyle(height:1.5)),const SizedBox(height:10),
          OutlinedButton(onPressed:()=>run(()async{final uri=Uri.tryParse('${row['sourceUrl']}');if(uri?.scheme!='https'||!await launchUrl(uri!,mode:LaunchMode.externalApplication))throw StateError('The official source could not open.');}),child:const Text('Check official source')),
          if(canRemindResource(row))OutlinedButton.icon(onPressed:()=>run(()async{final plan=ApplicationPlan(id:'resource-${row['id']}',institutionId:row['institutionId'] as String,programme:row['title'] as String,targetDate:row['date'] as String,reminder:true,note:'Published resource: ${row['sourceUrl']}\nSource checked: ${row['checkedAt']}\nCycle: ${row['cycle']}. Recheck the source before applying.');final ok=await saveTextFile('atlas-opportunity.ics',calendarReminder(plan,row['title'] as String),'text/calendar');status=ok?'Calendar file prepared. Import it into your calendar to enable its reminder. Updates are not automatic after import.':'Calendar export was not available.';}),icon:const Icon(Icons.event_outlined),label:const Text('Save calendar reminder')),
          const Divider(height:32),
        ]
      ]),
      card('04 · A PLAN WORTH SHARING','A clear family report','Choose your applications and create a polished PDF with academic explanations, costs and source information where available. Including grades is always your choice.',[FilledButton.icon(onPressed:busy||journey.applications.isEmpty?null:widget.onReport,icon:const Icon(Icons.picture_as_pdf_outlined),label:const Text('Prepare my application report'))]),
      const Text('No ads. No paid ranking. Your academic suggestions are never influenced by sponsorship.',style:TextStyle(color:ink,height:1.5)),
    ]);
  }
}
