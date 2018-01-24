// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Shadow/Diffuse Shadow Map"
{
    Properties
    {
        _MainTex ("Main", 2D) = "white" {}
        _ShadowStrength ("Shadow Strength", Range(0, 1)) = 0.
        _PCFOffset ("PCF Offset", FLOAT) = 0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }

        CGPROGRAM
        #pragma surface surf Lambert vertex:vert

            // const float2 poissonDisk[4] =
            // {
            //     float2(-0.94201624, -0.39906216),
            //     float2(0.94558609, -0.76890725),
            //     float2(-0.094184101, -0.92938870),
            //     float2(0.34495938, 0.29387760)
            // };

            struct Input
            {
                float2 uv_MainTex : TEXCOORD0;
                float3 uA : TEXCOORD1;
            };

            sampler2D _MainTex;
            fixed _ShadowStrength;

            //Global values
            sampler2D _ShadowMap;
            float4 _CameraSettings;
            float4x4 _ShadowMapMat;
            float4x4 _ShadowMapMV;
            
            void vert (inout appdata_full v, out Input o)
            {
                UNITY_INITIALIZE_OUTPUT(Input, o);
                o.uA.xy = mul(_ShadowMapMat, mul(unity_ObjectToWorld, v.vertex));
                o.uA.z = -mul(_ShadowMapMV, mul(unity_ObjectToWorld, v.vertex)).z / _CameraSettings.x;
            }

            #define BLOCKER_SEARCH_NUM_SAMPLES 16
            #define PCF_NUM_SAMPLES 16
            #define NEAR_PLANE 9.5
            #define LIGHT_WORLD_SIZE 2.5
            #define LIGHT_FRUSTUM_WIDTH 3.75
            
            #define LIGHT_SIZE_UV (LIGHT_WORLD_SIZE / LIGHT_FRUSTUM_WIDTH)
            const float2 poissonDisk[16] = {
                    float2( -0.94201624, -0.39906216 ),
                    float2( 0.94558609, -0.76890725 ),
                    float2( -0.094184101, -0.92938870 ),
                    float2( 0.34495938, 0.29387760 ),
                    float2( -0.91588581, 0.45771432 ),
                    float2( -0.81544232, -0.87912464 ),
                    float2( -0.38277543, 0.27676845 ),
                    float2( 0.97484398, 0.75648379 ),
                    float2( 0.44323325, -0.97511554 ),
                    float2( 0.53742981, -0.47373420 ),
                    float2( -0.26496911, -0.41893023 ),
                    float2( 0.79197514, 0.19090188 ),
                    float2( -0.24188840, 0.99706507 ),
                    float2( -0.81409955, 0.91437590 ),
                    float2( 0.19984126, 0.78641367 ),
                    float2( 0.14383161, -0.14100790 )
            };

            float PenumbraSize(float zReceiver, float zBlocker) //Parallel plane estimation 
            {
                return (zReceiver - zBlocker) / zBlocker;
            }

            void FindBlocker(out float avgBlockerDepth, out float numBlockers, float2 uv, float zReceiver)
            {
                //This uses similar triangles to compute what
                //area of the shadow map we should search
                float searchWidth = LIGHT_SIZE_UV * (zReceiver - NEAR_PLANE) / zReceiver;
                float blockerSum = 0;
                numBlockers = 0;

                for( int i = 0; i < BLOCKER_SEARCH_NUM_SAMPLES; ++i )
                {
                    float shadowMapDepth = tex2D(_ShadowMap, uv + poissonDisk[i] * searchWidth).r;
                    
                    if ( shadowMapDepth < zReceiver ) 
                    {
                        blockerSum += shadowMapDepth;
                        numBlockers++;
                    }
                    
                    avgBlockerDepth = blockerSum / numBlockers;
                }
            }

            float PCF_Filter( float2 uv, float zReceiver, float filterRadiusUV )
            {
                float sum = 0.0f;

                 sum += step(zReceiver, tex2D(_ShadowMap, uv + filterRadiusUV * float2(0.001, 0.001)).r); 
                  sum += step(zReceiver, tex2D(_ShadowMap, uv + filterRadiusUV * float2(0.001, -0.001)).r); 
                  sum += step(zReceiver, tex2D(_ShadowMap, uv + filterRadiusUV * float2(-0.001, -0.001)).r); 
                  sum += step(zReceiver, tex2D(_ShadowMap, uv + filterRadiusUV * float2(-0.001, 0.001)).r); 

                return sum /= 4;

                for ( int i = 0; i < PCF_NUM_SAMPLES; i++)
                {
                    float2 offset = poissonDisk[i] * filterRadiusUV;
                    sum += step(zReceiver, tex2D(_ShadowMap, uv + offset).r); 
                }
                return sum / PCF_NUM_SAMPLES;
            }

            float PCSS (float3 coords)
            {
                float2 uv = coords.xy;
                float zReceiver = coords.z; // Assumed to be eye-space z in this code

                // STEP 1: blocker search
                float avgBlockerDepth = 0;
                float numBlockers = 0;
                FindBlocker( avgBlockerDepth, numBlockers, uv, zReceiver );

                if( numBlockers < 1 ) //There are no occluders so early out (this saves filtering)
                {
                    return 1.0f;
                }

                // STEP 2: penumbra size
                float penumbraRatio = PenumbraSize(zReceiver, avgBlockerDepth);
                float filterRadiusUV = penumbraRatio * LIGHT_SIZE_UV * NEAR_PLANE / coords.z;

                // STEP 3: filtering
                return PCF_Filter( uv, zReceiver, filterRadiusUV);

            }

            //VSM
            float chebyshevUpperBound(float distance, float2 uv)
            {
                // We retrive the two moments previously stored (depth and depth*depth)
                float2 moments = tex2D(_ShadowMap, uv).rg;
                
                // Surface is fully lit. as the current fragment is before the light occluder
                if (distance <= moments.x)
                    return 1.0 ;
            
                // The fragment is either in shadow or penumbra. We now use chebyshev's upperBound to check
                // How likely this pixel is to be lit (p_max)
                float variance = moments.y - (moments.x*moments.x);
                variance = max(variance,0.000002);
            
                float d = distance - moments.x;
                float p_max = variance / (variance + d*d);
            
                return p_max;
            }

            void surf (Input IN, inout SurfaceOutput o)
            {
                fixed4 col = tex2D(_MainTex, IN.uv_MainTex);
                
                // fixed shadow = step(IN.uA.z, tex2D(_ShadowMap, IN.uA.xy).r);
                // fixed shadow = chebyshevUpperBound(IN.uA.z * 0.5 + 0.5, IN.uA.xy);
                fixed shadow = PCSS(IN.uA);

                // fixed shadow = PCF_Filter(IN.uA.xy, IN.uA.z, 0.01);

                // shadow /= 2;


                // o.Albedo = lerp(col.rgb, col.rgb * shadow, _ShadowStrength);
                // o.Albedo = tex2D(_ShadowMap, IN.uA.xy).rgb;
                o.Emission = shadow;
                  
                o.Alpha = col.a;
            }
        ENDCG
    }
}
