#pragma once

#include "GeometryUtils.h"

class PolySetBuilder
{
public:
	PolySetBuilder() {}

	void append(const Vector3d &v0, const Vector3d &v1, const Vector3d &v2);
	void append(const Vector3d &v0, const Vector3d &v1, const Vector3d &v2, const Vector3d &v3);
	void append(const Polygon &poly);
	void append(const Polygons &polygons);

	void build(class PolySet &ps);
private:
	Polygons polygons;
};
