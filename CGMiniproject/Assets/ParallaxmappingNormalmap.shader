Shader "Parallax mapping with Normalmap lighting" {
	Properties{
		[Header(Color and Main Texture)]
		_Color("Color", Color) = (1, 1, 1, 1) //The color of our object
		_Color2("defluse Color", Color) = (1, 1, 1, 1) //The color of our object
		_MainTex("Main Texture", 2D) = "white" {}

		[Header(Parallax Mapping)]
		_Height("Height", 2D) = "white" {}
		_Parallax("Parallax", Range(0,0.2)) = 0
		_bias("Parallax_bias", Range(-0.1, 0.1)) = 0

		[Header(Lighting Settings)]
		_NormalMap("Normal Map", 2D) = "white" {}
		_Shininess("Shininess", Range(0.1,200)) = 10 //Shininess
		_SpecColor("Specular Color", Color) = (1, 1, 1, 1) //Specular highlights color

	}
		SubShader{
			Tags { "RenderType" = "Opaque" } //We're not rendering any transparent objects
			Pass {
				Tags { "LightMode" = "ForwardBase" } //For the first light

				CGPROGRAM
					#pragma vertex vert
					#pragma fragment frag

					#include "UnityCG.cginc" 

					float4 _Color;
					float4 _Color2; 
					sampler2D _MainTex;

					//parallax varibles
					sampler2D _Height;
					float _Parallax;
					float _bias;

					// lighting Settings
					sampler2D _NormalMap;

					float4 _LightColor0; //From UnityCG

					// specular lighting parameters
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
						//postions
						float4 vertex : SV_POSITION;
						//textures
						float2 uv : TEXCOORD0;
						//light direction
						float3 lightDir : TEXCOORD1;
						// view directions
						float3 viewDir : TEXCOORD2;
						float3 tangentViewDir: TEXCOORD3;
						// TBN matrix
						float3x3 TBN: TEXCOORD4;
					};

					float2 ParallaxOffsetCalc(half3 viewDir, float2 uv)
					{
						float depth = tex2D(_Height, uv).r;
						float h = (depth* _Parallax) + _bias;
						return ((viewDir.xy * h) + uv);
						//return ((v.xy * ((h* _Parallax) + _bias))/v.z) + uv;
					}

					float3 Ambient_Lighting(float attenuation) {
						//Ambient component
						return ((UNITY_LIGHTMODEL_AMBIENT.rgb * _Color.rgb) * attenuation);
					}

					float3 diffuse_Reflection(float attenuation, float3 normalDirection, float3 lightDirection) {
						//Diffuse component
						return attenuation * _Color2 * max(0.0, dot(normalDirection, lightDirection));

					}
					float3 specular_Reflection(float3 lightDirection, float attenuation, float3 normalDirection, float3 viewDirection) {
						if (dot(normalDirection, lightDirection) < 0.0) //Light on the wrong side - no specular
						{
							return float3(0.0, 0.0, 0.0);
						}
						else
						{
							//Specular component
							float3 Reflection = reflect(-lightDirection, normalDirection);
							float3 specmax = max(0.0, dot(Reflection, viewDirection));
							return (attenuation * _LightColor0.rgb * _SpecColor.rgb * pow(specmax, _Shininess));
						}
					}

					v2f vert(appdata v)
					{
						v2f o;
						//positions
						o.vertex = UnityObjectToClipPos(v.vertex);
						//textures
						o.uv = v.uv;
						// Calculate lightdir in object space
						o.lightDir = normalize(mul(unity_WorldToObject, _WorldSpaceLightPos0.xyz));//DIRECTIONAL Light
						//object to tangent space matrix
						float3 N = v.normal.xyz;
						float3 T = v.tangent.xyz;
						float tangentSign = v.tangent.w * unity_WorldTransformParams.w;
						float3 B = cross(N, T) * tangentSign; 
						o.TBN = float3x3(normalize(T), normalize(B), normalize(N));
						// viewdirection calc
						float4 objCam = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0));
						o.viewDir = normalize(objCam.xyz - v.vertex.xyz);
						//convert viewdir from object ->  tangent space
						o.tangentViewDir = normalize(mul(o.TBN, o.viewDir));
						return o;
					}

					fixed4 frag(v2f i) : COLOR
					{
						//tangent -> object
						float3x3 TBN_T = transpose(i.TBN);
						// parallax mapping
						float2 newT = ParallaxOffsetCalc(normalize(i.tangentViewDir), i.uv);
						/* Sampling the textures with offset corrdinate */
						//main texture
						float3 tex_albedo = tex2D(_MainTex, newT);
						//normal Texture
						// normal vector from texture
						float3 TangentNormal = float3(0,0,0);
						TangentNormal.xy = tex2D(_NormalMap, newT).wy * 2 - 1;// remap to -1-1
						TangentNormal.z = sqrt(1 - saturate(dot(TangentNormal.xy,TangentNormal.xy)));


						/*NORMALS TO CALC LIGHT*/

						// TBN_T should be tangent space -> object space
						float3 objectNormalSpeccular = normalize(mul(TBN_T, TangentNormal));

						/* lighting */
						float3 ambientLighting = Ambient_Lighting(1);


						// I_diffuse = I_incoming *K_diffuse *max(0,dot(NORMAL,-LIGHTDIRECTING))
						float3 diffuseReflection = diffuse_Reflection(1, objectNormalSpeccular, normalize(i.lightDir));


						//Reflection = 2N*(N -> dot L)- L
						// I_specular = I_incoming* K_speccular * max(0,Reflection, viewDirection)^Shininess
						float3 specularReflection = specular_Reflection(normalize(i.lightDir), 1, objectNormalSpeccular, normalize(i.viewDir));



						float3 color = ((ambientLighting + diffuseReflection + specularReflection) * tex_albedo);
						return float4(color, 1.0);
					}
				ENDCG
			}
		}

			FallBack "Diffuse"
}