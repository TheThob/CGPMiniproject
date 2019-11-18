Shader "parallaxOclusion"
{
	Properties
	{
		//2 textures 
		_Texture("Main texture", 2D) = "white" {}
		_HeightMap("Height map", 2D) = "white" {}

		// 2 parameters
		_Parallax("Height scale", Range(0.0, 0.125)) = 0.08
		_ParallaxSamples("Parallax samples", Range(10, 100)) = 100
	}
		SubShader
		{
		Pass
			{
			Tags{ "LightMode" = "ForwardBase" }
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag

				sampler2D _Texture; //Main texture
				sampler2D _HeightMap; //Height map
				float _Parallax; //Height scale
				float _ParallaxSamples; //Parallax samples

				// data the vert function need
				struct Appdata
				{
					float4 vertex: POSITION;
					float3 normal: NORMAL;
					float2 texcoord: TEXCOORD0;
					float4 tangent : TANGENT;
				};

				struct v2f
				{
				float4 pos: SV_POSITION;
				float2 tex: TEXCOORD0;
				float4 posWorld: TEXCOORD1;
				float3 normal : TEXCOORD2;
				//Tangent Space
				float3 tSpace0 : TEXCOORD3;
				float3 tSpace1 : TEXCOORD4;
				float3 tSpace2 : TEXCOORD5;

				};

				v2f vert(Appdata v)
				{
				v2f vOut;
				//World position
				vOut.posWorld = mul(unity_ObjectToWorld, v.vertex);

				//Compute tangent space basis vectors in world space
				fixed3 worldNormal = mul(v.normal.xyz, (float3x3)unity_WorldToObject);
				fixed3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld, v.tangent.xyz));
				fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w;

				//Convert tangent space basis vectors to tangent space
				vOut.tSpace0 = float3(worldTangent.x, worldBinormal.x, worldNormal.x);
				vOut.tSpace1 = float3(worldTangent.y, worldBinormal.y, worldNormal.y);
				vOut.tSpace2 = float3(worldTangent.z, worldBinormal.z, worldNormal.z);

				//Converts to clip space
				vOut.pos = UnityObjectToClipPos(v.vertex);


				//Outputting texture and normal
				vOut.tex = v.texcoord;
				vOut.normal = v.normal;

				return vOut;
				}

				float4 frag(v2f i) : SV_TARGET
				{
					//Normalizing view direction in world space
					fixed3 worldViewDir = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);
				//Calculating the initial parallax direction vector
				fixed3 viewDir = i.tSpace0.xyz * worldViewDir.x + i.tSpace1.xyz * worldViewDir.y +
				i.tSpace2.xyz * worldViewDir.z;
				//Initial parallax direction gets normalized
				float2 vParallaxDirection = normalize(viewDir.xy);
				//Length of initial parallax direction vector
				float fLength = length(viewDir);
				//Calculating length
				float fParallaxLength = sqrt(fLength * fLength - viewDir.z * viewDir.z) / viewDir.z;
				//Calculating the parallax displacement vector
				float2 vParallaxOffsetTS = (fParallaxLength * _Parallax) * vParallaxDirection;
				//Min and max samples
				float nMinSamples = 6;
				float nMaxSamples = min(_ParallaxSamples, 100);
				//Calculate number of samples and step size
				int nNumSamples = (int)(lerp(nMinSamples, nMaxSamples, 1 - dot(worldViewDir, i.normal)));
				float fStepSize = 1.0 / (float)nNumSamples;
				//Current and previous height
				float fCurrHeight = 0.0;
				float fPrevHeight = 1.0;
				//Offset per step and current offstep
				float2 vTexOffsetPerStep = fStepSize * vParallaxOffsetTS;
				float2 vTexCurrentOffset = i.tex.xy;
				//Current bound and parallax amount
				float fCurrentBound = 1.0;
				float fParallaxAmount = 0.0;
				float2 pt1 = 0;
				float2 pt2 = 0;
				float2 dx = ddx(i.tex.xy);
				float2 dy = ddy(i.tex.xy);
				for (int nStepIndex = 0; nStepIndex < nNumSamples; nStepIndex++)
				{
					vTexCurrentOffset -= vTexOffsetPerStep;
					fCurrHeight = tex2D(_HeightMap, vTexCurrentOffset, dx, dy).r;
					fCurrentBound -= fStepSize;
					if (fCurrHeight > fCurrentBound)
					{
						pt1 = float2(fCurrentBound, fCurrHeight);
						pt2 = float2(fCurrentBound + fStepSize, fPrevHeight);
						nStepIndex = nNumSamples + 1;
						fPrevHeight = fCurrHeight;
					}
					else
					{
						fPrevHeight = fCurrHeight;
					}
				}

				float fDelta2 = pt2.x - pt2.y;
				float fDelta1 = pt1.x - pt1.y;
				float fDenominator = fDelta2 - fDelta1;
				if (fDenominator == 0.0f)
				{
					fParallaxAmount = 0.0f;
				}
				else
				{
					//Sample point in the height profile
					fParallaxAmount = (pt1.x * fDelta2 - pt2.x * fDelta1) / fDenominator;
				}
				i.tex.xy -= vParallaxOffsetTS * (1 - fParallaxAmount);
				float4 tex = tex2D(_Texture, i.tex.xy);
				return float4(tex.xyz, 1.0);
				}
			ENDCG
			}
		}
}