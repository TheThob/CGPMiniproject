// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Parallax_mapping_light_worldSpace" {
	Properties{
		_Color("Color", Color) = (1, 1, 1, 1) //The color of our object
		_Shininess("Shininess", Float) = 10 //Shininess
		_SpecColor("Specular Color", Color) = (1, 1, 1, 1) //Specular highlights color
		_MainTex("Texture", 2D) = "white" {}
		_Height("Height", 2D) = "white" {}
		_Parallax("Parallax", Range(0,0.2)) = 0
		_bias("Parallax_bias", Range(0,0.2)) = 0
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

					uniform float4 _LightColor0; //From UnityCG

					uniform float4 _Color; //Use the above variables in here
					uniform float4 _SpecColor;
					uniform float _Shininess;
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
						float3 normal : NORMAL;
						float4 posWorld : TEXCOORD1;
						float2 uv_MainTex : TEXCOORD0;
						float2 uv_HeightTex : TEXCOORD3;
						float4 vertex : SV_POSITION;
						float3 tangentViewDir : TEXCOORD2;
					};
					float2 ParallaxOffsetCalc(half h, half Parallax, half3 viewDir, half3 _bias)
					{
						float3 v = normalize(viewDir);
						return (v.xy * ((h)* Parallax + _bias));
					}

					float3 Ambient_Lighting() {
						//Ambient component
						return (UNITY_LIGHTMODEL_AMBIENT.rgb * _Color.rgb);
					}

					float3 diffuse_Reflection(float attenuation, float3 normalDirection, float3 lightDirection) {
						//Diffuse component
						return (attenuation * _LightColor0.rgb * _Color.rgb * max(0.0, dot(normalDirection, lightDirection)));
					}
					float3 specular_Reflection(float3 lightDirection, float attenuation, float3 normalDirection, float3 viewDirection) {
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


						return o;
					}

					fixed4 frag(v2f i) : COLOR
					{
						float3 normalDirection = normalize(i.normal);
						float3 viewDirection = normalize(_WorldSpaceCameraPos - i.posWorld.xyz);

						float3 vert2LightSource = _WorldSpaceLightPos0.xyz - i.posWorld.xyz;
						float oneOverDistance = 1.0 / length(vert2LightSource);
						float attenuation = lerp(1.0, oneOverDistance, _WorldSpaceLightPos0.w); //Optimization for spot lights. This isn't needed if you're just getting started.
						float3 lightDirection = _WorldSpaceLightPos0.xyz - i.posWorld.xyz * _WorldSpaceLightPos0.w;



						float3 ambientLighting = Ambient_Lighting();


						float3 diffuseReflection = diffuse_Reflection(attenuation, normalDirection, lightDirection);

						float3 specularReflection = specular_Reflection(lightDirection, attenuation, normalDirection, viewDirection);



						// parallax mapping
						float heightTex = tex2D(_Height, i.uv_HeightTex).r *-1;

						float2 parallaxOffset = ParallaxOffsetCalc(heightTex, _Parallax, i.tangentViewDir, _bias);

						float3 tex_ = tex2D(_MainTex, i.uv_MainTex + parallaxOffset);


						float3 color = (ambientLighting + diffuseReflection)* tex_ + specularReflection; //Texture is not applient on specularReflection
						return float4(color, 1.0);
					}
				ENDCG
			}

			/*Pass {
			  Tags { "LightMode" = "ForwardAdd" } //For every additional light
				Blend One One //Additive blending

				CGPROGRAM
			  #pragma vertex vert
			  #pragma fragment frag

			  #include "UnityCG.cginc" //Provides us with light data, camera information, etc

			  uniform float4 _LightColor0; //From UnityCG

			  sampler2D _Tex; //Used for texture
			  float4 _Tex_ST; //For tiling

			  uniform float4 _Color; //Use the above variables in here
			  uniform float4 _SpecColor;
			  uniform float _Shininess;

			  struct appdata
			  {
				  float4 vertex : POSITION;
				  float3 normal : NORMAL;
				  float2 uv : TEXCOORD0;
			  };

			  struct v2f
			  {
				  float4 pos : POSITION;
				  float3 normal : NORMAL;
				  float2 uv : TEXCOORD0;
				  float4 posWorld : TEXCOORD1;
			  };

			  v2f vert(appdata v)
			  {
				  v2f o;

				  o.posWorld = mul(unity_ObjectToWorld, v.vertex); //Calculate the world position for our point
				  o.normal = normalize(mul(float4(v.normal, 0.0), unity_WorldToObject).xyz); //Calculate the normal
				  o.pos = UnityObjectToClipPos(v.vertex); //And the position
				  o.uv = TRANSFORM_TEX(v.uv, _Tex);

				  return o;
			  }

			  fixed4 frag(v2f i) : COLOR
			  {
				  float3 normalDirection = normalize(i.normal);
				  float3 viewDirection = normalize(_WorldSpaceCameraPos - i.posWorld.xyz);

				  float3 vert2LightSource = _WorldSpaceLightPos0.xyz - i.posWorld.xyz;
				  float oneOverDistance = 1.0 / length(vert2LightSource);
				  float attenuation = lerp(1.0, oneOverDistance, _WorldSpaceLightPos0.w); //Optimization for spot lights. This isn't needed if you're just getting started.
				  float3 lightDirection = _WorldSpaceLightPos0.xyz - i.posWorld.xyz * _WorldSpaceLightPos0.w;

				  float3 diffuseReflection = attenuation * _LightColor0.rgb * _Color.rgb * max(0.0, dot(normalDirection, lightDirection)); //Diffuse component
				  float3 specularReflection;
				  if (dot(i.normal, lightDirection) < 0.0) //Light on the wrong side - no specular
				  {
					specularReflection = float3(0.0, 0.0, 0.0);
				  }
				  else
				  {
					  //Specular component
					  specularReflection = attenuation * _LightColor0.rgb * _SpecColor.rgb * pow(max(0.0, dot(reflect(-lightDirection, normalDirection), viewDirection)), _Shininess);
				  }

				  float3 color = (diffuseReflection)* tex2D(_Tex, i.uv) + specularReflection; //No ambient component this time
				  return float4(color, 1.0);
			  }
		  ENDCG
			}*/

		}
			FallBack "Diffuse"
}