// Inline script for layout.tsx that runs synchronously before first paint.
//
// 1. Legacy links. The Flutter app used to live at the nosus.foo root, so
//    burn/share/invite links in the wild (and Supabase auth callbacks) still
//    resolve here. Their key material rides in the hash fragment, which never
//    reaches a server, so only a client-side redirect can carry it to the app.
//    This layout also wraps 404.html, covering path-style legacy links.
//
// 2. Analytics. Cloudflare Web Analytics is loaded from here — and only here —
//    so it can never see a key: it is skipped whenever the page forwards, and
//    whenever the fragment is anything but a plain in-page anchor (#features).
//    If a key-bearing fragment arrives later (pasted into the address bar on
//    an open tab), the fragment is stripped before forwarding, so the beacon's
//    exit report cannot carry it either. "spa": false keeps the beacon to one
//    report per page load instead of following URL changes.
//
// 3. Private pages. /go (borrowed computer), /to (Drop), and every
//    <handle>.nosus.foo address never load the beacon.
//
// Tested in scripts/legacy-link-shim.test.cjs — keep that in step.

export const CLOUDFLARE_BEACON_SRC =
  "https://static.cloudflareinsights.com/beacon.min.js";

export function legacyLinkShim(analyticsToken: string): string {
  // The token is interpolated into inline script HTML. Cloudflare site tokens
  // are plain alphanumerics; refusing anything else at build time means a
  // mistyped value can never close the <script> element or inject code.
  if (!/^[A-Za-z0-9]*$/.test(analyticsToken)) {
    throw new Error("CLOUDFLARE_WEB_ANALYTICS_TOKEN must be alphanumeric");
  }
  return `(function(w,token){try{
var APP="https://app.nosus.foo";
function appTarget(){
var l=w.location,h=l.hash||"",p=l.pathname||"/",s=l.search||"";
var appHash=/^#\\/?(burn|burnfiles|burnfile|redeem|v|join|go)\\//.test(h);
var appPath=/^\\/(burn|burnfiles|burnfile|redeem|v|join|go)\\//.test(p);
var authCb=/(access_token|refresh_token|error_description|type=recovery)/.test(h)||/[?&]code=/.test(s);
return appHash||appPath||authCb?APP+(appPath?p:"/")+s+h:null;
}
function handoff(url){
var ua="";
try{ua=(w.navigator&&w.navigator.userAgent)||"";}catch(e){}
if(!/android/i.test(ua)){w.location.replace(url);return;}
var enc=encodeURIComponent(url);
w.location.replace("intent://open?u="+enc+"#Intent;scheme=foo.nosus.app;package=foo.nosus.app;S.browser_fallback_url="+enc+";end");
}
var t=appTarget();
if(t){handoff(t);return;}
w.addEventListener("hashchange",function(){
var next=appTarget();
if(!next)return;
try{w.history.replaceState(null,"",w.location.pathname+w.location.search);}catch(e){}
handoff(next);
});
if(/^\\/(go|to)(?:\\.html)?\\/?$/.test(w.location.pathname||"/"))return;
var host=(w.location.hostname||"").toLowerCase();
if(/\\.nosus\\.foo$/.test(host)&&!/^(www\\.)?nosus\\.foo$/.test(host))return;
if(!token)return;
var h=w.location.hash||"";
if(h&&!/^#[A-Za-z][\\w-]*$/.test(h))return;
var d=w.document,sc=d.createElement("script");
sc.src=${JSON.stringify(CLOUDFLARE_BEACON_SRC)};
sc.type="module";
sc.setAttribute("data-cf-beacon",JSON.stringify({token:token,spa:false}));
d.head.appendChild(sc);
}catch(e){}})(window,${JSON.stringify(analyticsToken)});`;
}
