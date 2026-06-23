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
    // Liquid Glass is generated per element on the client, following the method
    // in https://kube.io/blog/liquid-glass-css-svg/. The maps have to match each
    // surface's exact pixel size and corner radius — one stretched global filter
    // folds the corners into a bright caustic. A canvas builds two maps from the
    // rounded-rect signed-distance field: a displacement map (in a fixed-width rim
    // band, the displacement points along the outward normal scaled by a
    // Snell's-law refraction profile normalized to a peak of 1, so the magnitude
    // is uniform around the whole perimeter and never concentrates into a focal
    // point) and a specular map (the surface normal dotted with a fixed light).
    // The filter refracts the backdrop and screens the highlight on top, applied
    // as `backdrop-filter: url(...)` on each `.swui-glass` and recomputed on
    // resize. Chromium applies it; Safari keeps the CSS blur fallback.
    static let refractionScript = """
    <script>
    (function(){
    if(window.__swuiGlass)return;window.__swuiGlass=true;
    var ETA=0.66,NS=128;
    // Fixed light for the specular highlight: -60 deg in plane, raised 42 deg.
    var LA=-60*Math.PI/180,LE=42*Math.PI/180,LX=Math.cos(LA)*Math.cos(LE),LY=Math.sin(LA)*Math.cos(LE),LZ=Math.sin(LE);
    // Signed distance of a point to a rounded rectangle (negative inside).
    function sdf(px,py,hw,hh,r){
    var qx=Math.abs(px)-hw+r,qy=Math.abs(py)-hh+r;
    return Math.min(Math.max(qx,qy),0)+Math.hypot(Math.max(qx,0),Math.max(qy,0))-r;
    }
    // 1D bevel profile across the rim band: the Snell refraction shift through a
    // convex squircle surface, normalized to a peak of 1, plus the surface tilt
    // (sin/cos) used to light the specular highlight. Same for every element.
    function buildProfile(){
    var dp=new Float32Array(NS),st=new Float32Array(NS),ct=new Float32Array(NS),mx=0,i;
    for(i=0;i<NS;i++){
    var x=i/(NS-1),ox=1-x,u=1-Math.pow(ox,4);
    var slope=u<=1e-5?80:Math.pow(ox,3)/Math.pow(u,0.75);if(slope>80)slope=80;
    var nl=Math.hypot(slope,1);st[i]=slope/nl;ct[i]=1/nl;
    var Nx=-slope/nl,Ny=1/nl,cosi=Ny,k=1-ETA*ETA*(1-cosi*cosi),dx=0;
    if(k>=0){var c=ETA*cosi-Math.sqrt(k),Tx=c*Nx,Ty=-ETA+c*Ny;if(Ty<0)dx=Tx/(-Ty);}
    dp[i]=dx;var a=Math.abs(dx);if(a>mx)mx=a;
    }
    for(i=0;i<NS;i++)dp[i]=mx>0?dp[i]/mx:0;
    return {dp:dp,st:st,ct:ct};
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
    var sinT=P.st[idx],cosT=P.ct[idx],dot=nx*sinT*LX+ny*sinT*LY+cosT*LZ;
    if(dot>0)sp=Math.pow(dot,sharp);
    }
    var o=(y*w+x)*4;
    dd[o]=R;dd[o+1]=G;dd[o+2]=NS;dd[o+3]=255;
    var v=Math.round(255*sp*specOp);sd[o]=v;sd[o+1]=v;sd[o+2]=v;sd[o+3]=255;
    }
    xd.putImageData(di,0,0);xs.putImageData(si,0,0);
    return {d:cd.toDataURL(),s:cs.toDataURL()};
    }
    // Refract the backdrop, then screen the specular highlight on top.
    function flt(w,h,dm,sm,scale){
    var s="<svg height='"+h+"' width='"+w+"' viewBox='0 0 "+w+" "+h+"' xmlns='http://www.w3.org/2000/svg'><defs>"
    +"<filter id='d' color-interpolation-filters='sRGB'>"
    +"<feImage x='0' y='0' width='"+w+"' height='"+h+"' href='"+dm+"' result='dm'/>"
    +"<feDisplacementMap in='SourceGraphic' in2='dm' scale='"+scale+"' xChannelSelector='R' yChannelSelector='G' result='ref'/>"
    +"<feImage x='0' y='0' width='"+w+"' height='"+h+"' href='"+sm+"' result='sp'/>"
    +"<feBlend in='ref' in2='sp' mode='screen'/>"
    +"</filter></defs></svg>";
    return "data:image/svg+xml,"+encodeURIComponent(s)+"#d";
    }
    function apply(el){
    var b=el.getBoundingClientRect(),w=Math.round(b.width),h=Math.round(b.height);
    if(w<2||h<2)return;
    if(el.__lw===w&&el.__lh===h)return;el.__lw=w;el.__lh=h;
    var cs=getComputedStyle(el),r=Math.min(parseFloat(cs.borderTopLeftRadius)||0,Math.min(w,h)/2);
    var bezel=Math.max(8,Math.min(30,Math.round(Math.min(w,h)*0.22)));
    var scale=Math.round(bezel*1.4);
    var sf=Math.min(1,360/Math.max(w,h)),mw=Math.max(2,Math.round(w*sf)),mh=Math.max(2,Math.round(h*sf));
    var m=genMaps(mw,mh,r*sf,Math.max(2,bezel*sf),0.55,5);
    var f="url(\\""+flt(w,h,m.d,m.s,scale)+"\\")";
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
