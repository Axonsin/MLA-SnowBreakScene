Shader "Custom/CartoonFaceShader"
{
    Properties
    {
        _BaseMap ("Base Map", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _FaceShadingGradeMap ("Face Shadow Map", 2D) = "white" {}
        _Compensationcolor("最弱环境光阴影补偿色",Color) = (1,1,1,1)
        
        [Header(Face Settings)]
        _FaceShadingOffset ("Face Shading Offset", Range(-1, 1)) = 0
        _FaceShadingSoftness ("Face Shading Softness", Range(0, 1)) = 0.1
        _FaceGradient ("Face Gradient Intensity", Range(0, 1)) = 0.5
        _FaceGradientColor ("Face Gradient Color", Color) = (1, 0.8, 0.8, 1)
        _FaceGradientOffset ("Face Gradient Offset", Range(-1, 1)) = 0
        _FaceLocalHeightBound ("Face Local Height Bound (X:Scale, Y:Offset)", Vector) = (1, 0, 0, 0)
        
        _CharacterForward ("Character Forward", Vector) = (0, 0, -1, 0)
        _CharacterUp ("Character Up", Vector) = (0, 1, 0, 0)
    }
    
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float4 tangentWS : TEXCOORD3;
                float3 bitangentWS : TEXCOORD4;
                float3 viewDirWS : TEXCOORD5;
                float3 positionLS : TEXCOORD6; // Local space position for face height
            };
            
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);
            TEXTURE2D(_FaceShadingGradeMap);
            SAMPLER(sampler_FaceShadingGradeMap);
            
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float _BumpScale;
                float _FaceShadingOffset;
                float _FaceShadingSoftness;
                float _FaceGradient;
                float4 _FaceGradientColor;
                float _FaceGradientPow;
                float _FaceGradientOffset;
                float4 _FaceLocalHeightBound;
                float4 _CharacterForward;
                float4 _CharacterUp;
                float4 _Compensationcolor;
            CBUFFER_END
            
            Varyings vert(Attributes input)
            {
                Varyings output;
                
                // Transform positions
                VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = positionInputs.positionCS;
                output.positionWS = positionInputs.positionWS;
                output.positionLS = input.positionOS.xyz;
                
                // Transform normals and tangents
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.normalWS = normalInputs.normalWS;
                output.tangentWS = float4(normalInputs.tangentWS, input.tangentOS.w);
                output.bitangentWS = normalInputs.bitangentWS;
                
                // View direction
                output.viewDirWS = GetWorldSpaceViewDir(positionInputs.positionWS);
                
                // UVs
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                
                return output;
            }
            
            half4 frag(Varyings input) : SV_Target
            {
                // Sample base color and normal map
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half4 baseColor = baseMap * _BaseColor;
                
                // Sample face shadow mask R代表sdf，G代表蒙版
                half4 faceShadowMapL = SAMPLE_TEXTURE2D(_FaceShadingGradeMap, sampler_FaceShadingGradeMap, input.uv);
                
                // Setup normal mapping
                half3 normalMap = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv));
                normalMap.xy *= _BumpScale;
                
                // Construct TBN matrix
                float3 normalWS = normalize(input.normalWS);
                float3 tangentWS = normalize(input.tangentWS.xyz);
                float3 bitangentWS = normalize(input.bitangentWS);
                float3x3 tangentToWorld = float3x3(tangentWS, bitangentWS, normalWS);
                
                // Transform normal from tangent to world space
                float3 N = TransformTangentToWorld(normalMap, tangentToWorld, true);
                
                // Get main light direction
                Light mainLight = GetMainLight();
                float3 L = mainLight.direction;
                
                // Character orientation vectors
                float3 Front = normalize(_CharacterForward.xyz);
                float3 UP = normalize(_CharacterUp.xyz);
                float3 Left = normalize(cross(UP, Front));
                float3 Right = -Left;
                
                // Flatten vectors to xz plane for 2D face shadow calculation
                float3 FrontXZ = normalize(float3(Front.x, 0, Front.z));
                float3 LeftXZ = normalize(float3(Left.x, 0, Left.z));
                float3 RightXZ = normalize(float3(Right.x, 0, Right.z));
                float3 LightXZ = normalize(float3(L.x, 0, L.z));
                
                // Calculate dot products for face shading
                float FrontL = dot(FrontXZ, LightXZ);
                float LeftL = dot(LeftXZ, LightXZ);
                float RightL = dot(RightXZ, LightXZ);
                
                // Shadow map value (typically stored in red channel)
                float shadowMapValueL = 1-faceShadowMapL.r;
                float shadowMapMask = faceShadowMapL.g;
                
                // Calculate face shadow
                // If light comes from behind (FrontL < 0), apply full shadow
                // Otherwise check left and right sides with lightmap value
                float leftCheck = (shadowMapValueL > LeftL) ? 1.0 : 0.0;
                float rightCheck = (1.0 - shadowMapValueL < RightL) ? 0.0 : 1.0;
                
                // Final shadow attenuation - only apply if light is in front
                float lightAttenuation = (FrontL > 0) ? min(leftCheck, rightCheck) : 0.0;
                
               // Apply softness to shadow edge if needed
                float softShadow = lightAttenuation;
                if (_FaceShadingSoftness > 0) {
                    // 确定光源主要来自哪一侧
                    bool lightFromLeft = LeftL > RightL;
                    
                    // 根据光源位置选择正确的软化计算方式
                    float softEdge;
                    if (lightFromLeft) {
                        // 光源从左侧照射，使用左侧柔和过渡
                        softEdge = (shadowMapValueL - LeftL + _FaceShadingOffset) / max(0.0001, _FaceShadingSoftness);
                    } else {
                        //更新并反转uv 采样反方向的阴影图
                        half4 faceShadowMapR = SAMPLE_TEXTURE2D(_FaceShadingGradeMap, sampler_FaceShadingGradeMap, float2((1-input.uv.x),input.uv.y));
                        float shadowMapValueR = 1-faceShadowMapR.r;
                        // 光源从右侧照射，使用右侧柔和过渡
                        softEdge = ( shadowMapValueR - RightL + _FaceShadingOffset) / max(0.0001, _FaceShadingSoftness);
                    }
                    //乘以蒙版
                    softEdge = saturate(softEdge)*shadowMapMask;
                    softEdge = softEdge * softEdge * (3.0 - 2.0 * softEdge); // Smoothstep
                    
                    // 只在光线从前方照射时应用软化
                    softShadow = (FrontL > 0) ? softEdge : 0.0;
                }
                
                // Apply face height gradient
                // float localHeight = input.positionLS.y * _FaceLocalHeightBound.x + _FaceLocalHeightBound.y;
                // half gradientFactor = saturate(pow(saturate((_FaceGradientOffset - localHeight) / _FaceGradientPow), 1.0 / _FaceGradientPow));
                // gradientFactor = gradientFactor * gradientFactor * (3.0 - 2.0 * gradientFactor); // Smoothstep
                // gradientFactor = gradientFactor * _FaceGradient;
                
                // 最后加在一起
                half3 ambientLight = _Compensationcolor.rgb; // 使用补偿色调整环境光
                half3 directLighting = baseColor.rgb * mainLight.color * softShadow;
                half3 ambientLighting = baseColor.rgb * ambientLight;
                half3 shadedColor = max(directLighting, ambientLighting);
                // half3 shadedColor = ambientLighting + directLighting;
                
                half3 finalColor = lerp(shadedColor, _FaceGradientColor.rgb, 0.5);
                
                return half4(finalColor, baseColor.a);
            }
            ENDHLSL
        }
    }
}