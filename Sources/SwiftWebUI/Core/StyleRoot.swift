import SwiftHTML
import SwiftWebUITheme
import SwiftWebStyle

struct StyleRoot<Content: HTML>: Component {
    @Environment(\.preferredColorScheme) private var preferredColorScheme: ColorScheme?
    @Environment(\.styleSystem) private var styleSystem: StyleSystem

    private let content: Content

    init(@HTMLBuilder _ content: () -> Content) {
        self.content = content()
    }

    @HTMLBuilder
    var body: some HTML {
        if let registry = StyleRegistry.current {
            let css = RootStylesheet.css(for: styleSystem)
            let _ = registry.registerStylesheet(css)
            let _ = registry.registerScript(id: "swui-glass-refraction", body: StyleRootAssets.refractionScript)
            let _ = registry.registerScript(id: "swui-slider-sync", body: StyleRootAssets.sliderScript)
            EmptyHTML()
        } else {
            style {
                rawHTML(RootStylesheet.css(for: styleSystem))
            }
            rawHTML(StyleRootAssets.refractionScriptTag)
            rawHTML(StyleRootAssets.sliderScriptTag)
        }
        div {
            content
        }
        .attributes(rootAttributes)
    }

    private var rootAttributes: [HTMLAttribute] {
        var attributes: [HTMLAttribute] = []
        if let preferredColorScheme {
            attributes.append(.data("color-scheme", preferredColorScheme.rawValue))
        }
        attributes.append(.data("style-system", styleSystem.id))
        attributes.append(.class("swui-root"))
        return attributes
    }
}

private enum StyleRootAssets {
    static var refractionScriptTag: String {
        "<script>\(refractionScript)</script>"
    }

    static var sliderScriptTag: String {
        "<script>\(sliderScript)</script>"
    }

    // Mirrors each slider's native range value into `--swui-slider-progress` on
    // its `.swui-slider` wrapper so the custom fill and Liquid Glass thumb follow
    // the value instantly on the client (no WASM round-trip for the visual). The
    // native input owns the value: its trusted `input`/`change` events commit the
    // binding, and because the native thumb is sized to match the visible thumb
    // (see the stylesheet) the value<->position mapping lines the visible thumb up
    // under the cursor. Sliders added later (hydration) are bound via a
    // MutationObserver.
    static let sliderScript = """
    (function(){
    if(window.__swuiSlider)return;window.__swuiSlider=true;
    function num(v,d){v=parseFloat(v);return isFinite(v)?v:d;}
    function progress(inp){var mn=num(inp.min,0),mx=num(inp.max,100),v=num(inp.value,mn);return mx>mn?(v-mn)/(mx-mn):0;}
    function sync(inp){var w=inp.closest('.swui-slider');if(w)w.style.setProperty('--swui-slider-progress',String(progress(inp)));}
    function bind(inp){if(inp.__swuiSliderBound)return;inp.__swuiSliderBound=true;
    inp.addEventListener('input',function(){sync(inp);});
    inp.addEventListener('change',function(){sync(inp);});
    sync(inp);}
    function scan(){document.querySelectorAll('.swui-slider-input').forEach(bind);}
    function boot(){scan();if(window.MutationObserver){new MutationObserver(scan).observe(document.documentElement,{childList:true,subtree:true});}}
    if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot);else boot();
    })();
    """

    // Liquid Glass is generated per element on the client, following the method
    // in https://kube.io/blog/liquid-glass-css-svg/ with the optical model from
    // AndrewPrifer/liquid-dom. The maps have to match each surface's exact pixel
    // size and corner radius — one stretched global filter folds the corners into
    // a bright caustic. A canvas builds two maps from the rounded-rect
    // signed-distance field: a displacement map (in a fixed-width rim band, the
    // displacement points along the outward normal scaled by a Snell's-law
    // refraction profile normalized to a peak of 1, so the magnitude is uniform
    // around the whole perimeter and never concentrates into a focal point) and a
    // specular map (a rim highlight on the light-facing edge and a dimmer one on
    // the opposite edge). The filter refracts the backdrop in three passes at a
    // small per-channel scale spread (dispersion, the coloured edge), screens the
    // highlight on top, and is applied as `backdrop-filter: url(...)` on each
    // `.swui-glass`, recomputed on resize. Chromium applies it; Safari keeps the
    // CSS blur fallback.
    static let refractionScript = """
    (function(){
    if(window.__swuiGlass)return;window.__swuiGlass=true;
    var ETA=1/1.5,NS=128,OPP=0.45,DISP=0.07;
    // Fixed -45 deg key light for the specular highlight, in-plane. The rim
    // facing the light gets the full highlight; the opposite rim gets it at OPP.
    var LA=-45*Math.PI/180,LX2=Math.cos(LA),LY2=Math.sin(LA);
    // Signed distance of a point to a rounded rectangle (negative inside).
    function sdf(px,py,hw,hh,r){
    var qx=Math.abs(px)-hw+r,qy=Math.abs(py)-hh+r;
    return Math.min(Math.max(qx,qy),0)+Math.hypot(Math.max(qx,0),Math.max(qy,0))-r;
    }
    // 1D bevel profile across the rim band: the Snell refraction shift through a
    // convex squircle surface, normalized to a peak of 1, plus the surface tilt
    // (sin/cos) used to light the specular highlight. Same for every element.
    function buildProfile(){
    var dp=new Float32Array(NS),st=new Float32Array(NS),mx=0,i;
    for(i=0;i<NS;i++){
    var x=i/(NS-1),ox=1-x,u=1-Math.pow(ox,4);
    var slope=u<=1e-5?80:Math.pow(ox,3)/Math.pow(u,0.75);if(slope>80)slope=80;
    var nl=Math.hypot(slope,1);st[i]=slope/nl;
    var Nx=-slope/nl,Ny=1/nl,cosi=Ny,k=1-ETA*ETA*(1-cosi*cosi),dx=0;
    if(k>=0){var c=ETA*cosi-Math.sqrt(k),Tx=c*Nx,Ty=-ETA+c*Ny;if(Ty<0)dx=Tx/(-Ty);}
    dp[i]=dx;var a=Math.abs(dx);if(a>mx)mx=a;
    }
    for(i=0;i<NS;i++)dp[i]=mx>0?dp[i]/mx:0;
    return {dp:dp,st:st};
    }
    var P=buildProfile();
    // One pass over the rim band builds both maps. The displacement points along
    // the SDF's outward unit normal scaled by the normalized profile, so its
    // magnitude is uniform all the way around (corners included) and never folds
    // into a caustic. The specular is the surface normal dotted with the fixed
    // light. The centre stays neutral (no displacement, no highlight).
    function genMaps(w,h,r,bezel,specOp,sharp){
    var cd=document.createElement('canvas');cd.width=w;cd.height=h;
    var cs=document.createElement('canvas');cs.width=w;cs.height=h;
    var xd=cd.getContext('2d'),xs=cs.getContext('2d');
    var di=xd.createImageData(w,h),si=xs.createImageData(w,h),dd=di.data,sd=si.data,hw=w/2,hh=h/2,x,y;
    for(y=0;y<h;y++)for(x=0;x<w;x++){
    var px=x-hw+0.5,py=y-hh+0.5,dist=-sdf(px,py,hw,hh,r),R=NS,G=NS,sp=0;
    if(dist>=0&&dist<bezel){
    var t=dist/bezel,idx=Math.min(NS-1,Math.round(t*(NS-1))),mag=P.dp[idx];
    var gx=sdf(px+1,py,hw,hh,r)-sdf(px-1,py,hw,hh,r);
    var gy=sdf(px,py+1,hw,hh,r)-sdf(px,py-1,hw,hh,r);
    var gl=Math.hypot(gx,gy)||1,nx=gx/gl,ny=gy/gl;
    R=NS+nx*mag*127;G=NS+ny*mag*127;
    var ip=nx*LX2+ny*LY2,main=Math.pow(Math.max(0,ip),sharp),opp=OPP*Math.pow(Math.max(0,-ip),sharp);
    sp=(main+opp)*P.st[idx];
    }
    var o=(y*w+x)*4;
    dd[o]=R;dd[o+1]=G;dd[o+2]=NS;dd[o+3]=255;
    var v=Math.round(255*Math.min(1,sp)*specOp);sd[o]=v;sd[o+1]=v;sd[o+2]=v;sd[o+3]=255;
    }
    xd.putImageData(di,0,0);xs.putImageData(si,0,0);
    return {d:cd.toDataURL(),s:cs.toDataURL()};
    }
    // Refract the backdrop with a small per-channel scale spread (dispersion,
    // the coloured glass edge), then screen the specular highlight on top.
    function flt(w,h,dm,sm,scale){
    var sR=Math.round(scale*(1+DISP)),sB=Math.round(scale*(1-DISP));
    var s="<svg height='"+h+"' width='"+w+"' viewBox='0 0 "+w+" "+h+"' xmlns='http://www.w3.org/2000/svg'><defs>"
    +"<filter id='d' color-interpolation-filters='sRGB'>"
    +"<feImage x='0' y='0' width='"+w+"' height='"+h+"' href='"+dm+"' result='dm'/>"
    +"<feDisplacementMap in='SourceGraphic' in2='dm' scale='"+sR+"' xChannelSelector='R' yChannelSelector='G'/><feColorMatrix type='matrix' values='1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0' result='cr'/>"
    +"<feDisplacementMap in='SourceGraphic' in2='dm' scale='"+scale+"' xChannelSelector='R' yChannelSelector='G'/><feColorMatrix type='matrix' values='0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 1 0' result='cg'/>"
    +"<feDisplacementMap in='SourceGraphic' in2='dm' scale='"+sB+"' xChannelSelector='R' yChannelSelector='G'/><feColorMatrix type='matrix' values='0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0 0 0 1 0' result='cb'/>"
    +"<feBlend in='cr' in2='cg' mode='screen' result='rg'/><feBlend in='rg' in2='cb' mode='screen' result='ref'/>"
    +"<feImage x='0' y='0' width='"+w+"' height='"+h+"' href='"+sm+"' result='sp'/>"
    +"<feBlend in='ref' in2='sp' mode='screen'/>"
    +"</filter></defs></svg>";
    return "data:image/svg+xml,"+encodeURIComponent(s)+"#d";
    }
    function hasFilter(el){
    var f=el.style.backdropFilter||el.style.webkitBackdropFilter||"";
    return f.indexOf("url(")!==-1;
    }
    function apply(el){
    var b=el.getBoundingClientRect(),w=Math.round(b.width),h=Math.round(b.height);
    if(w<2||h<2)return;
    var cs=getComputedStyle(el),r=Math.min(parseFloat(cs.borderTopLeftRadius)||0,Math.min(w,h)/2);
    if(el.__lw===w&&el.__lh===h&&el.__lr===r&&hasFilter(el))return;el.__lw=w;el.__lh=h;el.__lr=r;
    // Optional per-element tuning. Small surfaces (e.g. a switch thumb) need a
    // proportionally thinner rim band and smaller displacement than the panel
    // defaults, or both overshoot the element and smear the backdrop. An
    // element opts in with `--swui-glass-bezel` / `--swui-glass-scale`; panels
    // leave them unset and keep the size-derived defaults.
    var bezelO=parseFloat(cs.getPropertyValue('--swui-glass-bezel'));
    var scaleO=parseFloat(cs.getPropertyValue('--swui-glass-scale'));
    var bezel=bezelO>0?Math.min(bezelO,Math.min(w,h)/2):Math.max(10,Math.min(20,Math.round(Math.min(w,h)*0.13)));
    var scale=scaleO>0?scaleO:Math.max(40,Math.min(90,Math.round(bezel*3.8)));
    var sf=Math.min(1,420/Math.max(w,h)),mw=Math.max(2,Math.round(w*sf)),mh=Math.max(2,Math.round(h*sf));
    var m=genMaps(mw,mh,r*sf,Math.max(2,bezel*sf),0.45,2);
    var f="blur(2.5px) url(\\""+flt(w,h,m.d,m.s,scale)+"\\")";
    el.style.backdropFilter=f;el.style.webkitBackdropFilter=f;
    }
    var observed=new Map();
    function cleanup(){
    observed.forEach(function(ro,el){
    if(!el.isConnected){if(ro)ro.disconnect();observed.delete(el);delete el.__lw;delete el.__lh;delete el.__lr;}
    });
    }
    function watch(el){
    if(observed.has(el)){apply(el);return;}
    apply(el);
    if(window.ResizeObserver){var ro=new ResizeObserver(function(){apply(el);});ro.observe(el);observed.set(el,ro);}
    else{observed.set(el,null);}
    }
    var pending=false;
    function scan(){if(pending)return;pending=true;requestAnimationFrame(function(){pending=false;cleanup();document.querySelectorAll('.swui-glass').forEach(watch);});}
    function boot(){scan();if(window.MutationObserver){new MutationObserver(scan).observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:['class','style']});}}
    if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot);else boot();
    })();
    """
}
