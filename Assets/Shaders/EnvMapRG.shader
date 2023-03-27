Shader "Unlit/EnvMapRG"
{
    Properties
    {
        _DiffuseCol ("Diffuse Color", Color) = (1, 1, 1, 1)
        _MicrofacetIntensity ("Specular", Range(0, 1)) = 0.5
        _Roughtness ("Roughness", Range(0, 1)) = 0.5
        _Metallic ("Metallic", Range(0, 1)) = 0
        _EnvX ("Rotate Env X", Range(0, 1)) = 0
        _EnvY ("Rotate Env Y", Range(0, 1)) = 0
        _MainTex ("Texture", 2D) = "white" {}
        _ENV ("Environment", 2D) = "white" {}
        _BRDF ("BRDF Tex", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #define PI 3.1415927

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : NORMAL;
                float3 worldPos : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            Texture2D _ENV;
            SamplerState sampler_ENV;
            sampler2D _BRDF;
            float4 _DiffuseCol;
            float _Roughtness;
            float _MicrofacetIntensity;
            float _Metallic;
            float _EnvX;
            float _EnvY;

            float adjustRoughness(float roughness)
            {
                return roughness;
            }

            float4 prefilterdEnv(float roughness, float3 r) 
            {
                float theta, phi;
                theta = acos(r.y);
                phi = atan2(r.z, r.x);
                if (phi < 0)
                    phi += 2 * PI;
                theta += PI * _EnvX;
                phi += 2 * PI * _EnvY;
                float sin_theta = sin(theta);
                uint envW, envH, envLevels;
                _ENV.GetDimensions(0, envW, envH, envLevels);
                float mipLevel = envLevels * adjustRoughness(roughness);
                int mipLow = floor(mipLevel);
                int mipHigh = ceil(mipLevel);
                float2 uv = float2(phi / (2 * PI), theta / PI);
                float k = frac(mipLevel);
                float4 envCol0, envCol1;
                envCol0 = _ENV.SampleLevel(sampler_ENV, uv, mipLow);
                envCol1 = _ENV.SampleLevel(sampler_ENV, uv, mipHigh);
                // Trilinear
                float4 envCol = lerp(envCol0, envCol1, k);
                return envCol;
            }

            float4 integrateMicrofacet(float roughness, float cos_v, float4 R0)
            {
                float4 T = tex2D(_BRDF, float2(cos_v, lerp(0, 1, roughness)));
                float T0 = T.x;
                float T1 = T.y;
                return R0 * T0 + T1;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 v = normalize(UnityWorldSpaceViewDir(i.worldPos));
                float3 n = normalize(i.worldNormal);
                float3 r = normalize(reflect(v, n));

                // Diffuse
                // metallic: https://zhuanlan.zhihu.com/p/375746359
                float4 diffuseCol = _DiffuseCol * tex2D(_MainTex, i.uv);

                // Calc env
                float4 specularEnv = prefilterdEnv(_Roughtness, r);
                float4 diffuseEnv = prefilterdEnv(0.96, n);

                // Integrate BRDF
                float cos_v = saturate(dot(n, v));
                float4 specularCol = integrateMicrofacet(_Roughtness, cos_v, float4(1, 1, 1, 1));

                // Shade
                float4 diffuseRadiance = diffuseEnv * diffuseCol;
                float4 microfacetRadiance = specularEnv * _MicrofacetIntensity * specularCol;

                // Apply metallic
                float metallic = lerp(0.04, 0.96, _Metallic);

                float4 col = lerp(diffuseRadiance, microfacetRadiance, metallic);
                return col;
            }
            ENDHLSL
        }
    }
}
