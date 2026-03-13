using UnityEngine;

public class BasicComputeTemplate : MonoBehaviour
{
    // Assign the compute shader in the Inspector
    public ComputeShader computeShader;

    // Number of elements we want to process
    public int elementCount = 256;

    // Example parameter sent to GPU
    public float multiplier = 2.0f;

    // GPU buffer
    ComputeBuffer resultBuffer;

    void Start()
    {
        // Always check platform support
        if (SystemInfo.supportsComputeShaders)
        {
            RunComputeShader();
        }
        else
        {
            Debug.LogError("Compute shaders not supported on this platform.");
        }
    }

    void RunComputeShader()
    {
        // ================================
        // 1. FIND KERNEL
        // ================================
        int kernelHandle = computeShader.FindKernel("CSMain");

        // ================================
        // 2. CREATE BUFFER
        // ================================
        // elementCount = number of elements we want to process
        // sizeof(float) = size in bytes of one float
        resultBuffer = new ComputeBuffer(elementCount, sizeof(float));

        // ================================
        // 3. SEND DATA TO GPU
        // ================================
        // Names must match the variables in the compute shader
        computeShader.SetBuffer(kernelHandle, "ResultBuffer", resultBuffer);
        computeShader.SetFloat("Multiplier", multiplier);

        // ================================
        // 4. OPTIONAL: QUERY THREAD GROUP SIZE FROM SHADER
        // ================================
        // These values come directly from [numthreads(x,y,z)]
        // defined in the compute shader
        computeShader.GetKernelThreadGroupSizes(
            kernelHandle,
            out uint threadGroupSizeX,
            out uint threadGroupSizeY,
            out uint threadGroupSizeZ
        );

        // ================================
        // 5. CALCULATE DISPATCH SIZE
        // ================================
        // We divide the total number of elements by the number
        // of threads per group and round up to ensure coverage.
        int threadGroupsX = Mathf.CeilToInt(
            elementCount / (float)threadGroupSizeX
        );

        // ================================
        // 6. DISPATCH COMPUTE SHADER
        // ================================
        computeShader.Dispatch(kernelHandle, threadGroupsX, 1, 1);

        // ================================
        // 7. READ BACK DATA (DEBUGGING)
        // ================================
        // Copy GPU data back to CPU memory
        float[] result = new float[elementCount];
        resultBuffer.GetData(result);

        Debug.Log("Result[10] = " + result[10]);
    }

    void OnDestroy()
    {
        // Always release GPU memory to avoid leaks
        if (resultBuffer != null)
            resultBuffer.Release();
    }
}
