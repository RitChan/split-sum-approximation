// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/DeferredTest"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _AoRadius ("AO Radius", Range(0.01, 1)) = 1.0
        _AoFactor ("AO Factor", Range(0, 1)) = 1.0
        _Roughness ("Roughness", Range(0, 1)) = 0.5
        _BRDF ("Precomputed BRDF", 2D) = "white" {}
        _UniformTex ("Uniform Texture", 2D) = "white" {}
        _DebugU0 ("Float 0", Range(0, 1)) = 0.0
        _DebugU1 ("Float 1", Range(0, 1)) = 0.0
        _DebugF0 ("Float 2", Range(8, 13)) = 0.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            ZTest Always
            Cull Off
            ZWrite Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "Assets/Shaders/Deferred/Deferred.hlsl"
            #include "Assets/Shaders/Deferred/FastAO.hlsl"
            #include "Assets/Shaders/Common/Random.hlsl"
            #include "Assets/Shaders/Common/Constants.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            float _AoRadius;
            float _AoFactor;
            float _Roughness;
            sampler2D _BRDF;
            sampler2D _UniformTex;

            #define NUM_SAMPLES 32
            float ambientOcculsion(float2 uv)
            {
                float ao = 0.0;
                float3 posView = getViewPos(uv);
                float3 normalView = getViewNormal(uv);
                float3 noise = float3(0.0, 0.0, 0.0);
                // [unroll]
                for (uint i = 0; i < NUM_SAMPLES; i++)
                { 
                    float3 ballPoint = UniformSampleUnitBall(tex2D(_UniformTex, uv + 0.128763 * float(i) / PI).xyw);
                    float PoN = dot(ballPoint, normalView);
                    if (PoN < 0)
                        ballPoint = ballPoint - 2 * PoN * normalView;
                    float3 samplePoint = ballPoint * _AoRadius + posView;
                    float3 samplePointNDC = viewToNDC(samplePoint);
                    float2 sampleUV = samplePointNDC.xy * 0.5 + 0.5;
                    float samplePointDepthNDC = getDepthNDC(sampleUV);
                    ao += samplePointDepthNDC < samplePointNDC.z ? 1.0 : 0.0;
                }
                return ao / float(NUM_SAMPLES);
            }

            float ambientOcculsionFast(float2 uv)
            {
                float ao = 0.0;
                float3 posView = getViewPos(uv);
                float3 normalView = getViewNormal(uv);
                float3 noise = float3(0.0, 0.0, 0.0);
                [unroll]
                for (uint i = 0; i < NUM_SAMPLES; i++)
                { 
                    float4 U = tex2D(_UniformTex, uv + 0.1233 * float(i) / PI).xyzw;
                    ao += sampleFastAO(uv, _AoRadius, U.xw);
                }
                return ao / float(NUM_SAMPLES);
            }

            float3 debugAO(float2 uv, uint i)
            {
                float3 posView = getViewPos(uv);
                float4 samplePointNDC = mul(_MATRIX_P, float4(posView, 1.0));
                samplePointNDC /= samplePointNDC.w;
                float2 sampleUV = samplePointNDC.xy * 0.5 + 0.5;
                sampleUV.y = 1 - sampleUV.y;
                float samplePointDepthNDC = getDepthNDC(sampleUV);
                float d = samplePointNDC.z;
                float3 noramlized = samplePointNDC.xyz * 0.5 + 0.5;
                return float3(d, d, d);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            
            float _DebugU0;
            float _DebugU1;
            float _DebugF0;

            float frag (v2f i) : SV_Target
            {
                return ambientOcculsion(i.uv);
            }
            ENDCG
        }

        pass
        {
            ZTest Always
            Cull Off
            ZWrite Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "Assets/Shaders/Deferred/Deferred.hlsl"
            #include "Assets/Shaders/Deferred/FastAO.hlsl"
            #include "Assets/Shaders/Common/Random.hlsl"
            #include "Assets/Shaders/Common/Constants.hlsl"
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            float _AoFactor;
            float _Roughness;
            sampler2D _BRDF;
            sampler2D _UniformTex;
            sampler2D _AO_TEX;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float3 integrateMicrofacet(float roughness, float cos_v, float3 F0)
            {
                float4 T = tex2D(_BRDF, float2(cos_v, lerp(0, 1, roughness)));
                float T0 = T.x;
                float T1 = T.y;
                return F0 * T0 + T1;
            }
            
            float3 applyAoFactor(float3 col, float ao, float aoFactor)
            {
                return lerp(col, ao * col, aoFactor);
            }

            #define BLUR_SIZE 3
            float blurAO(float2 uv)
            {
                float2 deltaU = float2(ddx(uv.x), 0.0);
                float2 deltaV = float2(0.0, ddy(uv.y));
                float finalAO = 0.0;
                for (int i = -BLUR_SIZE; i <= BLUR_SIZE; i++)
                {
                    for (int j = -BLUR_SIZE; j <= BLUR_SIZE; j++)
                    {
                        finalAO += tex2D(_AO_TEX, uv + float(i) * deltaU + float(j) * deltaV).r;
                    }
                }
                return finalAO / float((2 * BLUR_SIZE + 1) * (2 * BLUR_SIZE + 1));
            }

            #define Blur_Sharpness 0.5
            #define Blur_Size 3.0
            float CrossBilateralWeight(float Sharpness, float originAO, float blurAO)
            {
                float Variance = originAO - blurAO;
                return 0.39894 * exp(-0.5 * Variance * Variance / (Sharpness * Sharpness)) / Sharpness;
            }

            float Bilateralfilter(half2 uv)
            {

                half weight = 0.0, Num_Weight = 0.0;
                float blurAO = 0.0, final_AO = 0.0;
                float originAO = tex2D(_AO_TEX, uv);
                float2 deltaU = float2(ddx(uv.x), 0.0);
                float2 deltaV = float2(0.0, ddy(uv.y));

                [unroll]
                for (int i = -Blur_Size; i <= Blur_Size; i++)
                {
                    [unroll]
                    for (int j = -Blur_Size; j <= Blur_Size; j++)
                    {
                        half2 blurUV = uv + float(i) * deltaU + float(j) * deltaV;
                        blurAO = tex2D(_AO_TEX, blurUV);
                        weight = CrossBilateralWeight(Blur_Sharpness, originAO, blurAO);
                        Num_Weight += weight;
                        final_AO += weight * blurAO;
                    }
                }
                return final_AO / Num_Weight;
            }


            float4 frag (v2f i) : SV_Target
            {
                // Split-sum approximation
                float3 n = getViewNormal(i.uv);
                float3 viewPos = getViewPos(i.uv);
                float3 v = -normalize(viewPos);
                float3 NoV = dot(n, v);
                float3 F0 = getColor(i.uv).rgb;
                float3 specularCol = integrateMicrofacet(_Roughness, NoV, F0);
                float ao = Bilateralfilter(i.uv);
                return float4(ao * specularCol, 1.0);
                return float4(ao, ao, ao, 1.0);
            }

            ENDCG
        }
    }

}
