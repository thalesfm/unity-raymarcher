Shader "Hidden/Custom/BlitCopyWithLastCameraDepth"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _SrcBlend ("SrcBlend", Int) = 5 // SrcAlpha
        _DstBlend ("DstBlend", Int) = 10 // OneMinusSrcAlpha
        _ZWrite ("ZWrite", Int) = 1 // On
        _ZTest ("ZTest", Int) = 4 // LEqual
        _Cull ("Cull", Int) = 0 // Off
        _ZBias ("ZBias", Float) = 0.0
    }

    SubShader
    {
        Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }

        Pass
        {
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            ZTest [_ZTest]
            Cull [_Cull]
            Offset [_ZBias], [_ZBias]

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // #pragma target 2.0
            // #pragma multi_compile _ UNITY_SINGLE_PASS_STEREO STEREO_INSTANCING_ON STEREO_MULTIVIEW_ON

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 texcoord : TEXCOORD0;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            UNITY_DECLARE_DEPTH_TEXTURE(_LastCameraDepthTexture);

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
                return o;
            }

            fixed4 frag(v2f i, out float outDepth : SV_Depth) : SV_Target
            {
                outDepth = SAMPLE_DEPTH_TEXTURE(_LastCameraDepthTexture, i.texcoord);
                return tex2D(_MainTex, i.texcoord);
            }
            ENDCG
        }
    }
}
