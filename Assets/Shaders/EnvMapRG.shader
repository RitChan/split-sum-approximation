Shader "Unlit/EnvMapRG"
{
    Properties
    {
        _Color ("Diffuse Color", Color) = (1, 1, 1, 1)
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
            Tags { "LightMode"="ForwardBase"}
            HLSLPROGRAM
            #pragma multi_compile_fwdbase
            #pragma vertex vert
            #pragma fragment frag 
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #pragma multi_compile_fwdbase
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
                float3 worldNormal : NORMAL;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                LIGHTING_COORDS(3, 4)
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
                TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 v = normalize(UnityWorldSpaceViewDir(i.worldPos));
                float3 n = normalize(i.worldNormal);
                float3 r = normalize(reflect(v, n));

                // Diffuse
                float4 texCol = tex2D(_MainTex, i.uv);
                float4 surfaceCol = float4(0, 0, 0, 0);
                if (texCol.w == 0)
                    surfaceCol = _Color;
                else
                    surfaceCol = texCol;
                float4 F0 = lerp(0.04, surfaceCol, _Metallic);
                float4 diffuseCol = lerp(surfaceCol, float4(0, 0, 0, 0), _Metallic);

                // Calc env
                float4 specularEnv = prefilterdEnv(roughness, r);
                float4 diffuseEnv = prefilterdEnv(0.96, n);

                // Integrate BRDF
                float cos_v = saturate(dot(n, v));
                float4 specularCol = integrateMicrofacet(_Roughtness, cos_v, F0);

                // Shade
                float4 diffuseRadiance = diffuseEnv * diffuseCol;
                float4 microfacetRadiance = specularEnv * _MicrofacetIntensity * specularCol;
                float4 col = diffuseRadiance + microfacetRadiance;

                // With Shadow
                float attenuation = LIGHT_ATTENUATION(i);
                return col * attenuation;
            }
            ENDHLSL
        }

		Pass//产生阴影的通道(物体透明也产生阴影)
		{
			Tags { "LightMode" = "ShadowCaster" }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 2.0
			#pragma multi_compile_shadowcaster
			#pragma multi_compile_instancing // allow instanced shadow pass for most of the shaders
			#include "UnityCG.cginc"

			struct v2f {
				V2F_SHADOW_CASTER;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2f vert(appdata_base v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}
    }
}
