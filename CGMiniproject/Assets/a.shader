Shader "Unlit/a"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_Height("Height", 2D) = "white" {}
		_Parallax("Parallax", Range(0,0.1)) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"


			sampler2D _MainTex;
			sampler2D _Height;
			float _Parallax;
			float4 _MainTex_ST;
			float4 _Height_ST;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv_MainTex : TEXCOORD0;
				float2 uv_HeightTex : TEXCOORD1;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv_MainTex : TEXCOORD0;
				float2 uv_HeightTex : TEXCOORD1;
                float4 vertex : SV_POSITION;
				float3 tangentViewDir : TEXCOORD2;
            };

			float2 ParallaxOffsetCalc(half h, half height, half3 viewDir)
			{
				h = h * height - height / 2.0;
				float3 v = normalize(viewDir);
				v.z += 0.42;
				return h * (v.xy / v.z);
			}


            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                //o.uv_MainTex = TRANSFORM_TEX(v.uv_MainTex, _MainTex);
				o.uv_HeightTex = TRANSFORM_TEX(v.uv_HeightTex, _Height);

				//Transform the view direction from world space to tangent space			
				float3 worldVertexPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				float3 worldViewDir = worldVertexPos - _WorldSpaceCameraPos;

				float3 worldNormal = UnityObjectToWorldNormal(v.normal);
				float3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
				float3 worldBitangent = cross(worldNormal, worldTangent) * v.tangent.w * unity_WorldTransformParams.w;

				//Use dot products instead of building the matrix
				o.tangentViewDir = float3(dot(worldViewDir, worldTangent),dot(worldViewDir, worldNormal),dot(worldViewDir, worldBitangent));
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
				float heightTex = tex2D(_Height, i.uv_HeightTex).r;
				float2 parallaxOffset = ParallaxOffsetCalc(heightTex, _Parallax, i.tangentViewDir);
				float4 col = tex2D(_MainTex, i.uv_MainTex + parallaxOffset);
                return col;
            }
            ENDCG
        }
    }
	FallBack "Diffuse"
}
