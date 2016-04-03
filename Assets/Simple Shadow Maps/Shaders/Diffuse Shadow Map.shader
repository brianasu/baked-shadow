Shader "Shadow/Diffuse Shadow Map"
{
	Properties
	{
		_MainTex ("Main", 2D) = "white" {}
		_ShadowStrength ("Shadow Strength", Range(0, 1)) = 0.5
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" "Queue"="Geometry" }

		CGPROGRAM
		#pragma surface surf Lambert vertex:vert

			const float2 poissonDisk[4] =
			{
				float2(-0.94201624, -0.39906216),
				float2(0.94558609, -0.76890725),
				float2(-0.094184101, -0.92938870),
				float2(0.34495938, 0.29387760)
			};

			struct Input
			{
				float2 uv_MainTex : TEXCOORD0;
				float3 uA : TEXCOORD1;
			};

			sampler2D _MainTex;
			fixed _ShadowStrength;

			//Global values
			sampler2D _ShadowMap;
			float4 _CameraSettings;
			float4x4 _ShadowMapMat;
			float4x4 _ShadowMapMV;
			
			void vert (inout appdata_full v, out Input o)
			{
				UNITY_INITIALIZE_OUTPUT(Input, o);
				o.uA.xy = mul(_ShadowMapMat, mul(_Object2World, v.vertex));
				o.uA.z = -mul(_ShadowMapMV, mul(_Object2World, v.vertex)).z / _CameraSettings.x;
			}

			void surf (Input IN, inout SurfaceOutput o)
			{
				fixed4 col = tex2D(_MainTex, IN.uv_MainTex);
				
				fixed shadow = step(IN.uA.z, tex2D(_ShadowMap, IN.uA.xy).r);

				o.Albedo = lerp(col.rgb, col.rgb * shadow, _ShadowStrength);
			  	
				o.Alpha = col.a;
			}
		ENDCG
	}
}
