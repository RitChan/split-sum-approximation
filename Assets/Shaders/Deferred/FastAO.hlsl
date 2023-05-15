#ifndef _FAST_AO_
#define _FAST_AO_
#include "Assets/Shaders/Deferred/Deferred.hlsl"
#include "Assets/Shaders/Common/Random.hlsl"
#include "Assets/Shaders/Common/Constants.hlsl"

float3 getTangent(float3 viewDir)
{
    float3 upVector = viewDir.y > 0.999 ? float3(1.0, 0.0, 0.0) : float3(0.0, 1.0, 0.0);
    return normalize(cross(upVector, viewDir));
}

float getSceneSampleDepth(float2 xz, float3 viewPos, float3 tangentX, float3 tangentZ)
{  
    float3 samplePos = viewPos + xz.x * tangentX + xz.y * tangentZ;
    return getDepth(samplePos);
}

float3 getNormalPlanePoint(float3 N, float3 V, float3 sample, float3 viewPos)
{
    float NoV = dot(N, V);
    float t = dot(viewPos - sample, N) / NoV;
    return sample + V * t;
}


float sampleFastAO(float2 uv, float aoViewRadius, float2 U)
{
    // Occupancy normalization factor
    float C0 = 3 / (2 * PI * pow(aoViewRadius, 3.0));
    // Calc sample point on disk
    float3 viewPos = getViewPos(uv);
    float3 V = -normalize(viewPos);
    float3 tangentX = getTangent(V);
    float3 tangentZ = cross(tangentX, V);
    float2 xz = UniformSampleDisk(U);
    float3 diskSampleVec = (xz.x * tangentX + xz.y * tangentZ) * aoViewRadius;
    float3 diskSample = viewPos + diskSampleVec;
    float3 diskSampleNDC = viewToNDC(diskSample);
    // Calc scene sample point
    float dNDC = getDepth(diskSampleNDC.xy * 0.5 + 0.5);
    float3 sceneSample = ndcToView(float3(diskSampleNDC.xy, dNDC));
    // Calc sphere sample point
    float3 sphereSample = sqrt(1 - xz.x * xz.x - xz.y * xz.y) * aoViewRadius * V + diskSampleVec + viewPos;
    // Calc normal plane sample point
    float3 N = getViewNormal(uv);
    float3 normalSample = getNormalPlanePoint(N, V, sphereSample, viewPos);
    // Collect Y coord
    float d = dot(sceneSample - viewPos, V);
    float ys = dot(sphereSample - viewPos, V);
    float yn = dot(normalSample - viewPos, V);
    float aoSample = C0 * max(ys - max(max(d, yn), -ys), 0.0);
    float adjustment = max(ys - max(yn, -ys), 0.0) / (PI * pow(aoViewRadius, 2.0));
    return aoSample * PI * pow(aoViewRadius, 2);
}

float3 debugFastAO(float2 uv, float aoViewRadius, float2 U, float scalar)
{
    // Occupancy normalization factor
    float C0 = 3 / (2 * PI * pow(aoViewRadius, 3.0));
    // Calc sample point on disk
    float3 viewPos = getViewPos(uv);
    float3 V = -normalize(viewPos);
    float3 tangentX = getTangent(V);
    float3 tangentZ = cross(tangentX, V);
    float2 xz = UniformSampleDisk(U);
    xz = float2(0, 0);
    float3 diskSampleVec = (xz.x * tangentX + xz.y * tangentZ) * aoViewRadius;
    float3 diskSample = viewPos + diskSampleVec;
    float3 diskSampleNDC = viewToNDC(diskSample);
    // Calc scene sample point
    float dNDC = getDepth(diskSampleNDC.xy * 0.5 + 0.5);
    float3 sceneSample = ndcToView(float3(diskSampleNDC.xy, dNDC));
    // Calc sphere sample point
    float3 sphereSample = sqrt(1 - xz.x * xz.x - xz.y * xz.y) * aoViewRadius * V + diskSampleVec + viewPos;
    // Collect Y coord
    float d = dot(sceneSample - viewPos, V);
    float ys = dot(sphereSample - viewPos, V);
    return viewToNDC(sceneSample);
    return viewToNDC(viewPos);
    // return sceneSample;
    // return float3(d, d, d) * scalar;
    if (ys >= d - scalar)
        return float3(1, 1, 1);
    else
        return float3(0, 0, 0);
}

#endif