// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Custom/Hatching/Warp Lambert Detail Outline" {
	Properties {
		_Color ("Main Color", Color) = (0.5,0.5,0.5,1)
		[Toggle(OUTLINE_ON)] _UseOutline("Use Outline?", Float) = 0
		_OutlineColor ("Outline Color", Color) = (0,0,0,1)
		_Outline ("Outline width", Range (.002, 0.03)) = .005
		_OutlineFalloff ("Outline Falloff", Range (0.0, 1.0)) = 0.5
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_DetailTex ("Detail Map (RGB)", 2D) = "white" {}
		[Toggle(WARP_ON)] _UseWarp("Apply warping to lighting?", Float) = 0
		_LightScale ("Warp Lighting Scale", Float) = 0.5
		_LightBias ("Warp Lighting Bias", Float) = 0.5
		_LightExponent ("Warp Lighting Exponent", Float) = 2
		_DirectionalRamp ("Directional Light Ramp (RGB)", 2D) = "gray" {} 
		_SecondaryRamp ("Secondary Light Ramp (RGB)", 2D) = "gray" {} 
		_SecondaryIntensity("Secondary Lighting Intensity", Range(0,1)) = 1

		_HatchingPower ("Hatching Intensity", Range(0.0,2.0)) = 1.0
		// Hatching code adapted from https://forum.unity3d.com/threads/cross-hatching-overlaying-main-texture.197458/
		_Hatch0 ("Hatch 0 (light)", 2D) = "white" {}
        [NoScaleOffset] _Hatch1 ("Hatch 1", 2D) = "white" {}       
        [NoScaleOffset] _Hatch2 ("Hatch 2", 2D) = "white" {}
        [NoScaleOffset] _Hatch3 ("Hatch 3", 2D) = "white" {}       
        [NoScaleOffset] _Hatch4 ("Hatch 4", 2D) = "white" {}       
        [NoScaleOffset] _Hatch5 ("Hatch 5 (dark)", 2D) = "white" {}      
	}

	// Simple surface shader outline with falloff

	SubShader {
		
	// }

	// SubShader {
		// Main shader pass
		Tags { "RenderType"="Opaque" "Queue" = "Geometry" "IgnoreProjector" = "True"}
		Cull Back
		Blend Off
		CGPROGRAM
		#pragma target 4.6
		#pragma surface surf ToonRamp fullforwardshadows addshadow
		#pragma shader_feature WARP_ON

		half _LightScale;
		half _LightBias;
		half _LightExponent;

		sampler2D _DirectionalRamp;
		sampler2D _SecondaryRamp;
		half _SecondaryIntensity;

		// Hatching samplers
		fixed _HatchingPower;
		sampler2D _Hatch0;
        sampler2D _Hatch1;
        sampler2D _Hatch2;
        sampler2D _Hatch3;
        sampler2D _Hatch4;
        sampler2D _Hatch5;

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


        struct SurfaceOutputCustom{
        	fixed3 Albedo;
			fixed3 Normal;
			fixed3 Emission;

			fixed Alpha;
			half Specular;
			fixed Gloss;

			float2 hatchUV;
        };

		


		sampler2D _MainTex;
		sampler2D _DetailTex;
		float4 _Color;

		struct Input {
			float2 uv_MainTex : TEXCOORD0;
			float2 uv_DetailTex;
			float2 uv_Hatch0;
		};

		

		void surf (Input IN, inout SurfaceOutputCustom o) {
			half4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
			c *= tex2D(_DetailTex, IN.uv_DetailTex);
			o.Albedo = c.rgb;

			// Apply hatching
			//o.Albedo *= Hatching(IN.uv_Hatch0, IN.atten).rgb;

			o.hatchUV = IN.uv_Hatch0;

			o.Alpha = 1.0;

		}

		// custom lighting function that uses a texture ramp based
		// on angle between light direction and normal
		#pragma lighting ToonRamp exclude_path:prepass
		inline half4 LightingToonRamp (SurfaceOutputCustom s, half3 lightDir, half atten)
		{
			#ifndef USING_DIRECTIONAL_LIGHT
			lightDir = normalize(lightDir);
			#endif

			half d = 0.5;
			#ifdef WARP_ON
				d = saturate(dot(s.Normal, lightDir));
				d = pow(d * _LightScale + _LightBias, _LightExponent) * atten;
			#else
				// Modified as per user kebrus in this thread: https://forum.unity3d.com/threads/toon-shader-light-shadows.252952/
				d = (dot (s.Normal, lightDir)*0.5 + 0.5) * atten;
			#endif
			
			// Perform different calculations for Directional vs Point/Spot lights
			// Tell which is which by sampling w of _WorldSpaceLightPos0!
			half3 dirRamp = tex2D (_DirectionalRamp, float2(d,d)).rgb * (1.0 - _WorldSpaceLightPos0.w);
			half3 secondaryRamp = tex2D(_SecondaryRamp, float2(d,d)).rgb * _WorldSpaceLightPos0.w;
			
			half4 c;
			// c.rgb = s.Albedo * _LightColor0.rgb * ramp * (atten * 2);
			//c.rgb = s.Albedo * _LightColor0.rgb * (dirRamp + secondaryRamp*_SecondaryIntensity);
			c.rgb = s.Albedo.rgb * _LightColor0.rgb * Hatching(s.hatchUV, (dirRamp + secondaryRamp*_SecondaryIntensity));
			//c.rgb = s.Albedo * Hatching(s.hatchUV, atten) * _LightColor0.rgb * (dirRamp + secondaryRamp*_SecondaryIntensity);
			c.a = 0;
			return c;
		}
		ENDCG

		Tags{ "RenderType"="Opaque"}
        Cull Front
        Blend Off
        CGPROGRAM
            #pragma surface surf NoLight vertex:vert nolightmap noforwardadd noshadow noambient nodynlightmap nometa
            #pragma shader_feature OUTLINE_ON

            fixed4 LightingNoLight(SurfaceOutput o, fixed3 lightDir, fixed atten){

                return fixed4(0,0,0,0);
            }

            struct Input
            {
                half4 color : COLOR;
            };

            float _Outline;
            float _OutlineFalloff;

            void vert(inout appdata_full v)
            {
            	#ifdef OUTLINE_ON
                	// Scale outline thickness by z falloff from camera pos
               		float3 vPos = UnityObjectToClipPos(v.vertex);
                	v.vertex.xyz += v.normal * _Outline * (1.0 - vPos.z * _OutlineFalloff);
                #endif
                
            }

            fixed4 _OutlineColor;

            void surf(Input IN, inout SurfaceOutput o){
                fixed4 c;
                c.rgb = _OutlineColor;
                c.a = 1.0;
                //o.Smoothness = 0;
                //o.Metallic = 0;
            }



        ENDCG

		//#ifdef _USEOUTLINE_ON
		//UsePass "Toon/Basic Outline/OUTLINE"
		//#endif
	} 
	
	// Fallback "Diffuse"
	Fallback Off
}
