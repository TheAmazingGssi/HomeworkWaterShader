// ShaderLab/HLSL
// File: Assets/Shaders/ExplosionWithCompute.shader
//
// Geometry shader that reads per-triangle offset and normal from the
// compute buffer written by ExplosionCompute.compute.
// The geometry stage no longer calculates physics — it just looks up
// the pre-computed data for its triangle index and applies it.

Shader "Custom/ExplosionWithCompute"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            HLSLPROGRAM

            #pragma vertex   Vert
            #pragma geometry Geo
            #pragma fragment Frag
            #pragma target   4.5   // 4.5+ required for StructuredBuffer in vertex/geometry

            #include "UnityCG.cginc"

            // ------------------------------------------------------------------
            // Mirror of the struct in ExplosionCompute.compute.
            // Must match byte-for-byte (same field order, same padding).
            // ------------------------------------------------------------------
            struct TriangleData
            {
                float3 normal;   // face normal (object space)
                float3 offset;   // accumulated displacement along normal
                float3 velocity; // not used for rendering, but kept for layout match
                float lifetime;
            };

            // Read-only view of the buffer filled by the compute shader.
            // Bound from C# via material.SetBuffer("_TriangleBuffer", buffer).
            StructuredBuffer<TriangleData> _TriangleBuffer;

            float4 _Color;

            // ------------------------------------------------------------------
            // Input / interpolant structs
            // ------------------------------------------------------------------
            struct appdata
            {
                float4 vertex   : POSITION;
                float3 normal   : NORMAL;
                uint   vertexID : SV_VertexID; // needed to recover triangle index
            };

            struct v2g
            {
                float3 objPos  : TEXCOORD0;  // object-space position
                float3 normal  : NORMAL;
                uint   vertexID : TEXCOORD1; // passed through so Geo can derive triIndex
            };

            struct g2f
            {
                float4 clipPos : SV_POSITION;
                float3 normal  : NORMAL;
            };

            // ------------------------------------------------------------------
            // Vertex shader — minimal: forward position and IDs to geometry stage.
            // ------------------------------------------------------------------
            v2g Vert(appdata v)
            {
                v2g o;
                o.objPos = v.vertex.xyz;
                o.normal = v.normal;
                o.vertexID = v.vertexID;
                return o;
            }

            // ------------------------------------------------------------------
            // Geometry shader — reads buffer[triIndex] and applies the offset.
            // ------------------------------------------------------------------
            [maxvertexcount(3)]
            void Geo(
                triangle v2g input[3],
                uint primitiveID : SV_PrimitiveID,          // triangle index within the draw call
                inout TriangleStream<g2f> triStream
            )
            {

                
                TriangleData td = _TriangleBuffer[primitiveID];
                g2f o;

                for (int i = 0; i < 3; i++)
                {
                    // Apply the pre-computed displacement in object space.
                    float3 newObjPos;
                    if(td.lifetime > 0)
                    {
                        newObjPos = input[i].objPos + td.offset; //td.normal * displacement
                    }
                    else
                    {
                        newObjPos = float3(0,0,0);
                    }

                    o.clipPos = UnityObjectToClipPos(float4(newObjPos, 1.0));
                    o.normal = UnityObjectToWorldNormal(input[i].normal);

                    triStream.Append(o);
                }

                triStream.RestartStrip();
            }

            float4 Frag(g2f i) : SV_Target
            {
                float3 N = normalize(i.normal);
                float3 L = _WorldSpaceLightPos0.xyz;
                float  diffuse = saturate(dot(N, L));
                return float4(_Color.rgb * diffuse, 1.0);
            }

            ENDHLSL
        }
    }
}
