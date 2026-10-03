#include "Geometry.hpp"
#include <algorithm>
#include <cmath>
#include <functional>
#include <limits>
#include <stdexcept>

namespace mosaic {
namespace {
constexpr double pi = 3.14159265358979323846;
Polygon rect(double x=0, double y=0, double w=1, double h=1) {
    return {{x,y},{x+w,y},{x+w,y+h},{x,y+h}};
}
Polygon clip(const Polygon& p, double nx, double ny, double d) {
    Polygon out;
    double magnitude = std::max(std::abs(d), std::numeric_limits<double>::epsilon());
    for (auto a:p) magnitude=std::max(magnitude,std::abs(a.x*nx)+std::abs(a.y*ny));
    const double epsilon=1e-11*magnitude;
    for (size_t i=0;i<p.size();++i) {
        auto a=p[i], b=p[(i+1)%p.size()];
        double da=a.x*nx+a.y*ny-d, db=b.x*nx+b.y*ny-d;
        if(std::abs(da)<epsilon) da=0;
        if(std::abs(db)<epsilon) db=0;
        if(da>=0) out.push_back(a);
        if((da>0&&db<0)||(da<0&&db>0)) {
            double t=da/(da-db); out.push_back({a.x+(b.x-a.x)*t,a.y+(b.y-a.y)*t});
        }
    }
    Polygon clean;
    double scale=std::numeric_limits<double>::epsilon();
    for(auto a:out) scale=std::max({scale,std::abs(a.x),std::abs(a.y)});
    for(size_t i=0;i<out.size();++i) {
        auto a=out[i], b=out[(i+out.size()-1)%out.size()];
        if(std::hypot(a.x-b.x,a.y-b.y)>1e-11*scale) clean.push_back(a);
    }
    return clean;
}
Cells split(const Polygon& p,double angle,double fraction=.5) {
    double nx=std::cos(angle),ny=std::sin(angle),lo=INFINITY,hi=-INFINITY;
    for(auto a:p) {double v=a.x*nx+a.y*ny;lo=std::min(lo,v);hi=std::max(hi,v);}
    double target=area(p)*fraction;
    for(int i=0;i<38;++i) {double mid=(lo+hi)/2;if(area(clip(p,-nx,-ny,-mid))<target)lo=mid;else hi=mid;}
    double d=(lo+hi)/2;return {clip(p,-nx,-ny,-d),clip(p,nx,ny,d)};
}
Cells grow(Cells out,int n,const std::function<double(int,Box)>& angle,double fraction=.5) {
    while(int(out.size())<n) {
        size_t best=0;
        for(size_t i=1;i<out.size();++i) if(area(out[i])>area(out[best]))best=i;
        auto halves=split(out[best],angle(int(out.size()),bounds(out[best])),fraction);
        out.erase(out.begin()+best);out.insert(out.begin()+best,halves.begin(),halves.end());
    }
    return out;
}
Cells weighted(int n,std::vector<double> weights,double offset=0) {
    int rows=std::min(n,int(weights.size()));double total=0,y=0;Cells out;
    for(int r=0;r<rows;++r)total+=weights[r];
    for(int r=0;r<rows;++r) {
        int count=n/rows+(r<n%rows?1:0);double h=weights[r]/total,x=0,sum=0;std::vector<double> widths;
        for(int i=0;i<count;++i){double w=1+offset*std::sin((i+1)*(r+1)*1.8);widths.push_back(w);sum+=w;}
        for(double width:widths){double w=width/sum;out.push_back(rect(x,y,w,h));x+=w;}y+=h;
    }
    return out;
}
Cells rotate(Cells out){for(auto& p:out)for(auto& a:p)a={a.y,1-a.x};return out;}
Cells spiral(int n,bool alternate=false) {
    Cells out;double x=0,y=0,w=1,h=1;
    for(int i=0;i<n-1;++i) {
        double f=std::clamp(1/(std::sqrt(n-i)+.4),.16,.44);int dir=alternate?(i%2?3:0):i%4;
        if(dir==0){out.push_back(rect(x,y,w*f,h));x+=w*f;w*=1-f;}
        if(dir==1){out.push_back(rect(x,y,w,h*f));y+=h*f;h*=1-f;}
        if(dir==2){out.push_back(rect(x+w*(1-f),y,w*f,h));w*=1-f;}
        if(dir==3){out.push_back(rect(x,y+h*(1-f),w,h*f));h*=1-f;}
    }
    out.push_back(rect(x,y,w,h));return out;
}
Cells rays(int n,double cx,double cy,double rotation) {
    if(n==2)return split(rect(),rotation,.46);
    Cells out;
    for(int i=0;i<n;++i) {
        double a=rotation+i*pi*2/n,b=a+pi*2/n;
        out.push_back(clip(clip(rect(),-std::sin(a),std::cos(a),-std::sin(a)*cx+std::cos(a)*cy),std::sin(b),-std::cos(b),std::sin(b)*cx-std::cos(b)*cy));
    }
    return out;
}
Cells seeds(int n,const std::string& kind) {
    int cols=int(std::ceil(std::sqrt(n))),rows=int(std::ceil(double(n)/cols));Polygon points;Cells out;
    for(int i=0;i<n;++i) {
        int row=i/cols,col=i%cols;Point p;
        if(kind=="honeycomb")p={(.5+col+(row%2)*.45)/(cols+.45),(.5+row)/rows};
        else if(kind=="constellation"){double a=i*2.399963229728653,r=.44*std::sqrt((i+.5)/n);p={.5+r*std::cos(a),.5+r*std::sin(a)};}
        else if(kind=="dunes")p={(col+.5+.22*std::sin(i*3.1))/cols,(row+.5+.22*std::cos(i*2.7))/rows};
        else if(kind=="orbit"){double a=(i-1)*pi*2/(n-1)+.2;p=i==0?Point{.5,.5}:Point{.5+.43*std::cos(a),.5+.43*std::sin(a)};}
        else {double a=i*pi*2/n+.31,r=i%2?.46:.24;p={.5+r*std::cos(a),.5+r*std::sin(a)};}
        points.push_back(p);
    }
    for(int i=0;i<n;++i) {
        auto p=rect();auto a=points[i];
        for(int j=0;j<n;++j)if(i!=j){auto b=points[j];p=clip(p,a.x-b.x,a.y-b.y,(a.x*a.x+a.y*a.y-b.x*b.x-b.y*b.y)/2);}
        out.push_back(p);
    }
    return out;
}
Cells tiles(int n,int rows,bool stagger=false) {
    Cells out;
    for(int r=0;r<rows;++r) {
        int count=n/rows+(r<n%rows?1:0);double x=0;
        for(int c=0;c<count;++c) {
            double width=stagger&&count>1?(c==0?(r%2?.6:1.4):c==count-1?(r%2?1.4:.6):1):1;
            out.push_back(rect(x,double(r)/rows,width/count,1.0/rows));x+=width/count;
        }
    }
    return out;
}
Cells subdivide(int n,bool angled=false) {
    Cells out={rect()};
    while(int(out.size())<n) {
        size_t best=0;for(size_t i=1;i<out.size();++i)if(area(out[i])>area(out[best]))best=i;
        auto p=out[best];auto b=bounds(p);bool vertical=b.w>b.h*.95;
        double nx=vertical?1:0,ny=vertical?0:1;
        if(angled){if(vertical)ny=out.size()%2?.42:-.42;else nx=out.size()%2?.38:-.38;}
        double lo=INFINITY,hi=-INFINITY;for(auto a:p){double v=a.x*nx+a.y*ny;lo=std::min(lo,v);hi=std::max(hi,v);}
        double d=(lo+hi)/2;out.erase(out.begin()+best);
        out.insert(out.begin()+best,{clip(p,nx,ny,d),clip(p,-nx,-ny,-d)});
    }
    return out;
}
Polygon inset(const Polygon& p,double distance) {
    auto result=p;
    for(size_t i=0;i<p.size();++i) {
        auto a=p[i],b=p[(i+1)%p.size()];double dx=b.x-a.x,dy=b.y-a.y,len=std::hypot(dx,dy);
        if(len<1e-8)continue;
        double nx=-dy/len,ny=dx/len;result=clip(result,nx,ny,nx*a.x+ny*a.y+distance);
    }
    return result;
}
}
double area(const Polygon& p) {
    double sum=0;for(size_t i=0;i<p.size();++i){auto a=p[i],b=p[(i+1)%p.size()];sum=sum+a.x*b.y-b.x*a.y;}return std::abs(sum/2);
}
Box bounds(const Polygon& p) {
    if(p.empty())return {0,0,0,0};
    double x=INFINITY,y=INFINITY,r=-INFINITY,b=-INFINITY;
    for(auto a:p){x=std::min(x,a.x);y=std::min(y,a.y);r=std::max(r,a.x);b=std::max(b,a.y);}return {x,y,r-x,b-y};
}
Cells polygons(const std::string& id,int n,double ratio) {
    if(n<1||n>24||!std::isfinite(ratio)||ratio<.2||ratio>5)throw std::invalid_argument("Invalid collage geometry");
    if(n==1)return {rect()};
    if(id=="gallery")return weighted(n,{1.65,1,1.2});
    if(id=="triptych")return rotate(weighted(n,{1,1.8,1}));
    if(id=="panorama")return weighted(n,{1,2.8,1},.15);
    if(id=="shelves")return weighted(n,{1.4,1,.7,1.1},.4);
    if(id=="window")return grow({rect()},n,[ratio](int,Box b){return b.w*ratio>b.h?0:pi/2;},.38);
    if(id=="ribbon")return weighted(n,{2.8,1},.25);
    if(id=="spiral")return spiral(n);
    if(id=="terraces")return spiral(n,true);
    if(id=="weave")return rotate(spiral(n));
    if(id=="pinwheel")return grow({rect()},n,[](int i,Box){return i*pi/3+.2;},.42);
    if(id=="origami")return grow({rect()},n,[](int i,Box b){return (b.w>b.h?0:pi/2)+(i%2?.72:-.72);});
    if(id=="facets")return grow({rect()},n,[](int i,Box){return i*2.399963+.35;},.38);
    if(id=="sail")return grow({rect()},n,[](int i,Box){return i%2?pi/4:pi*3/4;});
    if(id=="lightning")return grow({rect()},n,[](int i,Box){return i%2?-.9:.9;},.36);
    if(id=="wave")return grow({rect()},n,[](int i,Box b){return (b.w>b.h?0:pi/2)+std::sin(i*1.4)*.28;},.44);
    if(id=="canyon")return grow({rect()},n,[](int i,Box){return std::sin(i*2)*.18;},.55);
    if(id=="rays")return rays(n,.24,.72,-.38);
    if(id=="honeycomb"||id=="constellation"||id=="dunes"||id=="orbit"||id=="burst")return seeds(n,id);
    if(id=="diamond") {
        if(n<5)return rays(n,.5,.5,.1);
        return grow({{{.5,0},{1,.5},{.5,1},{0,.5}},{{0,0},{.5,0},{0,.5}},{{.5,0},{1,0},{1,.5}},{{1,.5},{1,1},{.5,1}},{{0,.5},{.5,1},{0,1}}},n,[](int,Box b){return b.w>b.h?0:pi/2;});
    }
    if(id=="cross") {
        if(n<5)return weighted(n,{1,2},.55);
        return grow({rect(.25,.25,.5,.5),rect(0,0,.75,.25),rect(.75,0,.25,.75),rect(.25,.75,.75,.25),rect(0,.25,.25,.75)},n,[](int,Box b){return b.w>b.h?0:pi/2;});
    }
    if(id=="columns"||id=="rows") {
        Cells out;for(int i=0;i<n;++i)out.push_back(id=="columns"?rect(double(i)/n,0,1.0/n,1):rect(0,double(i)/n,1,1.0/n));return out;
    }
    if(id=="hero"||id=="editorial"||id=="film") {
        bool horizontal=id=="film";double large=id=="editorial"?.62:.58;
        auto rest=tiles(n-1,std::min(n-1,std::max(1,int(std::round(std::sqrt(n-1)*(horizontal?.55:1.5))))));
        for(auto& p:rest)for(auto& a:p){if(horizontal)a.y=large+a.y*(1-large);else a.x=large+a.x*(1-large);}
        rest.insert(rest.begin(),horizontal?rect(0,0,1,large):rect(0,0,large,1));return rest;
    }
    if(id=="mosaic"||id=="shards")return subdivide(n,id=="shards");
    if(id=="diagonal") {
        Cells out;for(int i=0;i<n;++i)out.push_back(clip(clip(rect(),1,.5,1.5*i/n),-1,-.5,-1.5*(i+1)/n));return out;
    }
    if(id=="chevron") {
        if(n<5)return subdivide(n,true);
        int left=int(std::ceil((n-2)/2.0)),right=n-2-left;Cells out;
        for(int i=0;i<left;++i)out.push_back({{0,double(i)/left},{.5,.2+i*.6/left},{.5,.2+(i+1)*.6/left},{0,double(i+1)/left}});
        out.push_back({{0,0},{1,0},{.5,.2}});out.push_back({{0,1},{.5,.8},{1,1}});
        for(int i=0;i<right;++i)out.push_back({{.5,.2+i*.6/right},{1,double(i)/right},{1,double(i+1)/right},{.5,.2+(i+1)*.6/right}});
        return out;
    }
    if(id=="fan")return n==2?subdivide(n,true):rays(n,.5,.5,-pi/4);
    return tiles(n,std::min(n,std::max(1,int(std::round(std::sqrt(n/ratio))))),id=="brick");
}
Frame frame(const std::string& id,int n,double w,double h,double requestedGap) {
    if(!std::isfinite(w)||!std::isfinite(h)||w<=0||h<=0||!std::isfinite(requestedGap)||requestedGap<0)throw std::invalid_argument("Invalid frame size");
    auto base=polygons(id,n,w/h);double gap=requestedGap;
    for(int i=0;i<30;++i) {
        Cells inner;bool valid=true;double pad=gap/2;
        for(auto p:base) {
            for(auto& a:p)a={pad+a.x*(w-2*pad),pad+a.y*(h-2*pad)};
            auto cell=inset(p,gap/2);if(cell.size()<3||area(cell)<=area(p)*.25)valid=false;inner.push_back(cell);
        }
        if(valid)return {inner,gap};gap*=.8;
    }
    for(auto& p:base)for(auto& a:p)a={a.x*w,a.y*h};return {base,0};
}
std::vector<double> packedFrame(const std::string& id,int n,double w,double h,double gap) {
    auto result=frame(id,n,w,h,gap);std::vector<double> out={result.gap};
    for(auto p:result.cells){out.push_back(double(p.size()));for(auto a:p){out.push_back(a.x);out.push_back(a.y);}}return out;
}

const std::vector<Layout>& layouts() {
    static const std::vector<Layout> catalog = {
        {"grid", "classic", "Lưới", "Grid"},
        {"columns", "classic", "Dọc", "Columns"},
        {"rows", "classic", "Ngang", "Rows"},
        {"hero", "classic", "Tiêu điểm", "Spotlight"},
        {"editorial", "classic", "Tạp chí", "Editorial"},
        {"film", "classic", "Điện ảnh", "Cinema"},
        {"brick", "creative", "Lát gạch", "Brickwork"},
        {"mosaic", "creative", "Khảm", "Mosaic"},
        {"diagonal", "creative", "Đường chéo", "Diagonal"},
        {"chevron", "creative", "Zigzag", "Zigzag"},
        {"shards", "creative", "Pha lê", "Prism"},
        {"fan", "creative", "Cánh quạt", "Sunburst"},
        {"gallery", "classic", "Triển lãm", "Gallery"},
        {"triptych", "classic", "Tam liên", "Triptych"},
        {"panorama", "classic", "Toàn cảnh", "Panorama"},
        {"shelves", "classic", "Tầng ảnh", "Shelves"},
        {"window", "classic", "Cửa sổ", "Window"},
        {"ribbon", "classic", "Dải phim", "Filmstrip"},
        {"spiral", "creative", "Xoắn ốc", "Spiral"},
        {"pinwheel", "creative", "Chong chóng", "Pinwheel"},
        {"diamond", "creative", "Kim cương", "Diamond"},
        {"facets", "creative", "Đá quý", "Gemstone"},
        {"honeycomb", "creative", "Tổ ong", "Honeycomb"},
        {"constellation", "creative", "Chòm sao", "Constellation"},
        {"origami", "creative", "Gấp giấy", "Origami"},
        {"lightning", "creative", "Tia chớp", "Lightning"},
        {"wave", "creative", "Sóng", "Wave"},
        {"rays", "creative", "Tia nắng", "Sunrays"},
        {"canyon", "creative", "Hẻm núi", "Canyon"},
        {"terraces", "creative", "Bậc thang", "Terraces"},
        {"cross", "creative", "Giao điểm", "Crossroads"},
        {"orbit", "creative", "Quỹ đạo", "Orbit"},
        {"dunes", "creative", "Cồn cát", "Dunes"},
        {"sail", "creative", "Cánh buồm", "Sails"},
        {"burst", "creative", "Bùng nổ", "Supernova"},
        {"weave", "creative", "Đan lát", "Woven"},
    };
    return catalog;
}
}
