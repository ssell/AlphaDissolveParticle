Shader "VertexFragment/AlphaDissolveParticle"
{
    Properties
    {
        [Header(Particle)]
        _ParticleTexture ("Particle Texture", 2D) = "white" {}
        _AlphaConstant ("Alpha Constant", Range(0, 1)) = 0.8
        [HDR] _Tint ("Tint", Color) = (1, 1, 1, 1)
        _HighlightStrength ("Highlight Strength", Range(0, 1)) = 0.25
        _HighlightFade ("Highlight Fade", Range(0, 1)) = 0.5

        [Header(Warp)]
        _FlowTexture ("Flow Texture", 2D) = "black" {}
        _FlowTile ("Flow Tiling", Float) = 1.0
        _FlowStrength ("Flow Strength", Range(0.0, 1.0)) = 0.1
        
        [Header(Dissolve)]
        _DissolveRate ("Dissolve Rate", Float) = 1.0
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "LightMode" = "UniversalForwardOnly"
        }

        Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
        ZWrite On
        Cull Back

        Pass
        {
            Name "Unlit"

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Common.hlsl"
            #include "ForwardLighting.hlsl"

            #pragma vertex VertMain
            #pragma fragment FragMain

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            
            CBUFFER_START(UnityPerMaterial)
                TEXTURE2D(_ParticleTexture);
                SAMPLER(sampler_ParticleTexture);

                TEXTURE2D(_FlowTexture);
                SAMPLER(sampler_FlowTexture);

                float _AlphaConstant;
                float _HighlightStrength;
                float _HighlightFade;
                float4 _Tint;

                float _FlowTile;
                float _FlowStrength;
                float _DissolveRate;
            CBUFFER_END

            // -----------------------------------------------------------------------------
            // Vertex
            // -----------------------------------------------------------------------------

            /**
             * Vertex input from a particle renderer supplying custom vertex streams.
             * Note the exact order of vertex data (age percent, etc.) is dependent on how the streams are configured.
             */
            struct ParticleVertInput
            {
                float4 position    : POSITION;
                float3 normal      : NORMAL;
                float4 color       : COLOR;
                float4 uvData      : TEXCOORD0;         // (uv.u, uv.v, age percent, random value)
            };

            struct VertOutput
            {
                float4 position    : SV_POSITION;
                float2 uv          : TEXCOORD0;
                float4 tex1        : TEXCOORD1;
                float4 tex2        : TEXCOORD2;
                float3 positionWS  : TEXCOORD6;
            };

            VertOutput VertMain(ParticleVertInput input)
            {
                VertOutput output = (VertOutput)0;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.position.xyz);

                float age01 = input.uvData.z;
                float rand01 = input.uvData.w;

                float spriteU = step(rand01, 0.5f) * 0.5f;
                float spriteV = step(Hash11(rand01), 0.5f) * 0.5f;
                
                output.position = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;
                output.uv = input.uvData.xy;
                output.tex1 = float4(spriteU, spriteV, age01, rand01);
                output.tex2 = input.color;

                return output;
            }
            
            // -----------------------------------------------------------------------------
            // Fragment
            // -----------------------------------------------------------------------------

            float2 WarpUV(float2 uv, float2 spriteOrigin, float2 flowDir, float flowStrength)
            {
                float2 warped = saturate(uv + (flowDir * flowStrength));
                float2 spriteUV = spriteOrigin.xy + (warped.xy * 0.5f);
                return spriteUV;
            }

            float4 FragMain(VertOutput input) : SV_Target
            {
                float rand01 = input.tex1.w;
                float time01 = EaseInQuadratic(input.tex1.z);
                float4 tint = input.tex2;

                float2 toCenter = input.uv - float2(0.5f, 0.5f);
                float distToCenter = length(toCenter);
                float flowModifier = EaseInCubic(saturate(1.0f - distToCenter));

                // -------------------------------------------------------------------------
                // Flow / Twist Distortion
                // -------------------------------------------------------------------------

                float2 flowUV = RotateUV(input.uv * _FlowTile, float2(0.5f, 0.5f), _Time.y + rand01);
                float2 flowDir = SAMPLE_TEXTURE2D(_FlowTexture, sampler_FlowTexture, flowUV).rg * 2.0f - 1.0f;
                float flowStrength = _FlowStrength * time01 * flowModifier * flowModifier;

                float2 particleUV = WarpUV(input.uv, input.tex1.xy, flowDir, flowStrength);
                float4 particle = SAMPLE_TEXTURE2D(_ParticleTexture, sampler_ParticleTexture, particleUV);

                float particleLighting = particle.r;
                float particleRimLighting = particle.g;
                float particleDissolve = particle.b;
                float particleMask = particle.a;

                // -------------------------------------------------------------------------
                // Dissolve
                // -------------------------------------------------------------------------

                float dissolve = step(time01 * _DissolveRate, 1.0f - particleDissolve);
                float alpha = particleMask * _AlphaConstant * dissolve * (1.0f - time01);

                // -------------------------------------------------------------------------
                // Lighting
                // -------------------------------------------------------------------------

                float3 positionWS = input.positionWS;
                float3 viewVectorWS = GetCurrentViewPosition() - positionWS;
                float3 viewDirectionWS = normalize(viewVectorWS);
                float3 normalWS = float3(0.0f, 1.0f, 0.0f);

                float3 diffuseLight = (float3)0;
                float3 specularLight = (float3)0;

                GetForwardLighting(positionWS, normalWS, viewDirectionWS, 1.0f, diffuseLight, specularLight);

                // -------------------------------------------------------------------------
                // Final Color
                // -------------------------------------------------------------------------

                float highlightModifier = smoothstep(0.0, _HighlightFade, time01);
                float4 color = float4(lerp(tint.rgb * (1.0f - _HighlightStrength), tint.rgb, particleLighting * highlightModifier) * _Tint.rgb * diffuseLight, alpha * tint.a);
                
                return color;
            }

            ENDHLSL
        }
    }
}