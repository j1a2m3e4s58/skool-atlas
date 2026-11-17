import webpush from 'web-push';
import {adminRequest,applyAdminPublication} from './admin.mjs';
import {adminPage} from './admin-page.mjs';
import {sha256,sourceHashIsReviewed,observeOfficialSource,applyObservations,buildAdmissionReviewQueue,validSubscription,validateReminders,remindersDue} from './monitor.mjs';

const json=(value,status=200)=>Response.json(value,{status,headers:{'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}});
const instance=(env,name)=>env.ATLAS_STATE.get(env.ATLAS_STATE.idFromName(name));
const encoder=new TextEncoder();
const tokenFrom=req=>(req.headers.get('Authorization')??'').replace(/^Bearer /,'');
const goodToken=s=>/^[A-Za-z0-9_-]{43}$/.test(s);
const goodId=s=>/^[a-f0-9-]{36}$/.test(s);

export default {
  async fetch(req,env) {
    const u=new URL(req.url);
    if(u.pathname==='/admin'&&req.method==='GET')return adminPage();
    if(u.pathname.startsWith('/api/admin/')&&!['/api/admin/source-review','/api/admin/check-all-sources','/api/admin/check-sources'].includes(u.pathname))return instance(env,'owner-admin').fetch(req);
    if(u.pathname==='/api/health')return json({app:'Ghana Tertiary Atlas',mode:env.APP_ENV,
      sourceMonitoring:'scheduled_every_15_minutes_full_sweep',pushConfigured:!!(env.VAPID_PUBLIC_KEY&&env.VAPID_PRIVATE_KEY),
      publicKey:env.VAPID_PUBLIC_KEY??null,personalData:'Only opted-in push subscriptions, random device identifiers and reminder dates are stored. Grades, notes and budgets stay on the device.'});
    if(u.pathname==='/tertiary-feed.json') {
      const result=await instance(env,'public-feed').fetch('https://internal/feed');
      const headers=new Headers(result.headers);headers.set('Cache-Control','no-store');headers.set('Access-Control-Allow-Origin','*');
      return new Response(result.body,{status:result.status,headers});
    }
    if(u.pathname==='/api/source-status')return instance(env,'public-feed').fetch('https://internal/status');
    if(u.pathname==='/api/admin/source-review'&&req.method==='GET'){
      if(!env.MONITOR_ADMIN_TOKEN||tokenFrom(req)!==env.MONITOR_ADMIN_TOKEN)return json({error:'Not found'},404);
      return instance(env,'public-feed').fetch('https://internal/review');
    }
    if(u.pathname==='/api/admin/check-all-sources'&&req.method==='POST') {
      if(!env.MONITOR_ADMIN_TOKEN||tokenFrom(req)!==env.MONITOR_ADMIN_TOKEN)return json({error:'Not found'},404);
      return json(await runFullSourceSweep(env));
    }
    if(u.pathname==='/api/admin/check-sources'&&req.method==='POST') {
      if(!env.MONITOR_ADMIN_TOKEN||tokenFrom(req)!==env.MONITOR_ADMIN_TOKEN)return json({error:'Not found'},404);
      return instance(env,'public-feed').fetch('https://internal/monitor',{method:'POST'});
    }
    const match=u.pathname.match(/^\/api\/reminders\/([a-f0-9-]{36})$/);
    if(match) {
      if(!goodId(match[1])||!['POST','DELETE'].includes(req.method))return json({error:'Invalid request'},400);
      if(req.headers.get('Origin')!==u.origin)return json({error:'Same-origin request required'},403);
      if(env.REMINDER_RATE&&!(await env.REMINDER_RATE.limit({key:'reminder:'+req.headers.get('CF-Connecting-IP')})).success)return json({error:'Too many requests; try again shortly'},429);
      if(!goodToken(tokenFrom(req)))return json({error:'Device authorization required'},401);
      if(!env.VAPID_PRIVATE_KEY||!env.VAPID_PUBLIC_KEY)return json({error:'Automatic reminders are not configured'},503);
      if(Number(req.headers.get('Content-Length')??0)>16000)return json({error:'Request too large'},413);
      const body=req.method==='POST'?await req.text():'';
      if(body.length>16000)return json({error:'Request too large'},413);
      return instance(env,'reminder:'+match[1]).fetch('https://internal/subscription',{
        method:req.method,headers:{Authorization:req.headers.get('Authorization'),'Content-Type':'application/json'},body:req.method==='POST'?body:undefined});
    }
    if(u.pathname.startsWith('/api/'))return json({error:'Not found'},404);
    const response=await env.ASSETS.fetch(req);const h=new Headers(response.headers);
    h.set('X-Content-Type-Options','nosniff');h.set('Referrer-Policy','strict-origin-when-cross-origin');
    if(['/sw.js','/index.html','/flutter_bootstrap.js'].includes(u.pathname))h.set('Cache-Control','no-cache');
    return new Response(response.body,{status:response.status,headers:h});
  },
  async scheduled(controller,env,ctx) {
    ctx.waitUntil(runFullSourceSweep(env,'scheduled').then(summary=>console.log('Source sweep complete',summary)));
  }
};

// Each bounded batch is a separate Durable Object invocation, preserving
// per-request connection/subrequest limits as the source catalogue grows.
export async function runFullSourceSweep(env,trigger='manual') {
  const stub=instance(env,'public-feed'),startedAt=new Date().toISOString(),seen=new Set();
  let release,total=Infinity;
  for(let rounds=1;rounds<=40;rounds++) {
    const response=await stub.fetch('https://internal/monitor',{method:'POST'});
    if(!response.ok)throw Error('Source sweep batch failed');
    const batch=await response.json();
    if(!Number.isInteger(batch.totalSources)||batch.totalSources<1||!Array.isArray(batch.checkedSourceUrls)||batch.checkedSourceUrls.length<1)throw Error('Invalid source sweep progress');
    if(release&&release!==batch.release)throw Error('Publication changed during source sweep');
    release=batch.release;total=batch.totalSources;
    for(const url of batch.checkedSourceUrls)seen.add(url);
    if(seen.size>=total) {
      const saved=await stub.fetch('https://internal/sweep-complete',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({release,startedAt,rounds,trigger})});
      if(!saved.ok)throw Error('Full sweep coverage could not be confirmed');
      return saved.json();
    }
  }
  throw Error('Source sweep exceeded the reviewed request budget');
}

export class AtlasState {
  constructor(state,env) {this.state=state;this.env=env;this.running=null;}
  async sourceSeed() {
    // Pin the publication in the bundle too: data-only deployments must also
    // replace warm Durable Object instances and their old asset bindings.
    const release=typeof ATLAS_BUILD_RELEASE==='undefined'?this.env.ATLAS_RELEASE:ATLAS_BUILD_RELEASE;
    const b=await this.env.ASSETS.fetch('https://assets/tertiary-monitor.json'+(release?'?release='+encodeURIComponent(release):''));
    if(!b.ok)throw new Error('Published source monitor unavailable');
    const monitor=await b.json();
    if(release&&monitor.release!==release)throw new Error('Published monitor release mismatch');
    const a=await this.env.ASSETS.fetch('https://assets/tertiary-feed.json?release='+encodeURIComponent(monitor.release));
    if(!a.ok)throw new Error('Published evidence assets unavailable');
    const feed=await a.json();
    if(![2,3,4,5].includes(feed.schemaVersion)||!feed.rules?.length||!Array.isArray(monitor.sources))throw new Error('Invalid publication seed');
    for(const s of monitor.sources)if(s.reviewedEquivalentHashes!=null&&(!Array.isArray(s.reviewedEquivalentHashes)||s.reviewedEquivalentHashes.length>3||new Set(s.reviewedEquivalentHashes).size!==s.reviewedEquivalentHashes.length||s.reviewedEquivalentHashes.some(h=>typeof h!=='string'||!/^([a-f0-9]{64})$/.test(h))))throw Error('Invalid reviewed evidence variants');
    const oldRelease=await this.state.storage.get('release');
    // A source baseline is held in the reviewed build. New deploys do not
    // automatically learn changed pages as acceptable admission requirements.
    if(oldRelease!==monitor.release) {
      const old=await this.state.storage.get('observations')??{};
      const retained={};
      for(const s of monitor.sources) if(old[s.url]&&old[s.url].baseline===s.sha256){const row=old[s.url];retained[s.url]=row.observedHash&&['unchanged','changed'].includes(row.state)?{...row,state:sourceHashIsReviewed(s,row.observedHash)?'unchanged':'changed'}:row;}
      await this.state.storage.put({release:monitor.release,observations:retained,lastFullSweep:null});
    }
    return {feed,monitor};
  }
  async fetch(req) {
    const path=new URL(req.url).pathname;
    try {
      if(path.startsWith('/api/admin/')||path==='/publication')return adminRequest(req,this.env,this.state.storage);
      if(path==='/subscription')return await this.subscription(req);
      if(path==='/monitor') {
        if(!this.running)this.running=this.checkSources().finally(()=>{this.running=null;});
        return json(await this.running);
      }
      const {feed,monitor}=await this.sourceSeed();
      const observations=await this.state.storage.get('observations')??{};
      if(path==='/sweep-complete'&&req.method==='POST') {
        const info=await req.json(),started=new Date(info.startedAt),completed=new Date();
        if(!['manual','scheduled'].includes(info.trigger)||info.release!==monitor.release||!Number.isFinite(started.getTime())||started>completed||!Number.isInteger(info.rounds)||info.rounds<1||info.rounds>40||monitor.sources.some(s=>!observations[s.url]||!Number.isFinite(new Date(observations[s.url].checkedAt).getTime())||new Date(observations[s.url].checkedAt)<started||new Date(observations[s.url].checkedAt)>completed))throw Error('Full sweep evidence is incomplete');
        const rows=monitor.sources.map(s=>observations[s.url]);
        const summary={release:monitor.release,trigger:info.trigger,startedAt:started.toISOString(),completedAt:completed.toISOString(),totalSources:rows.length,checked:rows.length,rounds:info.rounds,unchanged:rows.filter(r=>r.state==='unchanged').length,changed:rows.filter(r=>r.state==='changed').length,unavailable:rows.filter(r=>r.state==='unavailable').length};
        await this.state.storage.put('lastFullSweep',summary);return json(summary);
      }

      if(path==='/review')return json({checkedAt:new Date().toISOString(),queue:buildAdmissionReviewQueue(feed,monitor.sources,observations),policy:'Review source differences and all affected structured records before preparing an explicit publication. This endpoint cannot approve or publish changes.'});
      if(path==='/status')return json({intervalMinutes:15,scope:'all_monitored_sources',lastFullSweep:await this.state.storage.get('lastFullSweep')??null,lastRun:await this.state.storage.get('lastRun')??null,
        sources:monitor.sources.map(s=>({url:s.url,state:observations[s.url]?.state??'not_yet_checked',checkedAt:observations[s.url]?.checkedAt??null})),
        policy:'Changed or unavailable sources disable affected academic rules pending a reviewed publication. Check dates are not automatically renewed.'});
      const publicationResponse=await instance(this.env,'owner-admin').fetch('https://internal/publication');
      if(!publicationResponse.ok)throw Error('Publication unavailable');
      const publication=await publicationResponse.json();
      const response=json(applyObservations(applyAdminPublication(feed,publication),monitor.sources,observations));
      response.headers.set('X-Atlas-Release',monitor.release);
      return response;
    } catch {return json({error:'Service temporarily unavailable; retain your last verified offline data'},503);}
  }
  async checkSources(seed=null,maximum=12) {
    const {monitor}=seed??await this.sourceSeed();
    const observations=await this.state.storage.get('observations')??{};
    const now=new Date().toISOString();const cursor=await this.state.storage.get('cursor')??0;
    const count=Math.min(12,maximum,monitor.sources.length);
    const sources=Array.from({length:count},(_,i)=>monitor.sources[(cursor+i)%monitor.sources.length]);
    // Bounded batches stay under the free-plan subrequest and connection limits.
    for(let n=0;n<sources.length;n+=3) await Promise.all(sources.slice(n,n+3).map(async source=>{
      observations[source.url]=await observeOfficialSource(source,now);
    }));
    await this.state.storage.put({observations,lastRun:now,cursor:monitor.sources.length?(cursor+count)%monitor.sources.length:0});
    return {checkedAt:now,release:monitor.release,totalSources:monitor.sources.length,checkedSourceUrls:sources.map(s=>s.url),checked:sources.length,unchanged:sources.filter(s=>observations[s.url].state==='unchanged').length,
      changed:sources.filter(s=>observations[s.url].state==='changed').length,unavailable:sources.filter(s=>observations[s.url].state==='unavailable').length};
  }
  async subscription(req) {
    const token=tokenFrom(req);if(!goodToken(token))return json({error:'Unauthorized'},401);
    const tokenHash=await sha256(encoder.encode(token));const existing=await this.state.storage.get('reminder');
    if(existing&&existing.tokenHash!==tokenHash)return json({error:'Unauthorized'},401);
    if(req.method==='DELETE') {
      await this.state.storage.delete('reminder');await this.state.storage.deleteAlarm();return json({ok:true,enabled:false});
    }
    let input;try{input=await req.json();}catch{return json({error:'Invalid JSON'},400);}
    if(!validSubscription(input.subscription))return json({error:'Unsupported push subscription'},400);
    let reminders;try{reminders=validateReminders(input.reminders);}catch(e){return json({error:e.message},400);}
    const oldById=new Map((existing?.reminders??[]).map(r=>[r.id,r]));
    reminders=reminders.map(r=>({...r,sent:oldById.get(r.id)?.date===r.date?oldById.get(r.id).sent??false:false}));
    if(!reminders.length) {
      await this.state.storage.delete('reminder');await this.state.storage.deleteAlarm();return json({ok:true,enabled:false});
    }
    const value={tokenHash,subscription:input.subscription,reminders,updatedAt:new Date().toISOString()};
    await this.state.storage.put('reminder',value);await this.setNextAlarm(value);
    return json({ok:true,enabled:true,count:reminders.length});
  }
  async setNextAlarm(value) {
    const now=Date.now();
    const times=value.reminders.filter(r=>!r.sent).map(r=>new Date(r.date+'T08:00:00Z').getTime()-86400000).filter(t=>t>now);
    const tomorrow=remindersDue(value.reminders);
    const first=tomorrow.length?now+1000:Math.min(...times);
    const expiry=Math.max(...value.reminders.map(r=>new Date(r.date+'T00:00:00Z').getTime()))+7*86400000;
    await this.state.storage.setAlarm(Number.isFinite(first)?first:Math.max(now+1000,expiry));
  }
  async alarm() {
    const value=await this.state.storage.get('reminder');if(!value)return;
    const expiry=Math.max(...value.reminders.map(r=>new Date(r.date+'T00:00:00Z').getTime()))+7*86400000;
    if(Date.now()>expiry){await this.state.storage.delete('reminder');return;}
    const due=remindersDue(value.reminders);
    if(due.length) {
      try {
        const details=webpush.generateRequestDetails(value.subscription,JSON.stringify({title:'Tertiary Atlas reminder',body:'A personal application target is tomorrow. Open My journey to review your plans.',url:'/',tag:'atlas-personal-target'}),{
          TTL:86400,vapidDetails:{subject:this.env.VAPID_SUBJECT,publicKey:this.env.VAPID_PUBLIC_KEY,privateKey:this.env.VAPID_PRIVATE_KEY}});
        const sent=await fetch(details.endpoint,{method:'POST',headers:details.headers,body:details.body,redirect:'error',signal:AbortSignal.timeout(12000)});
        if([404,410].includes(sent.status)){await this.state.storage.delete('reminder');return;}
        if(!sent.ok)throw new Error('Push delivery rejected');
        for(const r of due)r.sent=true;
        await this.state.storage.put('reminder',value);
      }catch{await this.state.storage.setAlarm(Date.now()+3600000);return;}
    }
    await this.setNextAlarm(value);
  }
}
