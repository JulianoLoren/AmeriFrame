#include "Geometry.hpp"
#include <iostream>
#include <iomanip>
int main() {
    std::string id; int n; double w,h,gap;
    std::cout << std::setprecision(17);
    while(std::cin >> id >> n >> w >> h >> gap) {
        try {auto values=mosaic::packedFrame(id,n,w,h,gap);for(auto v:values)std::cout<<v<<' ';std::cout<<'\n';}
        catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}
    }
}
