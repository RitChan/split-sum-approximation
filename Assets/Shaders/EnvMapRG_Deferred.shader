Shader "Unlit/EnvMapRG_Deferred"
{
    Properties
    {
        _Color ("Diffuse Color", Color) = (1, 1, 1, 1)
        _Roughtness ("Roughness", Range(0, 1)) = 0.5
        _Metallic ("Metallic", Range(0, 1)) = 0
        _MainTex ("Texture", 2D) = "black" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags { "LightMode"="Deferred"}
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
                float4 col : COLOR;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldNormal : NORMAL;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };

            struct fout
            {
                float4 albedo : SV_TARGET0;
                float4 specular : SV_TARGET1;
                float4 normal : SV_TARGET2;
                float4 emission : SV_TARGET3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Color;
            float _Roughtness;
            float _Metallic;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            fout frag (v2f i)
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

                fout o;
                o.albedo = float4(diffuseCol.rgb, 1.0);
                float4 clipPos = mul(UNITY_MATRIX_VP, float4(i.worldPos, 1.0)).xyzw;
                clipPos /= clipPos.w;
                o.albedo = float4(diffuseCol.rgb, 1.0);
                o.specular = float4(F0.rgb, 1 - _Roughtness);
                o.normal = float4(n * 0.5 + 0.5, 1.0);
                o.emission = diffuseCol;
                return o;
            }
            ENDHLSL
        }
    }
}
