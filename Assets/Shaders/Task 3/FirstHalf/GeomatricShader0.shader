// ShaderLab/HLSL
// File: `Assets/Shaders/GeomatricShader0.shader`

// Notes: each section is annotated; geometry stage has detailed explanations and caveats.

Shader "Custom/GeomatricShader0"
{
    // Properties block defines inspector-exposed parameters.
    Properties
    {
        // _Color: RGBA tint used in the fragment shader.
        // Exposed as a Color in the material inspector.
        _Color ("Color", Color) = (1,1,1,1)

        // _PushAmount: scalar amount to push triangle vertices along the triangle normal.
        // Exposed as a float in the material inspector.
        _PushAmount ("Triangle Push Amount", Float) = 0.1
    }

    SubShader
    {
        // Tags hint to the render pipeline about how to treat this material.
        Tags { "RenderType"="Opaque" }

        Pass
        {
            // Begin HLSL block for programmable pipeline stages.
            HLSLPROGRAM

            // Pragma directives tell Unity which shader entrypoints to compile.
            #pragma vertex Vert       // Vertex shader entry point
            #pragma geometry Geo      // Geometry shader entry point
            #pragma fragment Frag     // Fragment (pixel) shader entry point
            #pragma target 4.0        // Require Shader Model 4.0 (geometry shaders)

            // Helper macros and functions (UnityObjectToClipPos, matrices, etc.)
            #include "UnityCG.cginc"

            // ---- Input structure from mesh to vertex shader ----
            struct appdata
            {
                float4 vertex : POSITION; // object-space position (x,y,z,w)
                float3 normal : NORMAL;   // object-space normal (if provided by mesh)
            };

            // ---- Data passed from vertex shader to geometry shader ----
            struct v2g
            {
                float4 clipPos : SV_POSITION; // clip-space position (computed in vertex for convenience)
                float3 objPos  : TEXCOORD0;   // object-space position passed explicitly (use TEXCOORD* for custom data)
                float3 normal  : NORMAL;      // per-vertex normal (object space) — note: semantic can be reused
            };

            // ---- Data emitted from geometry shader to fragment shader ----
            struct g2f
            {
                float4 clipPos : SV_POSITION; // final clip-space position for rasterization
                // Intentionally minimal: no interpolants passed to keep shading uniform (_Color).
                // Add TEXCOORDs / normals here if per-pixel shading is needed.
            };

            // ---- Uniforms set from material / C# ----
            float4 _Color;      // material color (RGBA)
            float _PushAmount;  // distance to push triangle along its normal

            // ---- Vertex shader: prepare data for geometry stage ----
            v2g Vert (appdata v)
            {
                v2g o;

                // Transform object-space position to clip-space for depth/position.
                // This is computed here but the geometry shader recomputes clip positions after pushing.
                o.clipPos = UnityObjectToClipPos(v.vertex);

                // Store object-space position explicitly so geometry shader can compute
                // triangle-space operations (normals, offsets) without projection distortion.
                o.objPos  = v.vertex.xyz;

                // Pass through vertex normal (object-space).
                // Note: if mesh doesn't have normals, this will be zero.
                o.normal  = v.normal;

                return o;
            }

           // ---- Geometry shader: receives an entire triangle and can emit new geometry ----
            // [maxvertexcount(3)] tells the GPU how many vertices this geometry shader will output per input primitive.
            // Here we emit exactly 3 vertices (one triangle) for each input triangle.
            [maxvertexcount(3)]
            void Geo(
                triangle v2g input[3],               // input[] contains the 3 vertices of the source triangle (object-space data set in Vert)
                inout TriangleStream<g2f> triStream  // TriangleStream: emits vertices as indexed triangles (3 vertices per triangle).
                                                     // Alternative streams:
                                                     // - LineStream<g2f>: emits vertices as line segments (2 vertices per line).
                                                     // - PointStream<g2f>: emits individual points (1 vertex per point).
                                                     // The 'inout' modifier allows reading and writing to the stream.
            )
            
            {
                

                // Read object-space positions for each corner of the triangle.
                float3 p0 = input[0].objPos;
                float3 p1 = input[1].objPos;
                float3 p2 = input[2].objPos;

                // Compute two triangle edges in object space.
                float3 edge1 = p1 - p0;
                float3 edge2 = p2 - p0;

                // Cross product gives a vector perpendicular to the triangle surface (object space).
                // Normalize to make _PushAmount an interpretable distance scale.
                float3 triNormal = normalize(cross(edge1, edge2));

                // NOTE: handle degenerate triangles:
                // If edge1 and edge2 are nearly colinear, cross(edge1, edge2) -> 0 and normalize yields NaN.
               
                g2f o;

                // Emit each vertex displaced along the triangle normal.
                // The sign/direction of triNormal depends on the vertex winding (clockwise vs counter-clockwise).
               
                for (int i = 0; i < 3; i++)
                {
                    // Offset in object space to avoid projection distortion.
                    float3 newObjPos = input[i].objPos + triNormal * (_PushAmount * _Time.y);

                    // Convert the pushed object-space position into clip space for rasterization.
                    // UnityObjectToClipPos multiplies by the object-to-clip matrix (model * view * proj).
                    float4 clip = UnityObjectToClipPos(float4(newObjPos, 1.0));

                    // Assign the SV_POSITION which the rasterizer uses.
                    o.clipPos = clip;

                    // Emit new vertex to the triangle stream.
                    triStream.Append(o);
                }

                // End the current primitive strip. RestartStrip ensures the next triangle emitted
                // does not get connected as part of a triangle strip with the previous output.
                triStream.RestartStrip();
            }

            // ---- Fragment shader: simple solid color output ----
            // Receives interpolated g2f (only clipPos used by rasterizer).
            float4 Frag (g2f i) : SV_Target
            {
                // For this shader we return a uniform color. Replace or expand this with lighting
                // if you want per-pixel shading using normals/UVs/etc.
                return _Color;
            }

            ENDHLSL
        }
    }
}
