#ifndef RAYMARCHING_SDF_INCLUDED
#define RAYMARCHING_SDF_INCLUDED

float Sphere(float3 p, float3 c, float r)
{
    return length(p - c) - r;
}

float Torus(float3 p, float r1, float r2)
{
  float2 q = float2(length(p.xz) - r1, p.y);
  return length(q) - r2;
}

float Tetrahedron(float3 p, float3 o, float s)
{
    p = (p - o) / s;
    float d = max(
        max(-p.x - p.y - p.z, p.x + p.y - p.z),
        max(-p.x + p.y + p.z, p.x - p.y + p.z));
	return s * (d - 1.0) / sqrt(3.0);
}

float Union(float d1, float d2)
{
    return min(d1, d2);
}

float Difference(float d1, float d2)
{
    return max(d1, -d2);
}

float Intersection(float d1, float d2)
{
    return max(d1, d2);
}

float SmoothUnion(float d1, float d2, float k)
{
    float d = exp(-k*d1) + exp(-k*d2);
    return -log(max(d, 1e-24)) / k;
}

float3 Fold(float3 p, float3 n)
{
    return p - 2.0 * min(0.0, dot(p, n)) * n;
}

float3 FoldX(float3 p)
{
    return float3(abs(p.x), p.y, p.z);
}

float3 FoldY(float3 p)
{
    return float3(p.x, abs(p.y), p.z);
}

float3 FoldZ(float3 p)
{
    return float3(p.x, p.y, abs(p.z));
}

#endif