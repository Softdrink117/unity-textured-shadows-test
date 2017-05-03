// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Custom/Warp Lambert Detail Outline" {
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
	}

	// Simple surface shader outline with falloff

	SubShader {
		Tags{ "RenderType"="Opaque"}
        Cull Front
        CGPROGRAM
            #pragma surface surf NoLight vertex:vert nolightmap noforwardadd noshadow noambient nodynlightmap nometa

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

                // Scale outline thickness by z falloff from camera pos
                float3 vPos = UnityObjectToClipPos(v.vertex);
                v.vertex.xyz += v.normal * _Outline * (1.0 - vPos.z * _OutlineFalloff);
                
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
	// }

	// SubShader {
		Tags { "RenderType"="Opaque"}
		
		CGPROGRAM
		#pragma target 4.6
		#pragma surface surf ToonRamp 
		#pragma shader_feature WARP_ON
		#pragma shader_feature SECONDARY_WARP_ON

		half _LightScale;
		half _LightBias;
		half _LightExponent;

		sampler2D _DirectionalRamp;
		sampler2D _SecondaryRamp;
		half _SecondaryIntensity;

		// custom lighting function that uses a texture ramp based
		// on angle between light direction and normal
		#pragma lighting ToonRamp exclude_path:prepass
		inline half4 LightingToonRamp (SurfaceOutput s, half3 lightDir, half atten)
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
			c.rgb = s.Albedo * _LightColor0.rgb * (dirRamp + secondaryRamp*_SecondaryIntensity);
			c.a = 0;
			return c;
		}


		sampler2D _MainTex;
		sampler2D _DetailTex;
		float4 _Color;

		struct Input {
			float2 uv_MainTex : TEXCOORD0;
			float2 uv_DetailTex;
		};

		

		void surf (Input IN, inout SurfaceOutput o) {
			half4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
			c *= tex2D(_DetailTex, IN.uv_DetailTex);
			o.Albedo = c.rgb;
			o.Alpha = c.a;

		}
		ENDCG

		//#ifdef _USEOUTLINE_ON
		//UsePass "Toon/Basic Outline/OUTLINE"
		//#endif
	} 
	
	Fallback "Toon/Lit"
}
