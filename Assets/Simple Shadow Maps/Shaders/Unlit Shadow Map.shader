// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Shadow/Unlit Shadow Map"
{
	Properties
	{
		_MainTex ("Main", 2D) = "white" {}
		_ShadowStrength ("Shadow Strength", Range(0, 1)) = 0.5
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" "Queue"="Geometry" }

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment surf
			#include "UnityCG.cginc"


			#define BLOCKER_SEARCH_NUM_SAMPLES 16
            #define PCF_NUM_SAMPLES 4
            #define NEAR_PLANE 9.5
            #define LIGHT_WORLD_SIZE 2.5
            #define LIGHT_FRUSTUM_WIDTH 3.75
            
            #define LIGHT_SIZE_UV (LIGHT_WORLD_SIZE / LIGHT_FRUSTUM_WIDTH)
            float2 poissonDisk[16] = {
                float2( -0.94201624, -0.39906216 ),
                float2( 0.94558609, -0.76890725 ),
                float2( -0.094184101, -0.92938870 ),
                float2( 0.34495938, 0.29387760 ),
                float2( -0.91588581, 0.45771432 ),
                float2( -0.81544232, -0.87912464 ),
                float2( -0.38277543, 0.27676845 ),
                float2( 0.97484398, 0.75648379 ),
                float2( 0.44323325, -0.97511554 ),
                float2( 0.53742981, -0.47373420 ),
                float2( -0.26496911, -0.41893023 ),
                float2( 0.79197514, 0.19090188 ),
                float2( -0.24188840, 0.99706507 ),
                float2( -0.81409955, 0.91437590 ),
                float2( 0.19984126, 0.78641367 ),
                float2( 0.14383161, -0.14100790 )
            };

	
				struct Input
				{
					float4 pos : SV_POSITION;
					float2 uv_MainTex : TEXCOORD0;
					float3 uA  : TEXCOORD1;
				};
	
				sampler2D _MainTex;
				float4 _MainTex_ST;
				fixed _ShadowStrength;
	
				//Global values
				sampler2D _ShadowMap;
				float4 _CameraSettings;
				float4x4 _ShadowMapMat;
				float4x4 _ShadowMapMV;
				
				Input vert (appdata_base v)
				{
					Input o;
					
					o.pos = UnityObjectToClipPos(v.vertex);
					o.uv_MainTex = v.texcoord * _MainTex_ST.xy + _MainTex_ST.zw;
					
					o.uA.xy = mul(_ShadowMapMat, mul(unity_ObjectToWorld, v.vertex));
					o.uA.z = -mul(_ShadowMapMV, mul(unity_ObjectToWorld, v.vertex)).z / _CameraSettings.x;
					
					return o;
				}

            float PCF_Filter( float2 uv, float zReceiver, float filterRadiusUV )
            {
                float totalShadow = 0;

                for ( int i = 0; i < PCF_NUM_SAMPLES; i++)
                {
                    float2 uvOffset = poissonDisk[i] * filterRadiusUV;
                    totalShadow += step(zReceiver, tex2D(_ShadowMap, uv + uvOffset).r); 
                }
                return totalShadow / 2;
            }

	
				fixed4 surf (Input IN) : COLOR
				{
					fixed4 col = tex2D(_MainTex, IN.uv_MainTex);
					
					fixed shadow = step(tex2D(_ShadowMap, IN.uA.xy).r, IN.uA.z);
					
					fixed3 Albedo = 0;
				  	Albedo = col.rgb;
				  	Albedo -= shadow * _ShadowStrength;
				  	
					fixed Alpha = col.a;

					return PCF_Filter(IN.uA.xy, IN.uA.z, 0.00001);
					
					return fixed4(Albedo, Alpha);
				}
				
			ENDCG
		}
	}
}
