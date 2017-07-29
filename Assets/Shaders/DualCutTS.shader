Shader "Custom/Dual Cut TS" {
	Properties {
		_Color ("Main Color", Color) = (0.5,0.5,0.5,1)
		_MainTex ("Base (RGB)", 2D) = "white" {}

		[KeywordEnum(MeshUV, ScreenUV)] _UVMode ("Texture UV Mode", Float) = 0

		_Cut1 ("Shadows Cutoff", Range(0.0,1.0)) = 0.0
		_Cut2 ("Midtones Cutoff", Range(0.0, 1.0)) = 0.5
		//[NoScaleOffset] _ShadeNoise ("Light Distortion (R)", 2D) = "black" {}
		//[Gamma] _ShadeNoiseScale ("Light Distort Scale", Range(0.0, 3.0)) = 1.0

		[NoScaleOffset] _ShadowTex ("Shadows Tex (R)", 2D) = "black" {}
		[Gamma] _ShadowTexScale ("Shadow Tex Scale", float) = 1.0
		[NoScaleOffset] _MidtonesTex ("Midtones Tex (R)", 2D) = "gray"
		[Gamma] _MidtonesTexScale ("Midtones Tex Scale", float) = 1.0
		_ShadowMaskSpeed ("Shadow Scroll Speed (XY)", Vector) = (1.0, 1.0, 0.0, 0.0)
	}

	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		CGPROGRAM
		#pragma surface surf ToonRamp
		#pragma multi_compile _UVMODE_MESHUV _UVMODE_SCREENUV

		half _Cut1;
		half _Cut2;

		sampler2D _ShadowTex;
		sampler2D _MidtonesTex;
		//sampler2D _ShadeNoise;

		//float _ShadeNoiseScale;
		float _ShadowTexScale;
		float _MidtonesTexScale;

		float2 _ShadowMaskSpeed;

		struct SurfaceOutputCustom{
			fixed3 Albedo;
			fixed3 Normal;
			fixed3 Emission;

			fixed Alpha;
			half Specular;
			fixed Gloss;

			float2 screenUV;
			float2 meshUV;
		};

		// Apply cuts / ramping to the diff lighting term
		half cuts(half diff, SurfaceOutputCustom s){
			float cut1 = 0.0;
			float cut2 = 0.0;

			#ifdef _UVMODE_SCREENUV
			cut1 = (1.0 - step(_Cut1, diff)) * (tex2D(_ShadowTex, s.screenUV *_ShadowTexScale + _ShadowMaskSpeed*_Time.y)).r;
			cut2 = step(_Cut1, diff) * ((1.0 - step(_Cut2, diff)) * (tex2D(_MidtonesTex, s.screenUV *_MidtonesTexScale + _ShadowMaskSpeed*_Time.y)).r);
			#endif

			#ifdef _UVMODE_MESHUV
			cut1 = (1.0 - step(_Cut1, diff)) * (tex2D(_ShadowTex, s.meshUV *_ShadowTexScale + _ShadowMaskSpeed*_Time.y)).r;
			cut2 = step(_Cut1, diff) * ((1.0 - step(_Cut2, diff)) * (tex2D(_MidtonesTex, s.meshUV *_MidtonesTexScale + _ShadowMaskSpeed*_Time.y)).r);
			#endif

			float highlight = step(_Cut2, diff);
			return cut1 + cut2 + highlight;
		}

		// custom lighting function that uses a texture ramp based
		// on angle between light direction and normal
		#pragma lighting ToonRamp exclude_path:prepass
		inline half4 LightingToonRamp (SurfaceOutputCustom s, half3 lightDir, half atten)
		{
			#ifndef USING_DIRECTIONAL_LIGHT
			lightDir = normalize(lightDir);
			#endif
						
			// Modified as per user kebrus in this thread: https://forum.unity3d.com/threads/toon-shader-light-shadows.252952/
			half d = (dot (s.Normal, lightDir)*0.5 + 0.5) * atten;
			
			// #ifdef _UVMODE_SCREENUV
			// d += (tex2D(_ShadeNoise, float2(d ,s.screenUV.y * _ShadeNoiseScale))).r;
			// #endif

			// #ifdef _UVMODE_MESHUV
			// d += (tex2D(_ShadeNoise, float2(d ,s.meshUV.y * _ShadeNoiseScale))).r;
			// #endif

			d = cuts(d, s);

	
			half4 c;
			//c.rgb = s.Albedo * _LightColor0.rgb * ramp * (atten * 2);
			c.rgb = s.Albedo * _LightColor0.rgb * d;

			c.a = 0;
			return c;
		}


		sampler2D _MainTex;
		float4 _Color;

		struct Input {
			float2 uv_MainTex : TEXCOORD0;
			float4 screenPos;
		};

		void surf (Input IN, inout SurfaceOutputCustom o) {
			half4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			o.Alpha = c.a;

			float2 uvTemp = IN.screenPos.xy/IN.screenPos.w;
			// o.screenUV = uvTemp * _ShadowTexScale;
			o.screenUV = uvTemp;
			o.meshUV = IN.uv_MainTex;
		}
		ENDCG

	} 

	Fallback "Diffuse"
}
