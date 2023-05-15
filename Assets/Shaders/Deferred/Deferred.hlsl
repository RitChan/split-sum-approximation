#ifndef _DEFERRED_
#define _DEFERRED_
sampler2D _CameraGBufferTexture0;
sampler2D _CameraGBufferTexture1; 
sampler2D _CameraGBufferTexture2; 
sampler2D _CameraGBufferTexture3; 
sampler2D _CameraGBufferTexture4;
sampler2D _CameraDepthTexture;
float4x4 _MATRIX_P_INV;
float4x4 _MATRIX_P;
float4x4 _MATRIX_V;
float4 _DEPTH_PARAM;

float4 getColor(float2 uv)
{
    return tex2D(_CameraGBufferTexture0, uv);
}

float getDepth(float2 uv)
{
    return tex2D(_CameraDepthTexture, uv).r;
}

float getDepthNDC(float2 uv)
{
    return getDepth(uv);
}

float3 getWorldNormal(float2 uv)
{
    return tex2D(_CameraGBufferTexture2, uv).xyz * 2 - 1;
}

float3 getViewNormal(float2 uv)
{
    float3 worldN = getWorldNormal(uv);
    return mul(_MATRIX_V, float4(worldN, 0.0)).xyz;
}

float3 getViewPos(float2 uv)
{
    float depth = getDepthNDC(uv);
    float4 ndcPos = float4(uv * 2 - 1, depth, 1.0);
    float4 viewPosH = mul(_MATRIX_P_INV, ndcPos);
    return viewPosH.xyz / viewPosH.w;
}

float3 viewToNDC(float3 viewPos)
{
    float4 clipPos = mul(_MATRIX_P, float4(viewPos, 1.0));
    return clipPos.xyz / clipPos.w;
}

float3 ndcToView(float3 ndcPos)
{
    float4 viewPosH = mul(_MATRIX_P_INV, float4(ndcPos, 1.0));
    return viewPosH.xyz / viewPosH.w;
}
#endif
