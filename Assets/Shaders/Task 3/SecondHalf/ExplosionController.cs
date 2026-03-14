using UnityEngine;

[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class ExplosionController : MonoBehaviour
{

    [SerializeField] ComputeShader explosionCompute;  
    [SerializeField] float initialSpeed = 2.0f;   
    [SerializeField] float gravity = -9.8f;  
    [SerializeField] float lifetime = 1;


    ComputeBuffer _triangleBuffer;  
    ComputeBuffer _vertexBuffer;    
    ComputeBuffer _indexBuffer;     

    int _kernelInit;
    int _kernelStep;
    int _triangleCount;

    Material _material;

    // Size of one TriangleData struct in bytes.
    const int TRIANGLE_DATA_STRIDE = 10 * sizeof(float);

    void Start()
    {
        Mesh mesh = GetComponent<MeshFilter>().mesh;
        _material  = GetComponent<MeshRenderer>().material;

        Vector3[] vertices = mesh.vertices;
        int[] indices  = mesh.triangles;
        _triangleCount = indices.Length / 3;

        // --- Build GPU buffers ---

        // Vertex buffer: flat array of float3 positions.
        _vertexBuffer = new ComputeBuffer(vertices.Length, sizeof(float) * 3);
        _vertexBuffer.SetData(vertices);

        // Index buffer: flat triangle index list.
        _indexBuffer = new ComputeBuffer(indices.Length, sizeof(int));
        _indexBuffer.SetData(indices);

        // Triangle data buffer: one record per triangle, read-write from compute,
        // read-only from the geometry shader.
        _triangleBuffer = new ComputeBuffer(_triangleCount, TRIANGLE_DATA_STRIDE);

        // --- Locate kernels ---
        _kernelInit = explosionCompute.FindKernel("InitTriangles");
        _kernelStep = explosionCompute.FindKernel("StepExplosion");

        // --- Bind resources to both kernels ---
        foreach (int k in new[] { _kernelInit, _kernelStep })
        {
            explosionCompute.SetBuffer(k, "_TriangleBuffer", _triangleBuffer);
            explosionCompute.SetBuffer(k, "_Vertices", _vertexBuffer);
            explosionCompute.SetBuffer(k, "_Indices", _indexBuffer);
        }

        explosionCompute.SetInt("_TriangleCount", _triangleCount);

        // --- Run init kernel once ---
        explosionCompute.SetFloat("_InitialSpeed", initialSpeed);
        Dispatch(_kernelInit);

        // --- Give the geometry shader access to the same buffer ---
        _material.SetBuffer("_TriangleBuffer", _triangleBuffer);
    }

    // -----------------------------------------------------------------------
    void Update()
    {
        // Upload per-frame parameters.
        explosionCompute.SetFloat("_DeltaTime", Time.deltaTime);
        explosionCompute.SetFloat("_Gravity", gravity);
        explosionCompute.SetFloat("_Lifetime", lifetime);

        // Step the simulation.
        Dispatch(_kernelStep);
    }

    void Dispatch(int kernel)
    {
        int groups = Mathf.CeilToInt(_triangleCount / 64.0f);
        explosionCompute.Dispatch(kernel, groups, 1, 1);
    }

    [ContextMenu("Reset Explosion")]
    public void ResetExplosion()
    {
        explosionCompute.SetFloat("_InitialSpeed", initialSpeed);
        Dispatch(_kernelInit);
    }

    void OnDestroy()
    {
        _triangleBuffer?.Release();
        _vertexBuffer?.Release();
        _indexBuffer?.Release();
    }
}
