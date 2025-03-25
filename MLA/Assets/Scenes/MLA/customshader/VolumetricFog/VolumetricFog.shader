Shader "Tutorial/VolumetricFog2D"
{
    Properties
    {
        _Color("Color", Color) = (1, 1, 1, 1)
        _MaxDistance("Max distance", float) = 100
        _StepSize("Step size", Range(0.1, 20)) = 1
        _DensityMultiplier("Density multiplier", Range(0, 10)) = 1
        _NoiseOffset("Noise offset", float) = 0
        _MaxIterations("Max Iterations", Range(1, 256)) = 256 // 添加最大迭代次数
        
        _FogNoise("Fog noise", 2D) = "white" {}
        _NoiseTiling("Noise tiling", float) = 1
        _DensityThreshold("Density threshold", Range(0, 1)) = 0.1
        _NoiseScrollSpeed("Noise Scroll Speed", Vector) = (0.1, 0.1, 0, 0)
        _HeightFalloff("Height Falloff", Range(0, 1)) = 0.2
        
        [HDR]_LightContribution("Light contribution", Color) = (1, 1, 1, 1)
        _LightScattering("Light scattering", Range(0, 1)) = 0.2
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            float4 _Color;
            float _MaxDistance;
            float _DensityMultiplier;
            float _StepSize;
            float _NoiseOffset;
            int _MaxIterations; // 添加最大迭代次数
            TEXTURE2D(_FogNoise);
            SAMPLER(sampler_FogNoise);
            float _DensityThreshold;
            float _NoiseTiling;
            float4 _LightContribution;
            float _LightScattering;
            float4 _NoiseScrollSpeed;
            float _HeightFalloff;

            float henyey_greenstein(float angle, float scattering)
            {
                return (1.0 - angle * angle) / (4.0 * PI * pow(1.0 + scattering * scattering - (2.0 * scattering) * angle, 1.5f));
            }
            
            float get_density(float3 worldPos)
            {
                // 使用两个不同平面的2D采样来模拟3D效果
                float2 texCoordXY = worldPos.xy * 0.01 * _NoiseTiling + _Time.xx * _NoiseScrollSpeed.xy;
                float2 texCoordXZ = worldPos.xz * 0.01 * _NoiseTiling + _Time.xx * _NoiseScrollSpeed.xz * 0.7;
                
                float4 noiseXY = SAMPLE_TEXTURE2D(_FogNoise, sampler_FogNoise, texCoordXY);
                float4 noiseXZ = SAMPLE_TEXTURE2D(_FogNoise, sampler_FogNoise, texCoordXZ);
                
                // 混合两个平面的噪声
                float4 noise = lerp(noiseXY, noiseXZ, 0.5);
                
                // 添加高度衰减
                float heightFactor = saturate(1.0 - abs(worldPos.y) * _HeightFalloff);
                
                float density = dot(noise, noise)*heightFactor;
                density = saturate(density - _DensityThreshold) * _DensityMultiplier;
                return density;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float4 col = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, IN.texcoord);
                float depth = SampleSceneDepth(IN.texcoord);
                float3 worldPos = ComputeWorldSpacePosition(IN.texcoord, depth, UNITY_MATRIX_I_VP);

                float3 entryPoint = _WorldSpaceCameraPos;
                float3 viewDir = worldPos - _WorldSpaceCameraPos;
                float viewLength = length(viewDir);
                float3 rayDir = normalize(viewDir);

                float2 pixelCoords = IN.texcoord * _BlitTextureSize.xy;
                float distLimit = min(viewLength, _MaxDistance);
                float distTravelled = InterleavedGradientNoise(pixelCoords, (int)(_Time.y / max(HALF_EPS, unity_DeltaTime.x))) * _NoiseOffset;
                float transmittance = 1;
                float4 fogCol = _Color;

                // 限制循环最大迭代次数
                [loop]
                for(int i = 0; i < _MaxIterations && distTravelled < distLimit; i++)
                {
                    float3 rayPos = entryPoint + rayDir * distTravelled;
                    float density = get_density(rayPos);
                    if (density > 0)
                    {
                        Light mainLight = GetMainLight(TransformWorldToShadowCoord(rayPos));
                        fogCol.rgb += mainLight.color.rgb * _LightContribution.rgb * henyey_greenstein(dot(rayDir, mainLight.direction), _LightScattering) * density * mainLight.shadowAttenuation * _StepSize;
                        transmittance *= exp(-density * _StepSize);
                    }
                    distTravelled += _StepSize;
                }
                
                return lerp(col, fogCol, 1.0 - saturate(transmittance));
            }
            ENDHLSL
        }
    }
}