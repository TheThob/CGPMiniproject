Shader "parallax_mapping"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_Height("Height", 2D) = "white" {}
		_Parallax("Parallax", Range(0,0.2)) = 0
		_bias("Parallax_bias", Range(0,0.2)) = 0
	}
		SubShader
		{
			Tags { "RenderType" = "Opaque" }
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
				float _bias;
				float4 _MainTex_ST;// Needed for TRANSFORM_TEX(v.texcoord, _MainTex)
				float4 _Height_ST; // Needed for TRANSFORM_TEX(v.texcoord, _Height)

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


				float2 ParallaxOffsetCalc(half h, half Parallax, half3 viewDir, half3 _bias)
				{
					float3 v = normalize(viewDir);
					return (v.xy * ((h) * Parallax + _bias));
				}
				v2f vert(appdata v) 
				{
					v2f o;
					o.vertex = UnityObjectToClipPos(v.vertex);
					o.uv_MainTex = TRANSFORM_TEX(v.uv_MainTex, _MainTex);
					o.uv_HeightTex = TRANSFORM_TEX(v.uv_HeightTex, _Height);

					float4 objCam = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0));
					float3 viewDir = v.vertex.xyz - objCam.xyz;

					float tangentSign = v.tangent.w * unity_WorldTransformParams.w;
					float3 bitangent = cross(v.normal.xyz, v.tangent.xyz) * tangentSign;

					o.tangentViewDir = float3(
						dot(viewDir, v.tangent.xyz),
						dot(viewDir, bitangent.xyz),
						dot(viewDir, v.normal.xyz)
						);
					return o;
				}

				float3 frag(v2f i) : SV_Target
				{
					float heightTex = tex2D(_Height, i.uv_HeightTex).r *-1;

					/*float h = ((heightTex * _Parallax - _Parallax / 2.0)*-1)+_bias;
					float3 v = normalize(i.tangentViewDir);
					float2	parallaxOffset = (h * v.xy);*/
					float2 parallaxOffset = ParallaxOffsetCalc(heightTex, _Parallax, i.tangentViewDir, _bias);

					float3 col = tex2D(_MainTex, i.uv_MainTex + parallaxOffset);
					return col;
				}
				ENDCG
			}
		}
			FallBack "Diffuse"
}
