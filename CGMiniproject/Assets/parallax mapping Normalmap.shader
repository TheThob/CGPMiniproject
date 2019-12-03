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

					//parallax varibles
					sampler2D _Height;
					float _Parallax;
					float _bias;

					// lighting Settings
					sampler2D _NormalMap;

					float4 _LightColor0; //From UnityCG
					float4 _SpecColor;
					float _Shininess;

					struct appdata
					{
						//textures
						float2 uv : TEXCOORD0;

						// information to calc
						float4 vertex : POSITION;
						float3 normal : NORMAL;
						float4 tangent : TANGENT;
					};

					struct v2f
					{
						//textures
						float2 uv : TEXCOORD0;

						//postions
						float3 lightDir : TEXCOORD3;
						float4 vertex : SV_POSITION;


						float3 viewDir : TEXCOORD4;

						float3 tangentViewDir: TEXCOORD8;
						float3 normal : NORMAL;
					};

					float2 ParallaxOffsetCalc(half3 viewDir, float2 uv)
					{
						// inverted because a value 1 (white) time 0-1 gets smaller.
						float depth = tex2D(_Height, uv).r *-1; 
						float h = (depth* _Parallax) + _bias;
					    return (viewDir.xy * h)+ uv;
						//return ((v.xy * ((h* _Parallax) + _bias))/v.z) + uv;
					}

					float3 Ambient_Lighting(float attenuation) {
						//Ambient component
						return ((UNITY_LIGHTMODEL_AMBIENT.rgb * _Color.rgb) * attenuation);
					}

					float3 diffuse_Reflection(float attenuation, float3 normalDirection, float3 lightDirection) {
						//Diffuse component
						return (attenuation * _LightColor0.rgb * _Color.rgb * max(0.0, dot(normalDirection, lightDirection)));
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

						//textures
						o.uv = v.uv;

						//positions
						o.vertex = UnityObjectToClipPos(v.vertex);


						// Calculate lightdir
						float4 posWorld = mul(unity_ObjectToWorld, v.vertex.xyz); 
						o.lightDir = normalize(_WorldSpaceLightPos0.xyz);//DIRECTIONAL Light
						
						
						float4 objCam = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0));
						o.viewDir = v.vertex.xyz - objCam.xyz;

						float tangentSign = v.tangent.w * unity_WorldTransformParams.w;
						float3 bitangent = cross(v.normal.xyz, v.tangent.xyz) *tangentSign;
						o.tangentViewDir = float3(
							dot(o.viewDir, v.tangent.xyz),
							dot(o.viewDir, bitangent.xyz),
							dot(o.viewDir, v.normal.xyz)
							);
						o.normal = v.normal.xyz;

						return o;
					}

					fixed4 frag(v2f i) : COLOR
					{

						// parallax mapping
						float2 newT = ParallaxOffsetCalc(i.tangentViewDir, i.uv);


						float3 tex_albedo = tex2D(_MainTex, newT);


						// normal vector in tangen space
						float3 TangentNormal = tex2D(_NormalMap, newT).xyz;
						// remap to 0-1
						TangentNormal = normalize(TangentNormal * 2- 1);
																	

						float attenuation = 1.0; // no attenuation
						float3 lightDirection = normalize(i.lightDir);


						
						float3 ambientLighting = Ambient_Lighting(1);
						// I_diffuse = I_incoming *K_diffuse *max(0,dot(NORMAL,-LIGHTDIRECTING))
						float3 diffuseReflection = diffuse_Reflection(attenuation, i.normal, lightDirection);


						//Reflection = 2N*(N -> dot L)- L
						// I_specular = I_incoming* K_speccular * max(0,Reflection, viewDirection)^Shininess
						float3 specularReflection = specular_Reflection(lightDirection, attenuation, TangentNormal, i.tangentViewDir);
						

						float3 color = ((ambientLighting + diffuseReflection) * tex_albedo + specularReflection); //Texture is not applient on specularReflection
						return float4(color, 1.0);
					}
				ENDCG
			}
		}

		FallBack "Diffuse"
}