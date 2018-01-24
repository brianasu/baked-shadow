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
	
				fixed4 surf (Input IN) : COLOR
				{
					fixed4 col = tex2D(_MainTex, IN.uv_MainTex);
					
					fixed shadow = step(tex2D(_ShadowMap, IN.uA.xy).r, IN.uA.z);
					
					fixed3 Albedo = 0;
				  	Albedo = col.rgb;
				  	Albedo -= shadow * _ShadowStrength;
				  	
					fixed Alpha = col.a;
					
					return fixed4(Albedo, Alpha);
				}
				
			ENDCG
		}
	}
}
