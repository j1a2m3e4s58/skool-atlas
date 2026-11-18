const json=(data,status=200)=>Response.json(data,{status,headers:{'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}});
const secret=()=>btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32)))).replaceAll('+','-').replaceAll('/','_').replaceAll('=','');
const hash=async value=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value))),b=>b.toString(16).padStart(2,'0')).join('');
const validKey=x=>typeof x==='string'&&/^[A-Za-z0-9_-]{43}$/.test(x);
const stages=['Researching','Preparing','Submitted','Offer received','Accepted','Closed'];
function text(value,max){if(typeof value!=='string'||value.length>max)throw Error('Invalid text');return value;}
export function validateSnapshot(value){
 if(!value||value.schemaVersion!==1||!Array.isArray(value.applications)||value.applications.length>50||!Array.isArray(value.comparison)||value.comparison.length>4)throw Error('Invalid journey');
 const ids=new Set();
 const applications=value.applications.map(a=>{
  const id=text(a.id,100);if(!id||ids.has(id))throw Error('Duplicate application');ids.add(id);
  if(!stages.includes(a.stage)||!Array.isArray(a.completed)||a.completed.length>20||a.completed.some(x=>typeof x!=='string'||x.length>150))throw Error('Invalid application');
  if(a.targetDate!=null&&(!/^\d{4}-\d{2}-\d{2}$/.test(a.targetDate)||!Number.isFinite(Date.parse(a.targetDate))||new Date(a.targetDate).toISOString().slice(0,10)!==a.targetDate))throw Error('Invalid date');
  if(!a.budget||Array.isArray(a.budget)||typeof a.budget!=='object'||Object.keys(a.budget).length>10||Object.entries(a.budget).some(([k,v])=>k.length>100||typeof v!=='number'||!Number.isFinite(v)||v<0||v>1e9))throw Error('Invalid budget');
  return {id,institutionId:text(a.institutionId,150),programme:text(a.programme,500),stage:a.stage,note:text(a.note??'',5000),period:text(a.period??'One academic year',100),targetDate:a.targetDate??null,reminder:a.reminder===true,completed:a.completed,budget:a.budget};
 });
 if(value.comparison.some(id=>!ids.has(id))||new Set(value.comparison).size!==value.comparison.length)throw Error('Invalid comparison');
 // Deliberate allowlist: never accept grades, admissions rules or account credentials.
 return {schemaVersion:1,applications,comparison:value.comparison};
}
export async function plusRequest(req,storage){
 const action=new URL(req.url).pathname.split('/').at(-1);
 if(!['GET','POST'].includes(req.method))return json({error:'Method not allowed'},405);
 let body={};
 if(req.method==='POST'){
  if(!req.headers.get('Content-Type')?.startsWith('application/json'))return json({error:'JSON required'},415);
  const reader=req.body?.getReader(),chunks=[];let size=0;
  if(reader)while(true){const {done,value}=await reader.read();if(done)break;size+=value.byteLength;if(size>100000){await reader.cancel();return json({error:'Journey is too large'},413);}chunks.push(value);}
  const bytes=new Uint8Array(size);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.byteLength;}
  try{body=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));}catch{return json({error:'Invalid request'},400);}
  if(!body||typeof body!=='object'||Array.isArray(body))return json({error:'Invalid request'},400);
 }
 const token=(req.headers.get('Authorization')??'').replace(/^Bearer /,'');
 if(action==='create'&&req.method==='POST'){
  if(body.consent!==true)return json({error:'Cloud storage consent is required'},400);
  return storage.transaction(async tx=>{
   if(await tx.get('plusAccount'))return json({error:'Workspace already exists'},409);
   const key=secret();await tx.put('plusAccount',{keyHash:await hash(key),createdAt:new Date().toISOString()});
   return json({key,revision:0});
  });
 }
 if(!validKey(token))return json({error:'Workspace access key required'},401);
 const digest=await hash(token);
 if(action==='shared'&&req.method==='GET'){
  const share=await storage.get('plusShare');
  if(!share||share.keyHash!==digest||share.expiresAt<=Date.now())return json({error:'This sharing link has expired or been revoked'},404);
  return json({applications:share.applications,createdAt:share.createdAt,expiresAt:new Date(share.expiresAt).toISOString(),readOnly:true});
 }
 // Authenticate and mutate under the same transaction so deletion/revocation cannot race a write.
 return storage.transaction(async tx=>{
  const account=await tx.get('plusAccount');
  if(!account||account.keyHash!==digest)return json({error:'Workspace access key is incorrect'},401);
  const current=await tx.get('plusSnapshot')??{revision:0,snapshot:null,updatedAt:null};
  if(action==='snapshot'&&req.method==='GET')return json(current);
  if(action==='snapshot'&&req.method==='POST'){
   if(body.revision!==current.revision)return json({error:'Another phone changed this backup. Load the cloud copy before saving again.',revision:current.revision},409);
   let snapshot;try{snapshot=validateSnapshot(body.snapshot);}catch{return json({error:'Invalid journey backup. No data changed.'},400);}
   const next={snapshot,revision:current.revision+1,updatedAt:new Date().toISOString()};await tx.put('plusSnapshot',next);return json(next);
  }
  if(action==='share'&&req.method==='POST'){
   if(body.consent!==true||!Array.isArray(body.ids)||body.ids.length<1||body.ids.length>6||new Set(body.ids).size!==body.ids.length)return json({error:'Select one to six applications and confirm sharing permission'},400);
   const plans=current.snapshot?.applications??[];
   if(body.ids.some(id=>!plans.some(a=>a.id===id)))return json({error:'Save the selected applications to cloud first'},400);
   const key=secret(),createdAt=new Date().toISOString(),expiresAt=Date.now()+7*86400000;
   const applications=plans.filter(a=>body.ids.includes(a.id)).map(a=>({programme:a.programme,institutionId:a.institutionId,stage:a.stage,targetDate:a.targetDate}));
   await tx.put('plusShare',{keyHash:await hash(key),createdAt,expiresAt,applications});
   return json({key,createdAt,expiresAt:new Date(expiresAt).toISOString()});
  }
  if(action==='revoke'&&req.method==='POST'){await tx.delete('plusShare');return json({ok:true});}
  if(action==='delete'&&req.method==='POST'){
   if(body.confirm!==true)return json({error:'Confirm deletion'},400);
   await tx.delete('plusShare');await tx.delete('plusSnapshot');await tx.delete('plusAccount');return json({ok:true});
  }
  return json({error:'Not found'},404);
 });
}
