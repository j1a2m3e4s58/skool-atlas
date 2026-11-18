import {test} from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import worker from '../src/worker.mjs';
import {familyPage} from '../src/family-page.mjs';
test('Plus API stays disabled unless explicitly enabled; foreign origins blocked and rate limit required',async()=>{
 const req=(origin)=>new Request('https://atlas.test/api/plus/12345678-1234-1234-1234-123456789abc/snapshot',{headers:{...(origin?{Origin:origin}:{}),Authorization:'Bearer '+'a'.repeat(43)}});
 assert.equal((await worker.fetch(req(),{})).status,503);
 assert.equal((await worker.fetch(req('https://evil.test'),{PLUS_ENABLED:'pilot'})).status,403);
 assert.equal((await worker.fetch(req(),{PLUS_ENABLED:'pilot'})).status,429);
 let called=false;const env={PLUS_ENABLED:'pilot',REMINDER_RATE:{limit:async()=>({success:true})},ATLAS_STATE:{idFromName:id=>id,get:()=>({fetch:async()=>{called=true;return Response.json({ok:true});}})}};
 assert.equal((await worker.fetch(req('https://atlas.test'),env)).status,200);assert.equal(called,true);
});
test('family page uses strict CSP, no-store and text rendering; access fragment removed',async()=>{
 const r=familyPage(),html=await r.text();assert.equal(r.headers.get('Cache-Control'),'no-store');assert.equal(r.headers.get('Referrer-Policy'),'no-referrer');assert.match(r.headers.get('Content-Security-Policy'),/frame-ancestors 'none'/);assert.match(html,/history.replaceState/);assert.doesNotMatch(html,/innerHTML/);new vm.Script(html.match(/<script nonce="[^"]+">([\s\S]*?)<\/script>/)[1]);
});
