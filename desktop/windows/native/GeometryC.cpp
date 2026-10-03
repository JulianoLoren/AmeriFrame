#include "../../../mobile/core/Geometry.hpp"
#include <algorithm>
#include <exception>
#ifdef _WIN32
#define API extern "C" __declspec(dllexport)
#else
#define API extern "C" __attribute__((visibility("default")))
#endif
// Returns required doubles; negative values indicate invalid input. No C++ object crosses the ABI.
API int mosaic_frame(const char* id, int count, double width, double height, double gap, double* output, int capacity) noexcept {
    try {
        if(!id || capacity<0) return -1;
        auto values=mosaic::packedFrame(id,count,width,height,gap);
        if(output && capacity>=static_cast<int>(values.size())) std::copy(values.begin(),values.end(),output);
        return static_cast<int>(values.size());
    } catch(...) { return -1; }
}
API int mosaic_layout_count() noexcept { return static_cast<int>(mosaic::layouts().size()); }
API const char* mosaic_layout_field(int index,int field) noexcept {
    const auto& values=mosaic::layouts();
    if(index<0||index>=static_cast<int>(values.size()))return "";
    const auto& item=values[index];
    switch(field){case 0:return item.id;case 1:return item.category;case 2:return item.vi;case 3:return item.en;default:return "";}
}
