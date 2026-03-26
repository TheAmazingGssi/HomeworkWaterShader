using UnityEngine;

public class RainController : MonoBehaviour
{
    [SerializeField] Material rainySurface;
    [SerializeField] Material lens;
    public void OnSetRainIntensity(float intensity)
    {
        rainySurface.SetFloat("_Rain_Intensity", intensity);
        lens.SetFloat("_Rain_Intensity", intensity);
    }
}
