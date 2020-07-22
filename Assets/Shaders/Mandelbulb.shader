Shader "Ray Marching/Mandelbulb"
{
    Properties
    {
        [Header(Main Maps)] [Space]
        _Tint ("Albedo", Color) = (1.0, 1.0, 1.0)
        [Gamma] _Metallic ("Metallic", Range(0, 1)) = 0.0
        _Smoothness ("Smoothness", Range(0, 1)) = 0.5

        [Header(Mandelbulb Parameters)] [Space]
        _Iterations ("Iterations", Int) = 10
        _Power ("Power", Int) = 8
        _EscapeRadius ("Escape Radius", Float) = 2.0
        _Scale ("Scale", Float) = 0.4

        [Header(Ray Marching Options)] [Space]
        _Tolerance ("Tolerance", Float) = 0.001
        [Toggle] _RelativeTolerance ("Relative Tolerance", Float) = 1.0
        _MaxDistance ("Max. Distance", Float) = 1000.0
        _MaxSteps ("Max. Steps", Int) = 100

        [Space]
        [KeywordEnum(Fast, Forward, Centered, Tetrahedron)] _NormalApproxMode ("Normal Approx. Mode", Float) = 0.0
        _NormalApproxStep ("Normal Approx. Step", Float) = 0.001
        [Toggle] _NormalFiltering ("Normal Filtering", Float) = 1.0

        [Space]
        [Toggle] _AmbientOcclusion ("Ambient Occlusion", Float) = 1.0
        _AmbientOcclusionMultiplier ("Ambient Occlusion Multiplier", Float) = 1.0
        _AmbientOcclusionStep ("Ambient Occlusion Step", Float) = 0.1
        _AmbientOcclusionSamples ("Ambient Occlusion Samples", Int) = 5

        [Space]
        [KeywordEnum(None, Hard, Soft)] _ShadowMode ("Shadow Mode", Float) = 0.0
        _SoftShadowFactor ("Soft Shadow Factor", Float) = 1.0
    }

    CGINCLUDE
        #include "RayMarchingSDF.cginc"

        int _Iterations;
        int _Power;
        float _EscapeRadius;
        float _Scale;

        float SDF(float3 pos)
        {
            if (length(pos) > 1) {
                return Sphere(pos, 0, 0.5);
            }
            pos = pos/_Scale;
            float3 z = pos;
            float dr = 1.0;
            float r = 0.0;
            for (int i = 0; i < _Iterations; ++i) {
                // Convert to polar coordinates
                r = length(z);
                if (r > _EscapeRadius)
                    break;
                float theta = acos(z.y/r);
		        float phi = atan2(z.z,z.x);
                dr =  pow(r, _Power - 1.0) * _Power * dr + 1.0;
                
                // Scale and rotate the point
                float zr = pow(r, _Power);
                theta = theta * _Power;
                phi = phi * _Power;
                
                // Convert back to cartesian coordinates
                z = zr * float3(sin(theta)*cos(phi), cos(theta), sin(phi)*sin(theta));
                z += pos;
            }
            return _Scale * 0.5 * log(r) * r / dr;
        }
    ENDCG

    SubShader
    {
        Tags { "Queue"="AlphaTest" }

        Pass
        {
            Tags { "LightMode" = "ForwardBase" }
            Cull Front

            CGPROGRAM
            #pragma target 3.0
            
            #pragma shader_feature_local _RELATIVETOLERANCE_ON
            #pragma shader_feature_local _NORMALFILTERING_ON
            #pragma shader_feature_local _AMBIENTOCCLUSION_ON
            #pragma shader_feature_local _SELFSHADOWS_ON
            
            #pragma multi_compile_local _NORMALAPPROXMODE_FAST _NORMALAPPROXMODE_FORWARD _NORMALAPPROXMODE_CENTERED _NORMALAPPROXMODE_TETRAHEDRON
            #pragma multi_compile_local _SHADOWMODE_NONE _SHADOWMODE_HARD _SHADOWMODE_SOFT

            #pragma vertex vert
            #pragma fragment fragBase
            #include "RayMarching.cginc"
            ENDCG
        }

        Pass
        {
            Tags { "LightMode" = "ForwardAdd" }
            Cull Front
            ZWrite Off
            Blend One One

            CGPROGRAM
            #pragma target 3.0
            
            #pragma shader_feature_local _RELATIVETOLERANCE_ON
            #pragma shader_feature_local _NORMALFILTERING_ON
            #pragma shader_feature_local _AMBIENTOCCLUSION_ON
            #pragma shader_feature_local _SELFSHADOWS_ON
            
            #pragma multi_compile_local _NORMALAPPROXMODE_FAST _NORMALAPPROXMODE_FORWARD _NORMALAPPROXMODE_CENTERED _NORMALAPPROXMODE_TETRAHEDRON
            #pragma multi_compile_local _SHADOWMODE_NONE _SHADOWMODE_HARD _SHADOWMODE_SOFT

            #pragma multi_compile_fwdadd

            #pragma vertex vert
            #pragma fragment fragAdd
            #include "RayMarching.cginc"
            ENDCG
        }

        Pass
        {
            Tags { "LightMode" = "ShadowCaster" }
            Cull Front

            CGPROGRAM
            #pragma target 3.0
            
            #pragma shader_feature_local _RELATIVETOLERANCE_ON
            #pragma shader_feature_local _NORMALFILTERING_ON
            #pragma shader_feature_local _AMBIENTOCCLUSION_ON
            #pragma shader_feature_local _SELFSHADOWS_ON
            
            #pragma multi_compile_local _NORMALAPPROXMODE_FAST _NORMALAPPROXMODE_FORWARD _NORMALAPPROXMODE_CENTERED _NORMALAPPROXMODE_TETRAHEDRON
            #pragma multi_compile_local _SHADOWMODE_NONE _SHADOWMODE_HARD _SHADOWMODE_SOFT

            #pragma multi_compile_fwdadd

            #pragma vertex vert
            #pragma fragment fragShadowCaster
            #include "RayMarching.cginc"
            ENDCG
        }
    }
}
