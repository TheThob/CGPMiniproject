// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "parallax mapping Normalmap" {
	Properties{
		[Header(Color and Main Texture)]
		_Color("Color", Color) = (1, 1, 1, 1) //The color of our object
		_MainTex("Main Texture", 2D) = "white" {}
		[Header(Parallax Mapping)]
		_Height("Height", 2D) = "white" {}
		_Parallax("Parallax", Range(0,0.2)) = 0
		_bias("Parallax_bias", Range(0,0.2)) = 0
		[Header(Lighting Settings)]
		_NormalMap("Normal Map", 2D) = "white" {}
		_Shininess("Shininess", Float) = 10 //Shininess
		_SpecColor("Specular Color", Color) = (1, 1, 1, 1) //Specular highlights color

	}
		SubShader{
			Tags { "RenderType" = "Opaque" } //We're not rendering any transparent objects
			LOD 200 //Level of detail
			Pass {
				Tags { "LightMode" = "ForwardBase" } //For the first light

				CGPROGRAM
					#pragma vertex vert
					#pragma fragment frag

					#include "UnityCG.cginc" //Provides us with light data, camera information, etc

					float4 _Color; //Use the above variables in here
					sampler2D _MainTex;
					float4 _MainTex_ST;// Needed for TRANSFORM_TEX(v.texcoord, _MainTex) //For tiling
					//parallax varibles
					sampler2D _Height;
					float _Parallax;
					float _bias;
					float4 _Height_ST; // Needed for TRANSFORM_TEX(v.texcoord, _Height) //For tiling
					// lighting Settings
					sampler2D _NormalMap;
					sampler2D _NormalMap_ST;
					float4 _LightColor0; //From UnityCG
					float4 _SpecColor;
					float _Shininess;

					struct appdata
					{
						float4 vertex : POSITION;
						float2 uv_MainTex : TEXCOORD0;
						float2 uv_HeightTex : TEXCOORD1;
						float2 uv_NormalTex : TEXCOORD2;
						float3 normal : NORMAL;
						float4 tangent : TANGENT;
					};

					struct v2f
					{
						float3 normal : NORMAL;
						float4 posWorld : TEXCOORD1;
						float2 uv_MainTex : TEXCOORD0;
						float2 uv_HeightTex : TEXCOORD3;
						float2 uv_NormalTex : TEXCOORD4;
						float4 vertex : SV_POSITION;
						float3 tangentViewDir : TEXCOORD2;
						float3x3 TBNMatrix : TEXCOORD5;
					};

					float2 ParallaxOffsetCalc(half h, half Parallax, half3 viewDir, half3 _bias)
					{
						float3 v = normalize(viewDir);
						return (v.xyz * (h* Parallax + _bias));
					}

					float3 Ambient_Lighting() {
						//Ambient component
						return (UNITY_LIGHTMODEL_AMBIENT.rgb * _Color.rgb);
					}

					float3 diffuse_Reflection(float attenuation, float3 normalDirection, float3 lightDirection) {
						//Diffuse component
						return (attenuation * _LightColor0.rgb * _Color.rgb * max(0.0, dot(normalDirection, -lightDirection)));
					}
					float3 specular_Reflection(float3 lightDirection, float attenuation, float3 normalDirection, float3 viewDirection){
						if (dot(normalDirection, lightDirection) < 0.0) //Light on the wrong side - no specular
						{
							return float3(0.0, 0.0, 0.0);
						}
						else
						{
							//Specular component
							return (attenuation * _LightColor0.rgb * _SpecColor.rgb * pow(max(0.0, dot(reflect(-lightDirection, normalDirection), viewDirection)), _Shininess));
						}
					}

					v2f vert(appdata v)
					{
						v2f o;

						o.vertex = UnityObjectToClipPos(v.vertex);
						o.uv_MainTex = TRANSFORM_TEX(v.uv_MainTex, _MainTex);
						o.uv_HeightTex = TRANSFORM_TEX(v.uv_HeightTex, _Height);
						//o.uv_NormalTex = TRANSFORM_TEX(v.uv_NormalTex, _NormalMap);
						o.uv_NormalTex = v.uv_NormalTex;

						float4 objCam = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0));
						float3 viewDir = v.vertex.xyz - objCam.xyz;

						float tangentSign = v.tangent.w * unity_WorldTransformParams.w;
						float3 bitangent = cross(v.normal.xyz, v.tangent.xyz) * tangentSign;

						o.tangentViewDir = float3(
							dot(viewDir, v.tangent.xyz),
							dot(viewDir, bitangent.xyz),
							dot(viewDir, v.normal.xyz)
							);

						o.posWorld = mul(unity_ObjectToWorld, v.vertex); //Calculate the world position for our point
						o.normal = normalize(mul(float4(v.normal, 0.0), unity_WorldToObject).xyz); //Calculate the normal

						o.TBNMatrix = float3x3(v.tangent.xyz, bitangent.xyz, v.normal.xyz);

						return o;
					}

					fixed4 frag(v2f i) : COLOR
					{						

						// parallax mapping
						float heightTex = tex2D(_Height, i.uv_HeightTex).r *-1; // inverted because a value 1 (white) time 0-1 gets smaller.

						float2 parallaxOffset = ParallaxOffsetCalc(heightTex, _Parallax, i.tangentViewDir, _bias);
						float2 newT = i.uv_MainTex + parallaxOffset;

						float3 tex_ = tex2D(_MainTex, newT);


						// normal vector in tangen space
						float3 tex_normal = tex2D(_NormalMap, newT);
						// remap to 0-1
						tex_normal = normalize(tex_normal*2-1);
						
						float3x3 TBN_T = transpose(i.TBNMatrix);
						// back to world space
						float3 worldNormal = mul(TBN_T, tex_normal);
						

						float3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);
						
						float attenuation = 1.0; // no attenuation
						float3 lightDirection = _WorldSpaceLightPos0.xyz;

						
						float3 ambientLighting = Ambient_Lighting();
						// I_diffuse = I_incoming *K_diffuse *max(0,dot(NORMAL,-LIGHTDIRECTING))
						float3 diffuseReflection = diffuse_Reflection(attenuation, worldNormal, lightDirection);
						//Reflection = 2N*(N -> dot L)- L
						// I_specular = I_incoming* K_speccular * max(0,Reflection, viewDirection)^Shininess
						float3 specularReflection = specular_Reflection(lightDirection, attenuation, worldNormal, viewDirection);
						

						float3 color = ((ambientLighting + diffuseReflection)* tex_ + specularReflection); //Texture is not applient on specularReflection
						return float4(color, 1.0);
					}
				ENDCG
			}
		}

		FallBack "Diffuse"
}