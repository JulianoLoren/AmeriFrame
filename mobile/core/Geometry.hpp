#pragma once
#include <string>
#include <vector>

namespace mosaic {
struct Point { double x, y; };
using Polygon = std::vector<Point>;
using Cells = std::vector<Polygon>;
struct Box { double x, y, w, h; };
struct Frame { Cells cells; double gap; };
struct Layout { const char *id, *category, *vi, *en; };
const std::vector<Layout>& layouts();
double area(const Polygon& p);
Box bounds(const Polygon& p);
Cells polygons(const std::string& id, int count, double ratio);
Frame frame(const std::string& id, int count, double width, double height, double gap);
// Stable flat bridge format: effective gap, then [vertex count, x, y, ...] for each cell.
std::vector<double> packedFrame(const std::string& id, int count, double width, double height, double gap);
}
