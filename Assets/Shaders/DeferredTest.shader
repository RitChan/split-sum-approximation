// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/DeferredTest"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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

            sampler2D _MainTex;
            sampler2D _CameraGBufferTexture0;
            sampler2D _CameraGBufferTexture1; 
            sampler2D _CameraGBufferTexture2; 
            sampler2D _CameraGBufferTexture3; 
            sampler2D _CameraGBufferTexture4;
            sampler2D _CameraDepthTexture;
            float4x4 _MATRIX_P_INV;
            float4x4 _MATRIX_P;
            float4x4 _MATRIX_V;

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
                return getDepth(uv) * 2 - 1;
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
                float4 ndcPos = float4(uv * 2 - 1, getDepthNDC(uv), 1.0);
                float4 viewPosH = mul(_MATRIX_P_INV, ndcPos);
                return viewPosH.xyz / viewPosH.w;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // sample the texture
                float4 col;        
                col = float4(getColor(i.uv).rgb, 1.0);
                return col;
            }
            ENDCG
        }
    }
}
