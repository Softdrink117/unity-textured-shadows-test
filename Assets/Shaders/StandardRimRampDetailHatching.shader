Shader "Custom/StandardRimRampDetailHatching" {
	Properties {
		_Color ("Diffuse", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}

		_BumpMap ("Normal Map", 2D) = "bump" {}
		_BumpStrength ("Normal Intensity", Range(-2.0,2.0)) = 1.0

		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0

		_RimColor ("Rim Color", Color) = (1,1,1,1)
		_RimPower ("Rim Strength", Range(0.0,10.0)) = 0.5
		_RimRamp ("Rim Light Ramp", 2D) = "gray" {}

		_Detail ("Detail Texture", 2D) = "white" {}
		_DetailPower ("Detail Intensity", Range(0.0,2.0)) = 1.0

		_HatchingPower ("Hatching Intensity", Range(0.0,2.0)) = 1.0
		// Hatching code adapted from https://forum.unity3d.com/threads/cross-hatching-overlaying-main-texture.197458/
		_Hatch0 ("Hatch 0 (light)", 2D) = "white" {}
        _Hatch1 ("Hatch 1", 2D) = "white" {}       
        _Hatch2 ("Hatch 2", 2D) = "white" {}
        _Hatch3 ("Hatch 3", 2D) = "white" {}       
        _Hatch4 ("Hatch 4", 2D) = "white" {}       
        _Hatch5 ("Hatch 5 (dark)", 2D) = "white" {}      
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Standard fullforwardshadows finalcolor:FinalColor

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0

		sampler2D _MainTex;
		fixed4 _Color;

		half _Glossiness;
		half _Metallic;

		sampler2D _BumpMap;
		fixed _BumpStrength;

		float4 _RimColor;
		half _RimPower;
		sampler2D _RimRamp;

		half _DetailPower;
		sampler2D _Detail;

		// Hatching samplers
		fixed _HatchingPower;
		sampler2D _Hatch0;
        sampler2D _Hatch1;
        sampler2D _Hatch2;
        sampler2D _Hatch3;
        sampler2D _Hatch4;
        sampler2D _Hatch5;



		struct Input {
			float2 uv_MainTex;
			float2 uv_BumpMap;
			float2 uv_Detail;
			float2 uv_Hatch0;

			float3 viewDir;
		};

		
		// Calculate hatching setup
		// Adapted from https://forum.unity3d.com/threads/cross-hatching-overlaying-main-texture.197458/
		half3 Hatching(float2 _uv, half _intensity)
        {
            half3 hatch0 = (half3)tex2D(_Hatch0, _uv).rgb;
            half3 hatch1 = (half3)tex2D(_Hatch1, _uv).rgb;
            half3 hatch2 = (half3)tex2D(_Hatch2, _uv).rgb;
            half3 hatch3 = (half3)tex2D(_Hatch3, _uv).rgb;
            half3 hatch4 = (half3)tex2D(_Hatch4, _uv).rgb;
            half3 hatch5 = (half3)tex2D(_Hatch5, _uv).rgb;
           
            const half hatchingScale = 6.0 / 7.0;
            half hatchedIntensity = min(_intensity, hatchingScale);
            half remainingIntensity = _intensity - hatchedIntensity;
            half unitHatchedIntensity = hatchedIntensity / hatchingScale;
           
            half3 weightsA = saturate((unitHatchedIntensity * 6.0) + half3(-5.0, -4.0, -3.0));
            half3 weightsB = saturate((unitHatchedIntensity * 6.0) + half3(-2.0, -1.0, 0.0));
           
            weightsB.yz = saturate(weightsB.yz - weightsB.xy);
            weightsB.x = saturate(weightsB.x - weightsA.z);
            weightsA.yz = saturate(weightsA.yz - weightsA.xy);
           
            half3 hatching = remainingIntensity;
            hatching += hatch0 * weightsA.x;
            hatching += hatch1 * weightsA.y;
            hatching += hatch2 * weightsA.z;
            hatching += hatch3 * weightsB.x;
            hatching += hatch4 * weightsB.y;
            hatching += hatch5 * weightsB.z;
            return hatching;
        }

		// Adapted from:
		// http://elringus.me/blend-modes-in-unity/
		fixed4 Screen (fixed4 a, fixed4 b) {
		    fixed4 r = 1.0 - (1.0 - a) * (1.0 - b);
		    r.a = b.a;
		    return r;
		 }

		void surf (Input IN, inout SurfaceOutputStandard o) {
			// Albedo comes from a texture tinted by color
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			// Detail texture and intensity
			o.Albedo *= (1.0 + (tex2D(_Detail, IN.uv_Detail).rgb * _DetailPower));

			// Metallic and smoothness come from slider variables
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;

			// Scalable bump map intensity
			fixed3 norm = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
			norm.xy *= _BumpStrength;
			o.Normal = normalize(norm);

			// Rim lighting, sampled from ramp
			half rim = 1.0 - saturate(dot(normalize(IN.viewDir), o.Normal));
			half rampedRim = tex2D(_RimRamp, float2(rim, 0.5)).r;
			// o.Emission = _RimColor.rgb * pow(rim, _RimPower);
			o.Emission= Screen(c, _RimColor) * rampedRim * _RimPower;
			
		}

		// Apply hatching in FinalColor pass
		void FinalColor(Input IN, SurfaceOutputStandard o, inout fixed4 color)
        {
            // Calculate pixel intensity and tint
            half intensity = dot(color.rgb, half3(0.3, 0.59, 0.11));
            half3 tint = color.rgb / max(intensity, 1.0 / 255.0);
           
            // Apply hatching
            color.rgb = tint * Hatching(IN.uv_Hatch0, intensity);
        }
		ENDCG
	}
	FallBack "Diffuse"
}
