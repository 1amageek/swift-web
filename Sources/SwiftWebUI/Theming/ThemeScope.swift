import SwiftHTML

struct ThemeScope<Content: HTML>: Component {
    @Environment(\.theme) private var theme: Theme
    @Environment(\.styleSystem) private var styleSystem: StyleSystem

    private let content: Content

    init(@HTMLBuilder _ content: () -> Content) {
        self.content = content()
    }

    @HTMLBuilder
    var body: some HTML {
        style {
            rawHTML(ThemeStylesheet.css(for: theme, styleSystem: styleSystem))
        }
        // The client script that gives each `.swui-glass` its own per-element
        // displacement refraction (sized to the surface, recomputed on resize).
        // Chromium applies it for true refraction; Safari ignores `url()`
        // backdrop-filters and keeps the CSS blur fallback.
        rawHTML(ThemeScopeAssets.refractionScript)
        div(
            .data("theme", theme.name),
            .data("style-system", styleSystem.id),
            .class("swui-root")
        ) {
            content
        }
    }
}

private enum ThemeScopeAssets {
    // Liquid Glass refraction is generated per element on the client, because the
    // displacement map has to match each surface's exact pixel size and corner
    // radius — one stretched global SVG filter folds the corners into a bright
    // caustic. A canvas builds the map from the rounded-rect signed-distance
    // field: in a fixed-width rim band the displacement points along the outward
    // normal (the SDF gradient, a unit vector) scaled by a Snell's-law refraction
    // profile that is normalized to a peak magnitude of 1. Because the magnitude
    // is uniform all the way around — corners included — it never concentrates
    // into a focal point. Three displacement passes at staggered scales (R/G/B)
    // add chromatic aberration, applied as a `backdrop-filter: url(...)` on each
    // `.swui-glass`, recomputed on resize. Chromium applies it; Safari keeps the
    // CSS blur fallback.
    static let refractionScript = """
    <script>
    (function(){
    if(window.__swuiGlass)return;window.__swuiGlass=true;
    var ETA=0.66,SIGN=1,NS=128;
    // Signed-distance of a point to a rounded rectangle (negative inside).
    function sdf(px,py,hw,hh,r){
    var qx=Math.abs(px)-hw+r,qy=Math.abs(py)-hh+r;
    return Math.min(Math.max(qx,qy),0)+Math.hypot(Math.max(qx,0),Math.max(qy,0))-r;
    }
    // 1D refraction profile across the bezel: ray-trace a viewing ray through a
    // convex squircle surface with Snell's law, take the lateral shift, and
    // normalize so the peak magnitude is 1. Same profile for every element.
    function buildProfile(){
    var p=new Float32Array(NS),mx=0,i;
    for(i=0;i<NS;i++){
    var x=i/(NS-1),ox=1-x,u=1-Math.pow(ox,4);
    var slope=u<=1e-5?80:Math.pow(ox,3)/Math.pow(u,0.75);if(slope>80)slope=80;
    var nl=Math.hypot(slope,1),Nx=-slope/nl,Ny=1/nl;
    var cosi=Ny,k=1-ETA*ETA*(1-cosi*cosi),dx=0;
    if(k>=0){var c=ETA*cosi-Math.sqrt(k),Tx=c*Nx,Ty=-ETA+c*Ny;if(Ty<0)dx=Tx/(-Ty);}
    p[i]=dx;var a=Math.abs(dx);if(a>mx)mx=a;
    }
    for(i=0;i<NS;i++)p[i]=mx>0?p[i]/mx:0;
    return p;
    }
    var PROF=buildProfile();
    // Per-element displacement map: in the `bezel`-wide rim band the displacement
    // points along the rounded-rect's outward normal (the SDF gradient, a unit
    // vector) scaled by the normalized profile, so its magnitude is uniform all
    // the way around — including the corners, which is why it never folds into a
    // caustic. The centre stays neutral grey (no displacement).
    function genMap(w,h,r,bezel){
    var cv=document.createElement('canvas');cv.width=w;cv.height=h;
    var ctx=cv.getContext('2d'),img=ctx.createImageData(w,h),dt=img.data,hw=w/2,hh=h/2,x,y;
    for(y=0;y<h;y++)for(x=0;x<w;x++){
    var px=x-hw+0.5,py=y-hh+0.5,dist=-sdf(px,py,hw,hh,r),R=NS,G=NS;
    if(dist>=0&&dist<bezel){
    var t=dist/bezel,mag=PROF[Math.min(NS-1,Math.round(t*(NS-1)))]*SIGN;
    var gx=sdf(px+1,py,hw,hh,r)-sdf(px-1,py,hw,hh,r);
    var gy=sdf(px,py+1,hw,hh,r)-sdf(px,py-1,hw,hh,r);
    var gl=Math.hypot(gx,gy)||1;
    R=NS+(gx/gl)*mag*127;G=NS+(gy/gl)*mag*127;
    }
    var o=(y*w+x)*4;dt[o]=R;dt[o+1]=G;dt[o+2]=NS;dt[o+3]=255;
    }
    ctx.putImageData(img,0,0);return cv.toDataURL();
    }
    // The filter: three displacement passes at staggered scales (R/G/B) recombined
    // with screen blends — chromatic aberration that tints the refracted rim.
    function flt(w,h,mp,st,ca){
    var s="<svg height='"+h+"' width='"+w+"' viewBox='0 0 "+w+" "+h+"' xmlns='http://www.w3.org/2000/svg'><defs>"
    +"<filter id='d' color-interpolation-filters='sRGB'>"
    +"<feImage x='0' y='0' width='"+w+"' height='"+h+"' href='"+mp+"' result='m'/>"
    +"<feDisplacementMap in='SourceGraphic' in2='m' scale='"+(st+ca*2)+"' xChannelSelector='R' yChannelSelector='G'/>"
    +"<feColorMatrix type='matrix' values='1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0' result='cr'/>"
    +"<feDisplacementMap in='SourceGraphic' in2='m' scale='"+(st+ca)+"' xChannelSelector='R' yChannelSelector='G'/>"
    +"<feColorMatrix type='matrix' values='0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 1 0' result='cg'/>"
    +"<feDisplacementMap in='SourceGraphic' in2='m' scale='"+st+"' xChannelSelector='R' yChannelSelector='G'/>"
    +"<feColorMatrix type='matrix' values='0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0 0 0 1 0' result='cb'/>"
    +"<feBlend in='cr' in2='cg' mode='screen'/><feBlend in2='cb' mode='screen'/>"
    +"</filter></defs></svg>";
    return "data:image/svg+xml,"+encodeURIComponent(s)+"#d";
    }
    function apply(el){
    var b=el.getBoundingClientRect(),w=Math.round(b.width),h=Math.round(b.height);
    if(w<2||h<2)return;
    if(el.__lw===w&&el.__lh===h)return;el.__lw=w;el.__lh=h;
    var cs=getComputedStyle(el),r=parseFloat(cs.borderTopLeftRadius)||0;
    r=Math.min(r,Math.min(w,h)/2);
    var bezel=Math.max(8,Math.min(28,Math.round(Math.min(w,h)*0.22)));
    var st=Math.max(14,Math.min(70,Math.round(bezel*1.6)));
    var sf=Math.min(1,320/Math.max(w,h));
    var mw=Math.max(2,Math.round(w*sf)),mh=Math.max(2,Math.round(h*sf));
    var mp=genMap(mw,mh,r*sf,Math.max(2,bezel*sf));
    var sat=((cs.getPropertyValue('--swui-material-saturate')||'').trim())||'1.6';
    var br=((cs.getPropertyValue('--swui-material-brightness')||'').trim())||'1.05';
    var f="blur(1px) url(\\""+flt(w,h,mp,st,2)+"\\") saturate("+sat+") brightness("+br+")";
    el.style.backdropFilter=f;el.style.webkitBackdropFilter=f;
    }
    var seen=new WeakSet();
    function watch(el){if(seen.has(el))return;seen.add(el);apply(el);if(window.ResizeObserver){new ResizeObserver(function(){apply(el);}).observe(el);}}
    var pending=false;
    function scan(){if(pending)return;pending=true;requestAnimationFrame(function(){pending=false;document.querySelectorAll('.swui-glass').forEach(watch);});}
    function boot(){scan();if(window.MutationObserver){new MutationObserver(scan).observe(document.documentElement,{childList:true,subtree:true});}}
    if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot);else boot();
    })();
    </script>
    """
}


public extension HTML {
    func environment(
        _ keyPath: WritableKeyPath<EnvironmentValues, Theme>,
        _ value: Theme
    ) -> some HTML {
        EnvironmentModifier(keyPath, value) {
            ThemeScope {
                self
            }
        }
    }
}
