Shader "Shadow/Diffuse Shadow Map"
{
    Properties
    {
        _MainTex ("Main", 2D) = "white" {}
        _NoiseTex ("Noise Tex", 2D) = "black" {}
        _ShadowStrength ("Shadow Strength", Range(0, 1)) = 1
        _PCFOffset ("PCF Offset", FLOAT) = 0
        _LightSize ("Light Size", FLOAT) = 1.1
        _NearPlane ("Near Plane", FLOAT) = 9.5
        _NormalBias ("Normal Bias", FLOAT) = 0.05
        _VSMBound ("VSM Upper Bound", FLOAT) = 0.000002
        [KeywordEnum(NONE, STANDARD, VSM, PCF, PCSS)] _ShadowMode ("Shadow Mode", FLOAT) = 1
        [Toggle(_STRATIFIED)] _Stratified ("Stratified Sampling", FLOAT) = 1
        [Toggle(_ALPHATEST)] _ALPHATEST ("Alpha Test", FLOAT) = 1
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }

        CGPROGRAM
        #pragma surface surf Lambert vertex:vert noshadow
        #pragma target 3.0
        #pragma multi_compile _SHADOWMODE_STANDARD _SHADOWMODE_VSM _SHADOWMODE_PCF _SHADOWMODE_PCSS
        #pragma multi_compile _ _STRATIFIED
        #pragma multi_compile _ _ALPHATEST

        #define BLOCKER_SEARCH_NUM_SAMPLES 16
        #define PCF_NUM_SAMPLES 16
        #define NEAR_PLANE 9.5
        #define LIGHT_WORLD_SIZE 4.5
        #define LIGHT_FRUSTUM_WIDTH 3.75
        #define LIGHT_SIZE_UV (LIGHT_WORLD_SIZE / LIGHT_FRUSTUM_WIDTH)

        struct Input
        {
            float2 uv_MainTex : TEXCOORD0;
            float3 uA : TEXCOORD1;
            float4 screenPos;
            float3 worldPos;
        };

        sampler2D _MainTex;
        fixed _ShadowStrength;

        float _PCFOffset;

        //Global values
        sampler2D _ShadowMap;
        float4 _CameraSettings;
        float4x4 _ShadowMapMat;
        float4x4 _ShadowMapMV;
        float _NormalBias;
        
        void vert (inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);
            o.uA.xy = mul(_ShadowMapMat, mul(unity_ObjectToWorld, v.vertex + float4(v.normal.xyz * _NormalBias, 0)));
            o.uA.z = -mul(_ShadowMapMV, mul(unity_ObjectToWorld, v.vertex)).z / _CameraSettings.x;
        }

        float PenumbraSize(float zReceiver, float zBlocker) //Parallel plane estimation 
        {
            return (zReceiver - zBlocker) / zBlocker;
        }

        float _LightSize;
        float _NearPlane;

        void FindBlocker(out float avgBlockerDepth, out float numBlockers, float2 uv, float zReceiver, float3 screenPos)
        {
            const float2 poissonDisk[16] = {
                float2(-0.613392, 0.617481),
                float2(0.170019, -0.040254),
                float2(-0.299417, 0.791925),
                float2(0.645680, 0.493210),

                float2(-0.651784, 0.717887),
                float2(0.421003, 0.027070),
                float2(-0.817194, -0.271096),
                float2(-0.705374, -0.668203),

                float2(0.977050, -0.108615),
                float2(0.063326, 0.142369),
                float2(0.203528, 0.214331),
                float2(-0.667531, 0.326090),

                float2(-0.098422, -0.295755),
                float2(-0.885922, 0.215369),
                float2(0.566637, 0.605213),
                float2(0.039766, -0.396100)

                // float2(0.751946, 0.453352),
                // float2(0.078707, -0.715323),
                // float2(-0.075838, -0.529344),
                // float2(0.724479, -0.580798),

                // float2(0.222999, -0.215125),
                // float2(-0.467574, -0.405438),
                // float2(-0.248268, -0.814753),
                // float2(0.354411, -0.887570),

                // float2(0.175817, 0.382366),
                // float2(0.487472, -0.063082),
                // float2(-0.084078, 0.898312),
                // float2(0.488876, -0.783441),

                // float2(0.470016, 0.217933),
                // float2(-0.696890, -0.549791),
                // float2(-0.149693, 0.605762),
                // float2(0.034211, 0.979980)

                // float2(0.503098, -0.308878),
                // float2(-0.016205, -0.872921),
                // float2(0.385784, -0.393902),
                // float2(-0.146886, -0.859249),
                // float2(0.643361, 0.164098),
                // float2(0.634388, -0.049471),
                // float2(-0.688894, 0.007843),
                // float2(0.464034, -0.188818),
                // float2(-0.440840, 0.137486),
                // float2(0.364483, 0.511704),
                // float2(0.034028, 0.325968),
                // float2(0.099094, -0.308023),
                // float2(0.693960, -0.366253),
                // float2(0.678884, -0.204688),
                // float2(0.001801, 0.780328),
                // float2(0.145177, -0.898984),
                // float2(0.062655, -0.611866),
                // float2(0.315226, -0.604297),
                // float2(-0.780145, 0.486251),
                // float2(-0.371868, 0.882138),
                // float2(0.200476, 0.494430),
                // float2(-0.494552, -0.711051),
                // float2(0.612476, 0.705252),
                // float2(-0.578845, -0.768792),
                // float2(-0.772454, -0.090976),
                // float2(0.504440, 0.372295),
                // float2(0.155736, 0.065157),
                // float2(0.391522, 0.849605),
                // float2(-0.620106, -0.328104),
                // float2(0.789239, -0.419965),
                // float2(-0.545396, 0.538133),
                // float2(-0.178564, -0.596057)
            };

            //This uses similar triangles to compute what
            //area of the shadow map we should search
            float searchWidth = _LightSize * (zReceiver - _NearPlane) / zReceiver * 0.01;
            float blockerSum = 0;
            numBlockers = 0;

            for( int i = 0; i < BLOCKER_SEARCH_NUM_SAMPLES; ++i )
            {
                float2 disk = poissonDisk[i];
                float shadowMapDepth = tex2D(_ShadowMap, uv + disk * searchWidth).r;
                if ( shadowMapDepth < zReceiver ) 
                {
                    blockerSum += shadowMapDepth;
                    numBlockers++;
                }
            }
            avgBlockerDepth = blockerSum / numBlockers;
        }

        sampler2D _NoiseTex;

        float PCF_Filter( float2 uv, float zReceiver, float filterSize , float3 screenPos)
        {
            const float2 poissonDisk[16] = {
                float2(-0.613392, 0.617481),
                float2(0.170019, -0.040254),
                float2(-0.299417, 0.791925),
                float2(0.645680, 0.493210),

                float2(-0.651784, 0.717887),
                float2(0.421003, 0.027070),
                float2(-0.817194, -0.271096),
                float2(-0.705374, -0.668203),

                float2(0.977050, -0.108615),
                float2(0.063326, 0.142369),
                float2(0.203528, 0.214331),
                float2(-0.667531, 0.326090),

                float2(-0.098422, -0.295755),
                float2(-0.885922, 0.215369),
                float2(0.566637, 0.605213),
                float2(0.039766, -0.396100)

                // float2(0.751946, 0.453352),
                // float2(0.078707, -0.715323),
                // float2(-0.075838, -0.529344),
                // float2(0.724479, -0.580798),
                // float2(0.222999, -0.215125),
                // float2(-0.467574, -0.405438),
                // float2(-0.248268, -0.814753),
                // float2(0.354411, -0.887570),
                // float2(0.175817, 0.382366),
                // float2(0.487472, -0.063082),
                // float2(-0.084078, 0.898312),
                // float2(0.488876, -0.783441),
                // float2(0.470016, 0.217933),
                // float2(-0.696890, -0.549791),
                // float2(-0.149693, 0.605762),
                // float2(0.034211, 0.979980),
                // float2(0.503098, -0.308878),
                // float2(-0.016205, -0.872921),
                // float2(0.385784, -0.393902),
                // float2(-0.146886, -0.859249),
                // float2(0.643361, 0.164098),
                // float2(0.634388, -0.049471),
                // float2(-0.688894, 0.007843),
                // float2(0.464034, -0.188818),
                // float2(-0.440840, 0.137486),
                // float2(0.364483, 0.511704),
                // float2(0.034028, 0.325968),
                // float2(0.099094, -0.308023),
                // float2(0.693960, -0.366253),
                // float2(0.678884, -0.204688),
                // float2(0.001801, 0.780328),
                // float2(0.145177, -0.898984),
                // float2(0.062655, -0.611866),
                // float2(0.315226, -0.604297),
                // float2(-0.780145, 0.486251),
                // float2(-0.371868, 0.882138),
                // float2(0.200476, 0.494430),
                // float2(-0.494552, -0.711051),
                // float2(0.612476, 0.705252),
                // float2(-0.578845, -0.768792),
                // float2(-0.772454, -0.090976),
                // float2(0.504440, 0.372295),
                // float2(0.155736, 0.065157),
                // float2(0.391522, 0.849605),
                // float2(-0.620106, -0.328104),
                // float2(0.789239, -0.419965),
                // float2(-0.545396, 0.538133),
                // float2(-0.178564, -0.596057)
            };

            float totalShadow = 0;
            for ( int i = 0; i < PCF_NUM_SAMPLES; i++)
            {
                #if _STRATIFIED
                
                float dot_product = dot(float4(screenPos, i), float4(12.9898, 78.233, 45.164, 94.673));
                float random = frac(sin(dot_product) * 43758.5453);
                int index = int(16.0 * random) % 16;
                float2 uvOffset = poissonDisk[index] * filterSize;

                uvOffset = tex2D(_NoiseTex, float2(screenPos.xy + float2(i/64.0, 0))).r - 0.5;
                uvOffset *= 2;

                uvOffset *= filterSize;


                #else
                float2 uvOffset = poissonDisk[i] * filterSize;
                #endif

                totalShadow += step(zReceiver, tex2D(_ShadowMap, uv + uvOffset).r); 
            }
            return totalShadow / PCF_NUM_SAMPLES;
        }

        float PCSS (float3 coords, float3 screenPos)
        {
            float2 uv = coords.xy;
            float zReceiver = coords.z; // Assumed to be eye-space z in this code

            // STEP 1: blocker search
            float avgBlockerDepth = 0;
            float numBlockers = 0;
            FindBlocker( avgBlockerDepth, numBlockers, uv, zReceiver, screenPos);

            if (numBlockers < 1) //There are no occluders so early out (this saves filtering)
            {
                return 1.0f;
            }

            // STEP 2: penumbra size
            float penumbraRatio = PenumbraSize(zReceiver, avgBlockerDepth);
            float filterRadiusUV = penumbraRatio * _LightSize * _NearPlane / coords.z;

            // STEP 3: filtering
            return PCF_Filter( uv, zReceiver, filterRadiusUV * 0.01 * _PCFOffset, screenPos);
        }

        float _VSMBound;
        float VSM(float distance, float2 uv)
        {
            // We retrive the two moments previously stored (depth and depth*depth)
            float2 moments = tex2D(_ShadowMap, uv).rg;
            
            // Surface is fully lit. as the current fragment is before the light occluder
            if (distance <= moments.x)
                return 1.0;
        
            // The fragment is either in shadow or penumbra. We now use chebyshev's upperBound to check
            // How likely this pixel is to be lit (p_max)
            float variance = moments.y - (moments.x * moments.x);
            variance = max(variance, _VSMBound);
        
            float d = distance - moments.x;
            float p_max = variance / (variance + d*d);

            // Choose one of these, smoothstep has better quality
            // Darkening using linear step
            // p_max = clamp((p_max - 0.3) / (1.0 - 0.3), 0.0, 1.0);

            // Darkening using smooth step
            p_max = smoothstep(0.2, 1.0, p_max);
        
            return p_max;
        }

        void surf (Input IN, inout SurfaceOutput o)
        {
            fixed4 col = tex2D(_MainTex, IN.uv_MainTex);

            float3 screenPos = IN.screenPos.xyy / IN.screenPos.w;
            screenPos *= 10;

            

            #if _SHADOWMODE_STANDARD
            fixed shadow = step(IN.uA.z, tex2D(_ShadowMap, IN.uA.xy).r);
            #elif _SHADOWMODE_VSM
            fixed shadow = VSM(IN.uA.z * 0.5 + 0.5, IN.uA.xy);
            #elif _SHADOWMODE_PCF
            fixed shadow = PCF_Filter(IN.uA.xy, IN.uA.z, _PCFOffset * 0.01, screenPos);
            #elif _SHADOWMODE_PCSS
            fixed shadow = PCSS(IN.uA, screenPos);
            #else
            fixed shadow = 1;
            #endif

#if _ALPHATEST
            clip(col.a - 0.1);
#endif

            o.Albedo = lerp(col.rgb, col.rgb * shadow, _ShadowStrength);
            o.Alpha = col.a;
        }
        ENDCG
    }
}
