Shader "Custom/Toon Lit Atten -TS" {
	Properties {
		_Color ("Main Color", Color) = (0.5,0.5,0.5,1)
		_MainTex ("Base (RGB)", 2D) = "white" {}
		[NoScaleOffset] _Ramp ("Toon Ramp (RGB)", 2D) = "gray" {} 

		[NoScaleOffset] _ShadowTex ("Shadowmask (RGB)", 2D) = "white" {}
		[Gamma] _ShadowMaskScale ("Shadow mask scale", float) = 1.0
		_ShadowMaskThreshold ("Shadow mask Threshold", Range(0.0, 1.0)) = 0.5
	}

	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		CGPROGRAM
		#pragma surface surf ToonRamp

		sampler2D _Ramp;
		sampler2D _ShadowTex;

		float _ShadowMaskScale;
		float _ShadowMaskThreshold;

		struct SurfaceOutputCustom{
			fixed3 Albedo;
			fixed3 Normal;
			fixed3 Emission;

			fixed Alpha;
			half Specular;
			fixed Gloss;

			float2 screenUV;
		};

		// custom lighting function that uses a texture ramp based
		// on angle between light direction and normal
		#pragma lighting ToonRamp exclude_path:prepass
		inline half4 LightingToonRamp (SurfaceOutputCustom s, half3 lightDir, half atten)
		{
			#ifndef USING_DIRECTIONAL_LIGHT
			lightDir = normalize(lightDir);
			#endif
			
			//atten = round(atten);
			if(atten < _ShadowMaskThreshold){
				atten = (tex2D(_ShadowTex, s.screenUV)).rgb;
			}
			//atten = max(atten, _ShadowMaskThreshold);
			//atten = atten * tex2D(_ShadowTex, s.screenUV).rgb;
			//atten = 1;
			
			// Modified as per user kebrus in this thread: https://forum.unity3d.com/threads/toon-shader-light-shadows.252952/
			half d = (dot (s.Normal, lightDir)*0.5 + 0.5) * atten;
			

			if(d < _ShadowMaskThreshold){
				d = (tex2D(_ShadowTex, s.screenUV)).rgb;
			}else d = 1;

			half3 ramp = tex2D (_Ramp, float2(d,d)).rgb;

			
			half4 c;
			//c.rgb = s.Albedo * _LightColor0.rgb * ramp * (atten * 2);
			c.rgb = s.Albedo * _LightColor0.rgb * ramp;

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
			o.screenUV = uvTemp * _ShadowMaskScale;
		}
		ENDCG

	} 

	Fallback "Diffuse"
}
