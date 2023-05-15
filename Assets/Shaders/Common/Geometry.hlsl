#ifndef _GEOMETRY_
#define _GEOMETRY_
float3 polarToUnitVec(float phi, float theta, float3 N)
{
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);
    float3 H = float3(cos(phi) * sinTheta, cosTheta, sin(phi) * sinTheta);
    float3 right = N.x < 0.999 ? float3(1, 0, 0) : float3(0, 1, 0);
    float3 tangentZ = normalize(cross(right, N));
    float3 tangentX = normalize(cross(N, tangentZ));
    return H.x * tangentX + H.y * N + H.z * tangentZ;
}
#endif