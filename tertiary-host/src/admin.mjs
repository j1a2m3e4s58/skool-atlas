// Owner-only content management. Credentials and sessions never enter public feeds.
const enc=new TextEncoder();
const json=(body,status=200,headers={})=>Response.json(body,{status,headers:{'Cache-Control':'no-store','X-Content-Type-Options':'nosniff',...headers}});
const fail=(message,status=400)=>{throw Object.assign(new Error(message),{status});};
const random=()=>Array.from(crypto.getRandomValues(new Uint8Array(32)),n=>n.toString(16).padStart(2,'0')).join('');
const hash=async text=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',enc.encode(text))),n=>n.toString(16).padStart(2,'0')).join('');
const equal=(a,b)=>{if(typeof a!=='string'||typeof b!=='string'||a.length!==b.length)return false;let d=0;for(let n=0;n<a.length;n++)d|=a.charCodeAt(n)^b.charCodeAt(n);return d===0;};
async function passwordHash(password,salt,pepper){if(typeof pepper!=='string'||pepper.length<32)fail('Owner authentication is not configured.',503);const key=await crypto.subtle.importKey('raw',enc.encode(password),'PBKDF2',false,['deriveBits']);const derived=await crypto.subtle.deriveBits({name:'PBKDF2',hash:'SHA-256',salt:enc.encode(salt),iterations:100000},key,256);const signing=await crypto.subtle.importKey('raw',enc.encode(pepper),{name:'HMAC',hash:'SHA-256'},false,['sign']);return Array.from(new Uint8Array(await crypto.subtle.sign('HMAC',signing,derived)),n=>n.toString(16).padStart(2,'0')).join('');}
function password(value){if(typeof value!=='string'||value.length<14||value.length>128)fail('Use a password between 14 and 128 characters.');return value;}
const defaults={homeEyebrow:'AMBITION HAS A DESTINATION.',homeTitle:'Your potential.\nA world of possibilities.',homeIntro:'Discover universities, colleges and creative pathways across Ghana. Make your next move with clarity.',primaryActionLabel:'Explore institutions',secondaryActionLabel:'Find my pathway',regionHeading:'Across all 16 regions',supportEmail:'jamest4n4@gmail.com',announcement:''};
export const defaultContent=Object.freeze(defaults);
const blank=()=>({content:{},institutions:{},rules:{}});
const object=v=>v&&typeof v==='object'&&!Array.isArray(v);
const copy=v=>structuredClone(v);
const ruleFields=['programme','note','maxAggregate','coreCredits','aggregateCores','requiredElectives','allowedElectives','scienceOrSocial','gradeFloors','coreMaxGrades','additionalConditions','electiveRoutes'];
const cores=['English Language','Core Mathematics','Integrated Science','Social Studies'];
const electives=['Elective Mathematics','Physics','Chemistry','Biology','Economics','Geography','Government','History','Literature in English','French','Christian Religious Studies','Islamic Religious Studies','Ghanaian Language','Business Management','Financial Accounting','Cost Accounting','Clerical Office Duties','Food and Nutrition','Management in Living','General Knowledge in Art','Graphic Design','Picture Making','Textiles','Ceramics','Sculpture','Leatherwork','Basketry','Jewellery','General Agriculture','Animal Husbandry','Crop Husbandry and Horticulture','Forestry','Fisheries','Technical Drawing','Building Construction','Woodwork','Metalwork','Applied Electricity','Electronics','Auto Mechanics'];
function text(value,max=1000){if(typeof value!=='string'||value.length>max||/[\u0000-\u0008]/.test(value))fail('Invalid or overlong text.');return value.trim();}
function subjects(value,allowed,max=allowed.length){if(!Array.isArray(value)||value.length>max||new Set(value).size!==value.length||value.some(s=>!allowed.includes(s)))fail('Invalid subject selection.');return value;}
export function validateDocument(input,feed){
  if(!object(input)||enc.encode(JSON.stringify(input)).length>95000||Object.keys(input).some(k=>!['content','institutions','rules'].includes(k)))fail('Invalid draft or draft exceeds 95 KB.');
  const result=blank();
  for(const [key,value] of Object.entries(input.content??{})){
    if(!Object.hasOwn(defaults,key))fail('Unknown content field.');
    result.content[key]=text(value,key==='homeIntro'||key==='announcement'?1000:200);
    if(key!=='announcement'&&!result.content[key])fail('This content field cannot be empty.');
    if(key==='supportEmail'&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value))fail('Enter a valid support email.');
  }
  if(!object(input.content??{}))fail('Invalid content collection.');
  if(!object(input.institutions??{})||!object(input.rules??{}))fail('Invalid record collection.');
  for(const [id,patch] of Object.entries(input.institutions??{})){
    if(!feed.institutions?.some(i=>i.id===id)||!object(patch))fail('Unknown institution.');
    result.institutions[id]={};
    for(const [key,value] of Object.entries(patch)){
      if(!['name','location','category'].includes(key))fail('Institution identity, accreditation and region assignments are protected.');
      const clean=text(value,240);if(!clean)fail('Institution fields cannot be empty.');result.institutions[id][key]=clean;
    }
  }
  for(const [id,entry] of Object.entries(input.rules??{})){
    const base=feed.rules.find(r=>r.id===id);
    if(!base||!object(entry)||!object(entry.patch)||Object.keys(entry).some(k=>!['patch','reviewed','evidence','reviewedAt'].includes(k)))fail('Unknown programme or invalid edit.');
    const patch={};
    for(const [key,value] of Object.entries(entry.patch)){
      if(!ruleFields.includes(key))fail('This requirement field is protected.');
      patch[key]=copy(value);
    }
    const r={...base,...patch};
    for(const k of ['programme','note'])if(k in patch){patch[k]=text(patch[k],k==='note'?2000:240);if(!patch[k])fail('Programme and note cannot be empty.');}
    if(!(Number.isInteger(r.maxAggregate)&&r.maxAggregate>=6&&r.maxAggregate<=54)&&!(r.maxAggregate===null&&[2,3].includes(r.ruleVersion)))fail('Aggregate must be 6–54, or unset for a supported rule.');
    subjects(r.coreCredits,cores);if(!r.coreCredits.length)fail('At least one compulsory core is required.');subjects(r.aggregateCores,cores,3);if(r.aggregateCores.length!==3||r.aggregateCores.some(s=>!r.coreCredits.includes(s)))fail('Select three counted compulsory cores.');
    // Existing specialised subjects remain valid; the editor cannot invent new equivalents.
    const known=[...new Set(feed.rules.flatMap(x=>[...(x.allowedElectives??[]),...(x.requiredElectives??[]),...(x.electiveRoutes??[]).flatMap(t=>[...(t.allowed??[]),...(t.required??[]),...(t.groups??[]).flatMap(g=>g.subjects??[])])]))];
    if(r.electiveRoutes!=null){if(!Array.isArray(r.electiveRoutes)||!r.electiveRoutes.length||r.electiveRoutes.length>20)fail('Invalid elective routes.');for(const route of r.electiveRoutes){if(!object(route)||Object.keys(route).some(k=>!['label','required','countedRequired','allowed','groups','maxGrade','confirmation','coreMaxGrades'].includes(k)))fail('Invalid elective route.');text(route.label,240);const allowed=subjects(route.allowed??known,known);if(allowed.length<3)fail('Each route needs at least three allowed electives.');subjects(route.required??[],known,4);subjects(route.countedRequired??route.required??[],allowed,3);if(route.maxGrade!=null&&(!Number.isInteger(route.maxGrade)||route.maxGrade<1||route.maxGrade>8))fail('Invalid route grade.');if(route.confirmation!=null)text(route.confirmation,2000);if(route.coreMaxGrades!=null){if(!object(route.coreMaxGrades))fail('Invalid route core grades.');for(const [subject,grade] of Object.entries(route.coreMaxGrades))if(![...r.coreCredits,...(r.scienceOrSocial??[])].includes(subject)||!Number.isInteger(grade)||grade<1||grade>6)fail('Invalid route core grade.');}if(!Array.isArray(route.groups??[]))fail('Invalid subject groups.');for(const group of route.groups??[]){if(!object(group)||Object.keys(group).some(k=>!['subjects','count','maxGrade'].includes(k)))fail('Invalid subject group.');subjects(group.subjects,allowed);if(!Number.isInteger(group.count)||group.count<1||group.count>3||group.subjects.length<group.count)fail('Invalid subject group count.');if(group.maxGrade!=null&&(!Number.isInteger(group.maxGrade)||group.maxGrade<1||group.maxGrade>7))fail('Invalid group grade.');}}}
    subjects(r.requiredElectives??[],known,3);subjects(r.allowedElectives??known,known);
    if((r.requiredElectives??[]).some(s=>!(r.allowedElectives??known).includes(s)))fail('Required electives must also be allowed.');
    subjects(r.scienceOrSocial??[],['Integrated Science','Social Studies'],2);
    if((r.scienceOrSocial??[]).length&&((r.scienceOrSocial.length!==2)||!r.coreCredits.includes(r.scienceOrSocial[0])||!r.aggregateCores.includes(r.scienceOrSocial[0])))fail('Invalid alternative core arrangement.');
    for(const k of ['gradeFloors','coreMaxGrades'])if(r[k]!=null){if(!object(r[k]))fail('Grade limits must be a subject-to-grade object.');for(const [subject,grade] of Object.entries(r[k]))if(![...cores,...known].includes(subject)||!Number.isInteger(grade)||grade<1||grade>(k==='coreMaxGrades'?8:6))fail('Invalid subject grade limit.');}
    if(r.additionalConditions!=null&&(!Array.isArray(r.additionalConditions)||r.additionalConditions.length>30||r.additionalConditions.some(v=>typeof v!=='string'||v.length>2000)))fail('Invalid additional conditions.');
    const evidence=text(entry.evidence??'',4000);
    if(entry.reviewed===true&&evidence.length<30)fail('Include the exact official evidence and your review explanation (at least 30 characters).');
    result.rules[id]={patch,reviewed:entry.reviewed===true,evidence};
    if(entry.reviewedAt!=null){if(!/^\d{4}-\d{2}-\d{2}$/.test(entry.reviewedAt)||!Number.isFinite(Date.parse(entry.reviewedAt))||Date.parse(entry.reviewedAt)>Date.now())fail('Invalid review date.');result.rules[id].reviewedAt=entry.reviewedAt;}
  }
  return result;
}
export function applyAdminPublication(feed,publication){
  if(!publication?.document)return feed;
  const document=validateDocument(publication.document,feed),out=copy(feed);
  out.siteContent={...defaults,...document.content};
  out.adminRevision=publication.revision;
  if(out.institutions)out.institutions=out.institutions.map(i=>({...i,...document.institutions[i.id]}));
  out.rules=out.rules.map(r=>{const edit=document.rules[r.id];if(!edit)return r;return {...r,...edit.patch,status:edit.reviewed?'source_checked':'needs_source_review',checkedAt:edit.reviewed?edit.reviewedAt??r.checkedAt:r.checkedAt,note:[edit.patch.note??r.note,edit.reviewed?'Owner reviewed official evidence: '+edit.evidence:'Admin edit pending official-source review. '+edit.evidence].join('\n')};});
  return out;
}
async function seed(env){const r=await env.ASSETS.fetch('https://assets/tertiary-feed.json');if(!r.ok)fail('Catalogue unavailable.',503);return r.json();}
async function body(req){if(!req.headers.get('Content-Type')?.startsWith('application/json'))fail('JSON required.',415);const raw=await req.text();if(raw.length>105000)fail('Request too large.',413);try{return JSON.parse(raw);}catch{fail('Invalid JSON.');}}
const cookie=(token,age=28800)=>`atlas_admin=${token}; Path=/api/admin; Max-Age=${age}; HttpOnly; Secure; SameSite=Strict`;
export async function adminRequest(req,env,storage){
  const path=new URL(req.url).pathname,now=Date.now();
  try{
    if(path==='/publication')return json(await storage.get('published')??null);
    if(path==='/api/admin/status'&&req.method==='GET')return json({configured:!!await storage.get('account')});
    if(!['GET','POST'].includes(req.method))fail('Method not allowed.',405);
    if(req.method==='POST'&&req.headers.get('Origin')!==new URL(req.url).origin)fail('Same-origin request required.',403);
    if(req.headers.get('Sec-Fetch-Site')==='cross-site')fail('Cross-site request rejected.',403);
    if(['/api/admin/login','/api/admin/setup'].includes(path)){
      if(req.method!=='POST')fail('Method not allowed.',405);
      const ip=await hash(req.headers.get('CF-Connecting-IP')??'local');
      const permitted=await storage.transaction(async tx=>{
        const counters=await tx.get('attempts')??{};for(const k of Object.keys(counters))if(counters[k].until<=now)delete counters[k];
        for(const key of ['global',ip]){const row=counters[key]??{count:0,until:now+15*60000};if(row.count>=(key==='global'?60:8))return false;}
        for(const key of ['global',ip]){const row=counters[key]??{count:0,until:now+15*60000};row.count++;counters[key]=row;}await tx.put('attempts',counters);return true;
      });if(!permitted)fail('Too many attempts. Try again in 15 minutes.',429);
      const input=await body(req),email=String(input.email??'').trim().toLowerCase();
      if(path.endsWith('/setup')){
        if(!env.ADMIN_BOOTSTRAP_SECRET||!equal(req.headers.get('X-Atlas-Setup')??'',env.ADMIN_BOOTSTRAP_SECRET))fail('Setup is unavailable.',403);
        if(email!==(env.ADMIN_EMAIL??'jamest4n4@gmail.com'))fail('Owner email required.',403);
        const salt=random(),digest=await passwordHash(password(input.password),salt,env.ADMIN_PASSWORD_PEPPER);
        await storage.transaction(async tx=>{if(await tx.get('account'))fail('Owner account already exists.',409);await tx.put('account',{email,salt,digest,version:1,mustChange:true});});
        return json({ok:true});
      }
      const account=await storage.get('account');
      const candidate=await passwordHash(typeof input.password==='string'&&input.password.length<=128?input.password:'',account?.salt??'no-account',env.ADMIN_PASSWORD_PEPPER);
      if(!account||email!==account.email||!equal(candidate,account.digest))fail('Email or password is incorrect.',401);
      const token=random(),csrf=random(),key=await hash(token);
      await storage.transaction(async tx=>{const sessions=await tx.get('sessions')??{};for(const id of Object.keys(sessions))if(sessions[id].expires<=now)delete sessions[id];const ids=Object.keys(sessions);if(ids.length>=5)delete sessions[ids[0]];sessions[key]={csrf,version:account.version,expires:now+8*3600000};await tx.put('sessions',sessions);});
      return json({ok:true,csrf,mustChange:account.mustChange},200,{'Set-Cookie':cookie(token)});
    }
    const token=/(?:^|;\s*)atlas_admin=([a-f0-9]{64})(?:;|$)/.exec(req.headers.get('Cookie')??'')?.[1];
    const key=token?await hash(token):'',sessions=await storage.get('sessions')??{},session=sessions[key],account=await storage.get('account');
    if(!session||session.expires<=now||session.version!==account?.version)fail('Please sign in.',401);
    if(req.method==='POST'&&!equal(req.headers.get('X-Atlas-CSRF')??'',session.csrf))fail('Session confirmation failed. Reload and sign in.',403);
    if(path==='/api/admin/session'&&req.method==='GET')return json({email:account.email,csrf:session.csrf,mustChange:account.mustChange});
    if(path==='/api/admin/logout'&&req.method==='POST'){await storage.transaction(async tx=>{const s=await tx.get('sessions')??{};delete s[key];await tx.put('sessions',s);});return json({ok:true},200,{'Set-Cookie':cookie('',0)});}
    if(path==='/api/admin/password'&&req.method==='POST'){
      const allowed=await storage.transaction(async tx=>{let rate=await tx.get('passwordAttempts');if(!rate||rate.until<=now)rate={count:0,until:now+15*60000};if(rate.count>=8)return false;rate.count++;await tx.put('passwordAttempts',rate);return true;});if(!allowed)fail('Too many password attempts. Try again in 15 minutes.',429);
      const input=await body(req);
      if(typeof input.oldPassword!=='string'||input.oldPassword.length>128||!equal(await passwordHash(input.oldPassword,account.salt,env.ADMIN_PASSWORD_PEPPER),account.digest))fail('Current password is incorrect.',403);
      if(input.newPassword===input.oldPassword)fail('Choose a different password.');
      const salt=random(),digest=await passwordHash(password(input.newPassword),salt,env.ADMIN_PASSWORD_PEPPER);
      await storage.transaction(async tx=>{const current=await tx.get('account');if(current.version!==account.version)fail('Account changed. Sign in again.',409);await tx.put('account',{...account,salt,digest,version:account.version+1,mustChange:false});await tx.put('sessions',{});});
      return json({ok:true,signInAgain:true},200,{'Set-Cookie':cookie('',0)});
    }
    if(account.mustChange)fail('Change your temporary password first.',403);
    const confirmSession=async tx=>{const a=await tx.get('account'),s=(await tx.get('sessions')??{})[key];if(!s||s.expires<=Date.now()||s.version!==a?.version||a.version!==account.version)fail('Please sign in again.',401);};
    const meta=await storage.get('meta')??{version:0,revision:0,history:[]};
    if(path==='/api/admin/workspace'&&req.method==='GET')return json({meta,draft:await storage.get('draft')??blank(),published:await storage.get('published')??null,defaults,feed:await seed(env)});
    if(req.method!=='POST')fail('Not found.',404);
    const input=await body(req);
    if(!Number.isInteger(input.version)||input.version!==meta.version)fail('Someone changed this draft. Reload before saving.',409);
    if(path==='/api/admin/draft'){
      const document=validateDocument(input.document,await seed(env));
      await storage.transaction(async tx=>{await confirmSession(tx);const m=await tx.get('meta')??meta;if(m.version!==input.version)fail('Draft changed. Reload.',409);await tx.put('draft',document);await tx.put('meta',{...m,version:m.version+1});});return json({ok:true,version:meta.version+1});
    }
    if(path==='/api/admin/publish'||path==='/api/admin/undo'){
      let document=await storage.get('draft')??blank();
      if(path.endsWith('/undo')){if(!meta.history.some(h=>h.revision===input.revision))fail('Revision unavailable.');document=(await storage.get('revision:'+input.revision))?.document;if(!document)fail('Revision unavailable.');}
      const feed=await seed(env);document=validateDocument(document,feed);
      const reviewed=Object.entries(document.rules).filter(([,r])=>r.reviewed);
      if(reviewed.length){const stub=env.ATLAS_STATE.get(env.ATLAS_STATE.idFromName('public-feed'));const response=await stub.fetch('https://internal/status');if(!response.ok)fail('Source checks unavailable; save as pending.',409);const status=await response.json();for(const [id] of reviewed){const rule=feed.rules.find(r=>r.id===id),source=status.sources.find(s=>s.url===rule.sourceUrl);if(source?.state!=='unchanged'||!source.checkedAt||now-Date.parse(source.checkedAt)>24*3600000)fail('Official source has changed, is unavailable or is not recently checked. Save this rule as pending.',409);}}
      const previous=await storage.get('published');
      for(const [id,edit] of reviewed){if(path.endsWith('/undo'))continue;const old=previous?.document.rules[id];const same=old?.reviewed&&JSON.stringify(old.patch)===JSON.stringify(edit.patch)&&old.evidence===edit.evidence;document.rules[id].reviewedAt=same?old.reviewedAt??feed.rules.find(r=>r.id===id).checkedAt:new Date(now).toISOString().slice(0,10);}
      const note=text(input.note??'',240);if(note.length<8)fail('Describe this publication (at least 8 characters).');
      const publication={revision:meta.revision+1,at:new Date(now).toISOString(),note,document};
      await storage.transaction(async tx=>{await confirmSession(tx);const m=await tx.get('meta')??meta;if(m.version!==input.version)fail('Draft changed. Reload.',409);let history=m.history;if(!history.length){await tx.put('revision:0',{revision:0,document:blank(),note:'Original app content'});history=[{revision:0,note:'Original app content',at:new Date(now).toISOString()}];}history=[...history,{revision:publication.revision,at:publication.at,note}];if(history.length>20){const old=history.shift();await tx.delete('revision:'+old.revision);}await tx.put('revision:'+publication.revision,publication);await tx.put('published',publication);await tx.put('draft',document);await tx.put('meta',{version:m.version+1,revision:publication.revision,history});});
      return json({ok:true,revision:publication.revision,version:meta.version+1});
    }
    fail('Not found.',404);
  }catch(error){return json({error:error.status?error.message:'Admin service unavailable. No change was published.'},error.status??503);}
}
