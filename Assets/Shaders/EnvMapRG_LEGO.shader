Shader "Unlit/EnvMapRG_LEGO"
{
    Properties
    {
        _Color ("Surface Color", Color) = (1, 1, 1, 1)
        _MicrofacetIntensity ("Specular", Range(0, 1)) = 0.5
        _Roughtness ("Roughness", Range(0, 1)) = 0.5
        _Metallic ("Metallic", Range(0, 1)) = 0
        _EnvX ("Rotate Env X", Range(0, 1)) = 0
        _EnvY ("Rotate Env Y", Range(0, 1)) = 0
        _MainTex ("Texture", 2D) = "black" {}
        _ENV ("Environment", 2D) = "white" {}
        _BRDF ("BRDF Tex", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            HLSLPROGRAM
            #pragma multi_compile_fwdbase
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #define PI 3.1415927

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 col : COLOR;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : NORMAL;
                float3 worldPos : TEXCOORD2;
                float4 col : COLOR;
                SHADOW_COORDS(1)
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            Texture2D _ENV;
            SamplerState sampler_ENV;
            sampler2D _BRDF;
            float4 _Color;
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
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.col = v.col;
                TRANSFER_SHADOW(o);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 v = normalize(UnityWorldSpaceViewDir(i.worldPos));
                float3 n = normalize(i.worldNormal);
                float3 r = normalize(reflect(v, n));

                // Copy params
                float roughness = _Roughtness;
                float metallic = _Metallic;
                float specular_intensity = _MicrofacetIntensity;

                // Surface
                float4 texCol = tex2D(_MainTex, i.uv);
                float4 surfaceCol = texCol.w == 0 ? _Color : texCol;

                // Calc env
                float4 specularEnv = prefilterdEnv(roughness, r);
                float4 diffuseEnv = prefilterdEnv(0.96, n);

                // Integrate BRDF
                float cos_v = saturate(dot(n, v));
                float4 F0 = lerp(float4(0, 0, 0, 1), surfaceCol, metallic);
                float4 specularCol = integrateMicrofacet(roughness, cos_v, F0);

                // Shade
                float4 diffuseRadiance = diffuseEnv * lerp(surfaceCol, float4(0, 0, 0, 1), metallic);
                float4 microfacetRadiance = specularEnv * specular_intensity * specularCol;

                float4 col = diffuseRadiance + microfacetRadiance;
                return col * saturate(SHADOW_ATTENUATION(i) + 0.3);
            }
            ENDHLSL
        }

        Pass
        {
            Tags {"LightMode"="ShadowCaster"}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0
            #pragma multi_compile_shadowcaster
            #pragma multi_compile_instansing
            #include "UnityCG.cginc"

            struct v2f 
            {
                V2F_SHADOW_CASTER;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vert(appdata_base v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);
                return o;
            }

            float4 frag(v2f i) : SV_TARGET
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDHLSL
        }
    }
}
