Shader "Unlit/EnvLighting"
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

            float RadicalInverse( uint bits ){
                //reverse bit
                //高低16位换位置
                bits = (bits << 16u) | (bits >> 16u); 
                //A是5的按位取反
                bits = ((bits & 0x55555555) << 1u) | ((bits & 0xAAAAAAAA) >> 1u);
                //C是3的按位取反
                bits = ((bits & 0x33333333) << 2u) | ((bits & 0xCCCCCCCC) >> 2u);
                bits = ((bits & 0x0F0F0F0F) << 4u) | ((bits & 0xF0F0F0F0) >> 4u);
                bits = ((bits & 0x00FF00FF) << 8u) | ((bits & 0xFF00FF00) >> 8u);
                return  float(bits) * 2.3283064365386963e-10;
            }

            float2 Hammersley(uint i, uint N)
            {
                return float2(float(i) / float(N), RadicalInverse(i));
            }

            float2 unitToEnvSphere(float3 u)
            {
                float phi = atan2(u.z, u.x);
                if (phi < 0)
                {
                    phi += 2 * PI;
                }
                float theta = acos(u.y);
                return float2(phi, theta);
            }

            float GGX(float roughness, float NoH)
            {
                float alpha = roughness * roughness;
                float A = alpha * alpha;
                float B = PI * pow(pow(NoH, 2) * (A - 1) + 1, 2);
                return A / B;
            }

            float G1(float k, float NoV)
            {
                return NoV / (NoV * (1 - k) + k);
            }

            float smithG(float roughness, float NoL, float NoV)
            {
                float k = roughness * roughness / 2; // pow(roughness + 1, 2) / 8;
                return G1(k, NoL) * G1(k, NoV);
            }

            float fresnel(float4 F0, float VoH)
            {
                return F0 + (1 - F0) * pow(2, (-5.55473 * VoH - 6.98316) * VoH);
            }

            float2 sampleGgxHalfwaySphere(float roughness, float2 Xi)
            {
                float2 uv = Xi;
                float a = roughness * roughness;
                float phi = 2 * PI * uv.x;
                float theta = acos(sqrt((1 - uv.y) / (uv.y * (a * a - 1) + 1)));
                return float2(phi, theta);
            }

            float3 sampleGgxHalfway(float roughness, float3 N, float2 Xi) 
            {
                float2 phiTheta = sampleGgxHalfwaySphere(roughness, Xi);
                float phi = phiTheta.x;
                float theta = phiTheta.y;
                float cosTheta = cos(theta);
                float sinTheta = sin(theta);
                float3 H = float3(sinTheta * cos(phi), sinTheta * sin(phi), cosTheta);
                float3 up;
                if (abs(N.z) < 0.999)
                {
                    up = float3(0, 0, 1);
                }
                else
                {
                    up = float3(1, 0, 0);
                }
                float3 tangentX = normalize(cross(up, N));
                float3 tangentY = normalize(cross(N, tangentX));
                return H.y * tangentX + H.x * tangentY + H.z * N;
            }

            float4 integrateEnvLighting(float4 F0, float roughness, float3 N, float3 V, float2 seed)
            {
                float4 Lo = float4(0, 0, 0, 0);
                const uint numSamples = 32;
                for (uint i = 0; i < numSamples; i++)
                {
                    float2 Xi = Hammersley(i, numSamples);
                    float3 H = sampleGgxHalfway(roughness, N, Xi);
                    float3 L = 2 * dot(V, H) * H - V;
                    float NoV = saturate(dot(N, V));
                    float NoL = saturate(dot(N, L));
                    float NoH = saturate(dot(N, H));
                    float VoH = saturate(dot(V, H));
                    if (NoL > 0)
                    {
                        float2 L_Sphere = unitToEnvSphere(L);
                        float2 envUV = float2(L_Sphere.x / (2 * PI), (PI - L_Sphere.y) / PI);
                        float4 env = saturate(_ENV.SampleLevel(sampler_ENV, envUV, 0));
                        float G = smithG(roughness, NoL, NoV);
                        float Fc = pow(1 - VoH, 5);
                        float4 F = (1 - Fc) * F0 + Fc;
                        Lo +=  env * F * G * VoH / (NoH * NoV);
                        // Lo += float4(abs(L.xz), 1, 1);
                    }
                }
                return Lo / numSamples;
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
                // Diffuse
                float4 diffuseCol = _DiffuseCol * tex2D(_MainTex, i.uv);
                float2 seed2 = float2(i.vertex.x, i.worldPos.x);
                float4 col = integrateEnvLighting(diffuseCol, _Roughtness, n, v, seed2);

                return col;
            }
            ENDHLSL
        }
    }
}
