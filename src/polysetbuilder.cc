#include "polysetbuilder.h"
#include "polyset.h"

void PolySetBuilder::append(const Vector3d &v0, const Vector3d &v1, const Vector3d &v2)
{
	this->polygons.push_back({v0, v1, v2});
}

void PolySetBuilder::append(const Vector3d &v0, const Vector3d &v1, const Vector3d &v2, const Vector3d &v3)
{
	this->polygons.push_back({v0, v1, v2, v3});
}

void PolySetBuilder::append(const Polygon &poly)
{
	this->polygons.push_back(poly);
}

void PolySetBuilder::append(const Polygons &polygons)
{
	this->polygons.insert(this->polygons.end(), polygons.begin(), polygons.end());
}

void PolySetBuilder::build(PolySet &ps)
{
	ps.polygons = std::move(this->polygons);
	ps.dirty = true;
}

