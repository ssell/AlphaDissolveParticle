#ifndef VF_INCLUDE_FORWARD_LIGHTING
#define VF_INCLUDE_FORWARD_LIGHTING

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

// For shadows, don't forget:
// #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN

/**
 * Sums all lighting for a forward rendered surface using the provided main light source.
 * See: https://blog.unity.com/technology/custom-lighting-in-shader-graph-expanding-your-graphs-in-2019
 */
void GetForwardLighting(
    in Light mainLight,
    float3 positionWS, 
    float3 normalWS, 
    float3 viewDirectionWS, 
    float smoothness,
    inout float3 totalDiffuse, 
    inout float3 totalSpecular)
{
    float3 mainLightColor = mainLight.color * mainLight.distanceAttenuation * mainLight.shadowAttenuation;
    float specularPower = smoothness * 0.03125f;//exp2(10.0f * smoothness + 1.0f);

    float3 diffuseLight = LightingLambert(mainLightColor, mainLight.direction, normalWS);
    float3 specularLight = (float3)0;//LightingSpecular(mainLightColor, mainLight.direction, normalWS, viewDirectionWS, float4(_SpecularColor, 0.0f), smoothness);

    int otherLightsCount = GetAdditionalLightsCount();

    for (int i = 0; i < otherLightsCount; ++i)
    {
        Light light = GetAdditionalLight(i, positionWS);
        float3 lightColor = light.color * light.distanceAttenuation * light.shadowAttenuation;

        diffuseLight += LightingLambert(lightColor, light.direction, normalWS);
        specularLight += LightingSpecular(lightColor, light.direction, normalWS, viewDirectionWS, float4(light.color.rgb, 0.0f), smoothness) * specularPower;
    }

    float3 ambientLight = float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);

    totalDiffuse = saturate(diffuseLight + ambientLight);
    totalSpecular = mainLight.shadowAttenuation.rrr;//specularLight;
}

/**
 * Fetches the main light source and outputs the sum of all lighting for the forward rendered surface.
 * See: https://blog.unity.com/technology/custom-lighting-in-shader-graph-expanding-your-graphs-in-2019
 */
void GetForwardLighting(
    float3 positionWS, 
    float3 normalWS, 
    float3 viewDirectionWS, 
    float smoothness,
    inout float3 totalDiffuse, 
    inout float3 totalSpecular)
{
    Light mainLight = GetMainLight(TransformWorldToShadowCoord(positionWS), positionWS, 1.0f);
    GetForwardLighting(mainLight, positionWS, normalWS, viewDirectionWS, smoothness, totalDiffuse, totalSpecular);
}

#endif