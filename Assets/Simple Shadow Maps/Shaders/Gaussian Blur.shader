// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Hidden/Gauss Blur"
{
	Properties
	{
		_MainTex ("Base (RGB)", 2D) = "" {}
	}

	CGINCLUDE
	#include "UnityCG.cginc"

		struct v2f
		{
			float4 pos : POSITION;
			float2 uv : TEXCOORD0;
		};

		struct v2fBlur
		{
			float4 pos : POSITION;
			float2 uv[6] : TEXCOORD0;
		};

		sampler2D _MainTex;
		float4 _MainTex_TexelSize;
		float _BlurSize = 1;
		
		v2f vert( appdata_img v )
		{
			v2f o;
			o.pos = UnityObjectToClipPos(v.vertex);
			o.uv = v.texcoord;
			return o;
		}		

		v2fBlur vertBlurHorz( appdata_img v )
		{
			v2fBlur o;
			o.pos = UnityObjectToClipPos(v.vertex);

	 		float3 off = float3(_MainTex_TexelSize.x, -_MainTex_TexelSize.x, 0) * 0.5;
			o.uv[0] = v.texcoord.xy + off.xz;
			o.uv[1] = v.texcoord.xy + off.yz;
			
			o.uv[2] = v.texcoord.xy + off.xz * 2;
			o.uv[3] = v.texcoord.xy + off.yz * 2;
			
			o.uv[4] = v.texcoord.xy + off.xz * 3;
			o.uv[5] = v.texcoord.xy + off.yz * 3;
			return o;
		}

		v2fBlur vertBlurVert( appdata_img v )
		{
			v2fBlur o;
			o.pos = UnityObjectToClipPos(v.vertex);

	 		float3 off = float3(_MainTex_TexelSize.y, -_MainTex_TexelSize.y, 0) * 0.5;
			o.uv[0] = v.texcoord.xy + off.zx;
			o.uv[1] = v.texcoord.xy + off.zy;
			
			o.uv[2] = v.texcoord.xy + off.zx * 2;
			o.uv[3] = v.texcoord.xy + off.zy * 2;
			
			o.uv[4] = v.texcoord.xy + off.zx * 3;
			o.uv[5] = v.texcoord.xy + off.zy * 3;
			return o;
		}
		
		float _GlowStrength;
		float _GlowThreshold;
		
		float4 fragContrast(v2f i) : COLOR
		{
			float4 color = tex2D(_MainTex, i.uv);
			color = saturate(color - _GlowThreshold) * _GlowStrength;
			return color;
		}

		float4 fragBlur(v2fBlur i) : COLOR
		{
			float4 color = tex2D(_MainTex, i.uv[0]);
			color += tex2D(_MainTex, i.uv[1]);
			
			color += tex2D(_MainTex, i.uv[2]);
			color += tex2D(_MainTex, i.uv[3]);
			
			color += tex2D(_MainTex, i.uv[4]);
			color += tex2D(_MainTex, i.uv[5]);
			return color / 6;
		}
		
		sampler2D _BlurTex;
		
		float4 fragComposite(v2f i) : COLOR
		{
			float4 blur = tex2D(_BlurTex, i.uv);
			return saturate(tex2D(_MainTex, i.uv) + blur);
		}		
	ENDCG

	Subshader
	{
	
		Pass
		{
			ZTest Always Cull Off ZWrite Off
			Fog { Mode off }
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment fragContrast
			ENDCG
		}
			
		Pass
		{
			ZTest Always Cull Off ZWrite Off
			Fog { Mode off }
			CGPROGRAM
			#pragma vertex vertBlurHorz
			#pragma fragment fragBlur
			ENDCG
		}

		Pass
		{
			ZTest Always Cull Off ZWrite Off
			Fog { Mode off }
			CGPROGRAM
			#pragma vertex vertBlurVert
			#pragma fragment fragBlur
			ENDCG
		}
		
		Pass
		{
		
			ZTest Always Cull Off ZWrite Off
			Fog { Mode off }
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment fragComposite
			ENDCG
		}		
	}

	Fallback off

}