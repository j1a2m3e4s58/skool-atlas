/* Generated with the web build. Never cache account APIs or external media. */
const VERSION = '__ATLAS_VERSION__';
const CACHE = `skool-atlas-${VERSION}`;
const CORE = __ATLAS_CORE__;
const MEDIA = __ATLAS_MEDIA__;
const MEDIA_BYTES = __ATLAS_MEDIA_BYTES__;
const MEDIA_CACHE = 'atlas-photos-__ATLAS_MEDIA_VERSION__';
const ESSENTIAL = new Set(CORE);
const PHOTOS = new Set(MEDIA);
let mediaDownload;
let publicFetchCount=0;
self.addEventListener('message',event=>{
  if(!event.ports?.[0])return;
  if(event.data?.type==='ATLAS_CACHE_MEDIA') {
    if(!mediaDownload)mediaDownload=cacheFiles(MEDIA,2,MEDIA_CACHE).finally(()=>{mediaDownload=null;});
    event.waitUntil(mediaDownload.then(errors=>event.ports[0].postMessage({ok:errors.length===0,errors:errors.length})));
    return;
  }
  if(event.data?.type!=='ATLAS_OFFLINE_STATUS')return;
  event.waitUntil((async()=>{
    const cache=await caches.open(CACHE);
    const coreReady=(await Promise.all(CORE.map(path=>cache.match(path)))).every(Boolean);
    const photos=await caches.open(MEDIA_CACHE);
    const mediaCached=(await Promise.all(MEDIA.map(path=>photos.match(path)))).filter(Boolean).length;
    event.ports[0].postMessage({version:VERSION,ready:coreReady&&mediaCached===MEDIA.length,coreReady,files:CORE.length+MEDIA.length,mediaFiles:MEDIA.length,mediaCached,mediaBytes:MEDIA_BYTES,publicFetchCount});
  })());
});
async function cacheFiles(paths,concurrency,cacheName=CACHE) {
  const cache=await caches.open(cacheName),errors=[];let cursor=0;
  await Promise.all(Array.from({length:concurrency},async()=>{
    while(cursor<paths.length) {
      const path=paths[cursor++];
      if(await cache.match(path))continue;
      // A new app cache must not inherit an older runtime from HTTP cache.
      try {await cache.add(new Request(new URL(path,self.location.origin),{cache:'reload'}));}catch {errors.push(path);}
    }
  }));
  return errors;
}
self.addEventListener('install', event => event.waitUntil((async()=>{
  const errors=await cacheFiles(CORE,4);
  if(errors.length)throw Error('Essential offline download incomplete');
  await self.skipWaiting();
})()));
self.addEventListener('activate', event => event.waitUntil((async()=>{
  for(const key of await caches.keys()) {
    if((key.startsWith('skool-atlas-')||key.startsWith('flutter-'))&&key!==CACHE)await caches.delete(key);
    if(key.startsWith('atlas-photos-')&&key!==MEDIA_CACHE)await caches.delete(key);
  }
  await self.clients.claim();
})()));
self.addEventListener('fetch', event => {
  const request=event.request,url=new URL(request.url);
  if(request.method!=='GET'||url.origin!==self.location.origin||url.pathname.startsWith('/api/')||url.pathname==='/admin'||url.pathname==='/family'||url.pathname.startsWith('/cdn-cgi/'))return;
  publicFetchCount++;
  // Only the build's public shell is a fallback, never an arbitrary server page.
  const isShell=url.pathname==='/'||url.pathname==='/index.html'||/^\/offline-status(?:\.html)?\/?$/.test(url.pathname);
  if(request.mode==='navigate'||isShell) {
    event.respondWith(fetch(request).catch(async()=>{
      const cache=await caches.open(CACHE);
      const saved=await cache.match(/^\/offline-status(?:\.html)?\/?$/.test(url.pathname)?'/offline-status.html':'/index.html');
      // Cloudflare redirects /index.html to /. A cached redirected response
      // cannot satisfy a browser navigation with redirect mode "manual".
      return saved?new Response(saved.body,{status:saved.status,statusText:saved.statusText,headers:saved.headers}):Response.error();
    }));
    return;
  }
  const isAsset=(ESSENTIAL.has(url.pathname)||/^\/(?:assets|icons|canvaskit)\//.test(url.pathname))&&/\.(?:js|wasm|json|png|jpe?g|webp|svg|ttf|otf|woff2?|bin)$/.test(url.pathname);
  if(!isAsset)return;
  event.respondWith((async()=>{
    const cache=await caches.open(PHOTOS.has(url.pathname)?MEDIA_CACHE:CACHE);
    // Versioned runtime/data stay together and do not wait on a dead network.
    if(ESSENTIAL.has(url.pathname)||PHOTOS.has(url.pathname)) {
      const saved=await cache.match(url.pathname);
      if(saved)return saved;
    }
    try {
      const response=await fetch(request);
      if(response.ok&&response.type!=='opaque')await cache.put(request,response.clone());
      return response;
    } catch {return await cache.match(request)||Response.error();}
  })());
});

self.addEventListener('push', event => {
  let payload = {}; try { payload = event.data?.json() || {}; } catch {}
  event.waitUntil(self.registration.showNotification('Tertiary Atlas reminder', {
    body: 'A personal application target is tomorrow. Open My journey to review your plans.',
    icon: '/icons/Icon-192.png', badge: '/icons/Icon-192.png', tag: 'atlas-personal-target',
    data: {url: '/?journey=1'}
  }));
});
self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.waitUntil((async () => {
    const url = new URL('/?journey=1', self.location.origin).href;
    const open = await self.clients.matchAll({type: 'window', includeUncontrolled: true});
    for (const client of open) { if (new URL(client.url).origin === self.location.origin) { await client.navigate(url); return client.focus(); } }
    return self.clients.openWindow(url);
  })());
});
