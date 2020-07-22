using UnityEngine;

public class ResolutionScalingByLayer : MonoBehaviour
{
    [Range(0.1f, 1.0f)]
    public float widthScaleFactor = 1.0f;
    [Range(0.1f, 1.0f)]
    public float heightScaleFactor = 1.0f;
    public LayerMask layerMask = -1;

    Camera m_mainCamera;
    Camera m_secondaryCamera;
    Material m_material;

    void Start()
    {
        /* Setup cameras */

        LayerMask cullingMask;

        m_mainCamera = GetComponent<Camera>();
        cullingMask = layerMask & m_mainCamera.cullingMask;
        m_mainCamera.cullingMask &= ~cullingMask;

        GameObject cameraGO = new GameObject();
        cameraGO.hideFlags = HideFlags.HideAndDontSave;
        cameraGO.transform.parent = transform;

        m_secondaryCamera = cameraGO.AddComponent<Camera>();
        m_secondaryCamera.CopyFrom(m_mainCamera);
        m_secondaryCamera.aspect = m_mainCamera.aspect;
        m_secondaryCamera.backgroundColor = Color.clear;
        m_secondaryCamera.clearFlags = CameraClearFlags.SolidColor;
        m_secondaryCamera.cullingMask = cullingMask;
        m_secondaryCamera.enabled = false;

        /* Setup material */

        Shader shader = Shader.Find("Hidden/Custom/BlitCopyWithLastCameraDepth");
        m_material = new Material(shader);
        m_material.hideFlags = HideFlags.HideAndDontSave;
    }

    int GetScaledWidth(int width)
    {
        return (int) Mathf.Floor(widthScaleFactor * width);
    }

    int GetScaledHeight(int height)
    {
        return (int) Mathf.Floor(heightScaleFactor * height);
    }

    void OnRenderImage(RenderTexture source, RenderTexture dest)
    {
        // Allocate temporary render texture
        int width = GetScaledWidth(m_mainCamera.pixelWidth);
        int height = GetScaledHeight(m_mainCamera.pixelHeight);
        RenderTexture renderTexture = RenderTexture.GetTemporary(width, height, 24, RenderTextureFormat.Default);
        renderTexture.Create();

        // Blit full resolution layers
        m_material.SetInt("_SrcBlend", (int) UnityEngine.Rendering.BlendMode.One);
        m_material.SetInt("_DstBlend", (int) UnityEngine.Rendering.BlendMode.Zero);
        m_material.SetInt("_ZTest", (int) UnityEngine.Rendering.CompareFunction.Always);
        Graphics.Blit(source, dest, m_material);

        // Render scaled resolution layers
        m_secondaryCamera.targetTexture = renderTexture;
        m_secondaryCamera.Render();

        // Blit scaled resolution layers
        m_material.SetInt("_SrcBlend", (int) UnityEngine.Rendering.BlendMode.SrcAlpha);
        m_material.SetInt("_DstBlend", (int) UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
        m_material.SetInt("_ZTest", (int) UnityEngine.Rendering.CompareFunction.Less);
        Graphics.Blit(renderTexture, dest, m_material);

        renderTexture.Release();
    }
}
