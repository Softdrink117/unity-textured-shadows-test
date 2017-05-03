// Adapted from https://forum.unity3d.com/threads/cross-hatching-overlaying-main-texture.197458/
Shader "Custom/Hatching2"
{
    Properties
    {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _Hatch0 ("Hatch 0 (light)", 2D) = "white" {}
        _Hatch1 ("Hatch 1", 2D) = "white" {}       
        _Hatch2 ("Hatch 2", 2D) = "white" {}
        _Hatch3 ("Hatch 3", 2D) = "white" {}       
        _Hatch4 ("Hatch 4", 2D) = "white" {}       
        _Hatch5 ("Hatch 5 (dark)", 2D) = "white" {}                
    }
   
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
       
        CGPROGRAM
        #pragma target 3.0
       
        // NB: The intensity and tint calculations doesn't work with additive passes so exclude them
        #pragma surface surf Lambert finalcolor:FinalColor noforwardadd
       
        sampler2D _MainTex;
        sampler2D _Hatch0;
        sampler2D _Hatch1;
        sampler2D _Hatch2;
        sampler2D _Hatch3;
        sampler2D _Hatch4;
        sampler2D _Hatch5;
       
        struct Input
        {
            float2 uv_MainTex;
            float2 uv_Hatch0;
        };
 
        void surf(Input IN, inout SurfaceOutput o)
        {
            o.Albedo = (half3)tex2D(_MainTex, IN.uv_MainTex).rgb;
        }
       
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
       
        void FinalColor(Input IN, SurfaceOutput o, inout half4 color)
        {
            // Calculate pixel intensity and tint
            half intensity = dot(color.rgb, half3(0.3, 0.59, 0.11));
            half3 tint = color.rgb / max(intensity, 1.0 / 255.0);
           
            // Apply hatching
            color.rgb = tint * Hatching(IN.uv_Hatch0, intensity);
        }
        ENDCG
    }
   
    Fallback "Diffuse"
}