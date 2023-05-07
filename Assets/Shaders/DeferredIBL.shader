Shader "Deferred/DeferredIBL"
{
    Properties
    {
        _Color ("Diffuse Color", Color) = (1, 1, 1, 1)
        _MainTex ("Texture", 2D) = "white" {}
        _Roughtness ("Roughness", Range(0, 1)) = 0.5
        _Metallic ("Metallic", Range(0, 1)) = 0
        _BRDF ("BRDF Tex", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma exclude_renderers nomrt
            #pragma target 3.0
            #include "UnityCG.cginc"
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float3 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float4 color : TEXCOORD3;
                float4 vertex : SV_POSITION;
            };

            struct fout {
                float4 color : SV_TARGET0;
                float3 worldPos : SV_TARGET1;
                float3 worldNormal : SV_TARGET2;
                float depth : SV_TARGET3;
            };

            sampler2D _MainTex;
            float4 _Color;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.uv = v.uv;
                o.color = _Color;
                return o;
            }

            fout frag(v2f i) 
            {
                fout o;
                o.color = i.color;
                o.worldPos = i.worldPos;
                o.worldNormal = i.worldNormal;
                o.depth = EncodeFloatRGBA(i.vertex.z / i.vertex.w);
                return o;
            }
            ENDHLSL
        }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma exclude_renderers nomrt
            #pragma target 3.0
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _G_WorldPos;
            sampler2D _G_WorldNormal;
            sampler2D _G_Depth;
            sampler2D _G_Color;
            float4x4 _ViewMatrix;
            float4x4 _ProjectMatrix;
            float3 _CameraWorldPos;
            sampler2D _BRDF;
            float4 _Color;
            float _Metallic;
            float _Roughtness;

            float4 integrateMicrofacet(float roughness, float cos_v, float4 F0)
            {
                float4 T = tex2D(_BRDF, float2(cos_v, lerp(0, 1, roughness)));
                float T0 = T.x;
                float T1 = T.y;
                return F0 * T0 + T1;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = (o.vertex.xy / (sign(o.vertex.w) * max(abs(o.vertex.w), 0.0001))) * 0.5 + 0.5;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 worldPos = tex2D(_G_WorldPos, i.uv).xyz;
                float3 N = tex2D(_G_WorldNormal, i.uv);
                float3 V = normalize(_CameraWorldPos - worldPos);
                float3 NoV = dot(N, V);
                float4 F0 = tex2D(_G_Color, i.uv);
                return integrateMicrofacet(_Roughtness, NoV, F0);
            }
            ENDHLSL
        }
    }
}
