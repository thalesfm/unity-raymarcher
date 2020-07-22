// TODO: Rewrite using deferred path to decrease the number of passes

#ifndef RAYMARCHING_INCLUDED
#define RAYMARCHING_INCLUDED

// NOTE: UnityCG.cginc must be included before AutoLight.cginc otherwise
//       ObjSpaceLightDir stops working
#include "UnityCG.cginc"
#include "AutoLight.cginc"
#include "UnityPBSLighting.cginc"
#include "UnityGlobalIllumination.cginc"

#ifdef _RELATIVETOLERANCE_ON
#define TOLERANCE(t) (_Tolerance * (t))
#else
#define TOLERANCE(t) _Tolerance
#endif

#ifdef _NORMALFILTERING_ON
#define NORMAL_APPROX_STEP(t) (_NormalApproxStep * (t))
#else
#define NORMAL_APPROX_STEP(t) _NormalApproxStep
#endif

struct TraceHit
{
    bool missed;
    float t;
    float3 pos;
    int steps;
};

struct VertexInput
{
    float4 vertex : POSITION;
};

struct VertexOutput
{
    UNITY_POSITION(pos);
    float3 rayOrigin : TEXCOORD0;
    float3 rayDirection : TEXCOORD1;
};

float3 _Tint;
float _Metallic;
float _Smoothness;

float _Tolerance;
float _RelativeTolerance;
float _MaxDistance;
int _MaxSteps;

float _NormalApproxScheme;
float _NormalApproxStep;
float _NormalFiltering;

float _AmbientOcclusion;
float _AmbientOcclusionMultiplier;
float _AmbientOcclusionStep;
int _AmbientOcclusionSamples;

float _SoftShadowFactor;

// NOTE: This function serves as a replacement for Unity's builtin variables
//       since those don't work during shadow cast passes.
float3 ObjSpaceCameraPos()
{
    return float3(
        UNITY_MATRIX_IT_MV[3][0],
        UNITY_MATRIX_IT_MV[3][1],
        UNITY_MATRIX_IT_MV[3][2]
    );
}

float3 Backoff(float3 pos, float3 normal, float t)
{
    return pos + TOLERANCE(t) * normal;
}

float Depth(float3 pos)
{
    float4 clipPos = UnityObjectToClipPos(pos);
    return clipPos.z / clipPos.w;
}

float DepthWithBias(float3 pos, float3 normal)
{
    float4 clipPos = UnityClipSpaceShadowCasterPos(pos, normal);
    clipPos = UnityApplyLinearShadowBias(clipPos);
    return clipPos.z / clipPos.w;
}

void Trace(float3 rayOrigin, float3 rayDirection, float maxDistance, out TraceHit outHit)
{
    float t = 0.0;
    float3 pos;
    int steps = 0;

    for (steps = 0; steps < _MaxSteps && t < maxDistance; ++steps) {
        pos = rayOrigin + t * rayDirection;
        float d = SDF(pos);
        if (d < TOLERANCE(t)) {
            break;
        }
        t += d;
    }

    outHit.missed = t >= maxDistance;
    outHit.t = t;
    outHit.pos = pos;
    outHit.steps = steps;
}

float TraceSoftShadow(float3 rayOrigin, float3 rayDirection, float maxDistance)
{
    float t = 0;
    float softShadow = 1;

    for (int steps = 0; steps < _MaxSteps && t < maxDistance; ++steps) {
        float3 pos = rayOrigin + t * rayDirection;
        float d = SDF(pos);
        if (d < TOLERANCE(t)) {
            return 0;
        }
        t += d;
        softShadow = min(_SoftShadowFactor * d / t, softShadow);
    }

    return softShadow;
}

float3 Normal(float3 p, float t)
{
    float3 h = float3(NORMAL_APPROX_STEP(t), -NORMAL_APPROX_STEP(t), 0);
#ifdef _NORMALAPPROXMODE_FAST
    return normalize(float3(
        SDF(p + h.xzz),
        SDF(p + h.zxz),
        SDF(p + h.zzx)
    ));
#elif defined(_NORMALAPPROXMODE_FORWARD)
    return normalize(float3(
        SDF(p + h.xzz) - SDF(p),
        SDF(p + h.zxz) - SDF(p),
        SDF(p + h.zzx) - SDF(p)
    ));
#elif defined(_NORMALAPPROXMODE_CENTERED)
    return normalize(float3(
        SDF(p + h.xzz) - SDF(p - h.xzz),
        SDF(p + h.zxz) - SDF(p - h.zxz),
        SDF(p + h.zzx) - SDF(p - h.zzx)
    ));
#elif defined(_NORMALAPPROXMODE_TETRAHEDRON)
    const float2 s = float2(1, -1);
    return normalize(
        s.xyy * SDF(p + h.xyy) +
        s.yyx * SDF(p + h.yyx) +
        s.yxy * SDF(p + h.yxy) +
        s.xxx * SDF(p + h.xxx)
    );
#endif
}

float AmbientOcclusion(float3 p, float3 n)
{
#ifdef _AMBIENTOCCLUSION_ON
    float acc = 0;
    for (int i = 1; i <= _AmbientOcclusionSamples; ++i) {
        float d = SDF(p + i*_AmbientOcclusionStep*n);
        acc += exp2(-i) * (i*_AmbientOcclusionStep - max(d, 0));
    }
    return min(1 - _AmbientOcclusionMultiplier * acc, 1);
#else
    return 1;
#endif
}

float Shadow(float3 pos)
{
    float3 lightDir = ObjSpaceLightDir(float4(pos, 1));
#if defined(_SHADOWMODE_NONE)
    return 1;
#elif defined(_SHADOWMODE_HARD)
    TraceHit hit;
    Trace(pos, normalize(lightDir), _MaxDistance, hit);
    return (hit.missed) ? 1 : 0;
#elif defined(_SHADOWMODE_SOFT)
    return TraceSoftShadow(pos, normalize(lightDir), _MaxDistance);
#endif
}

UnityLight MainLight()
{
    UnityLight light;
    light.color = _LightColor0.rgb;
    light.dir = _WorldSpaceLightPos0.xyz;
    return light;
}

UnityLight AdditiveLight(half3 lightDir, half attenuation)
{
    UnityLight light;
    light.color = _LightColor0.rgb * attenuation;
    light.dir = lightDir;
#ifndef USING_DIRECTIONAL_LIGHT
    light.dir = normalize(light.dir);
#endif
    return light;
}

UnityIndirect EnvironmentIndirect(half3 normalWorld, half3 viewDir)
{
    half3 reflectionDir = reflect(-viewDir, normalWorld);

    Unity_GlossyEnvironmentData envData;
	envData.roughness = 1 - _Smoothness;
	envData.reflUVW = reflectionDir;
    
	UnityIndirect indirect;
	indirect.diffuse = max(0, ShadeSH9(half4(normalWorld, 1)));
	indirect.specular = Unity_GlossyEnvironment(
        UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData);
	return indirect;
}

UnityIndirect ZeroIndirect()
{
    UnityIndirect indirect;
    indirect.diffuse = 0;
    indirect.specular = 0;
    return indirect;
}

VertexOutput vert(VertexInput v)
{
    float4 pos = UnityObjectToClipPos(v.vertex);
    // NOTE: Ideally, the ray origin should correspond to a point in the near
    //       plane as opposed to the camera position so that depth can be
    //       computed accurately and orthographic projections work properly.
    float3 rayOrigin = ObjSpaceCameraPos();
    float3 rayDirection = v.vertex - rayOrigin;

    VertexOutput o;
    o.pos = pos;
    o.rayOrigin = rayOrigin;
    o.rayDirection = rayDirection;

    return o;
}

fixed4 fragBase(VertexOutput i, out float outDepth : SV_Depth) : SV_Target
{
    TraceHit hit;
    Trace(i.rayOrigin, normalize(i.rayDirection), _MaxDistance, hit);
    if (hit.missed) {
        discard;
    }

    float3 pos = hit.pos;
    float3 worldPos = mul(unity_ObjectToWorld, pos).xyz;

    float3 normal = Normal(hit.pos, hit.t);
    float3 normalWorld = UnityObjectToWorldNormal(normal);
    // TODO: Compute using i.rayDirection instead
    float3 viewDir = normalize(_WorldSpaceCameraPos - worldPos);

    float3 backoffPos = Backoff(hit.pos, normal, hit.t);
    float ambientOcclusion = AmbientOcclusion(backoffPos, normal);
    // TODO: Avoid computing shadows in case the main light is absent
    float shadow = Shadow(backoffPos);

    half3 albedo = _Tint;

    half3 specularTint;
    half oneMinusReflectivity;
    albedo = DiffuseAndSpecularFromMetallic(albedo, _Metallic, specularTint, oneMinusReflectivity);

    UnityLight light = MainLight();
    light.color *= shadow;

    UnityIndirect indirect = EnvironmentIndirect(normalWorld, viewDir);
    indirect.diffuse *= ambientOcclusion;
    indirect.specular *= ambientOcclusion;
    
    half4 color = UNITY_BRDF_PBS(albedo, specularTint, oneMinusReflectivity,
        _Smoothness, normalWorld, viewDir, light, indirect);

    outDepth = Depth(hit.pos);
    return color;
}

fixed4 fragAdd(VertexOutput i, out float outDepth : SV_Depth) : SV_Target
{
    TraceHit hit;
    Trace(i.rayOrigin, normalize(i.rayDirection), _MaxDistance, hit);
    if (hit.missed) {
        discard;
    }

    float3 pos = hit.pos;
    float3 worldPos = mul(unity_ObjectToWorld, pos).xyz;

    float3 normal = Normal(hit.pos, hit.t);
    float3 normalWorld = UnityObjectToWorldNormal(normal);
    float3 viewDir = normalize(_WorldSpaceCameraPos - worldPos);

    half3 albedo = _Tint;
    half3 specularTint;
    half oneMinusReflectivity;
    albedo = DiffuseAndSpecularFromMetallic(albedo, _Metallic, specularTint, oneMinusReflectivity);

    // NOTE: This variable can't be called 'shadow' because that name clashes
    //       with a variable defined internally by UNITY_LIGHT_ATTENUATION
    float shadow_  = Shadow(Backoff(hit.pos, normal, hit.t));

#ifdef USING_DIRECTIONAL_LIGHT
    half3 lightDir = _WorldSpaceLightPos0.xyz;
#else
    half3 lightDir = _WorldSpaceLightPos0.xyz - worldPos;
#endif
    UNITY_LIGHT_ATTENUATION(attenuation, 0, worldPos);
    UnityLight light = AdditiveLight(lightDir, attenuation);
    light.color *= shadow_;

    UnityIndirect indirect = ZeroIndirect();
    
    half4 color = UNITY_BRDF_PBS(albedo, specularTint, oneMinusReflectivity,
        _Smoothness, normalWorld, viewDir, light, indirect);

    outDepth = Depth(hit.pos);
    return color;
}

fixed4 fragShadowCaster(VertexOutput i, out float outDepth : SV_Depth) : SV_Target
{
    TraceHit hit;
    Trace(i.rayOrigin, normalize(i.rayDirection), _MaxDistance, hit);
    if (hit.missed) {
        discard;
    }

    outDepth = DepthWithBias(hit.pos, Normal(hit.pos, hit.t));
    return 0;
}

#endif