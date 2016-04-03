using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class ShadowProjector : MonoBehaviour
{
    public enum TextureSize
    {
        size64 = 64,
        size128 = 128,
        size256 = 256,
        size512 = 512,
        size1024 = 1024,
        size2048 = 2048,
        size4096 = 4096
    }
    [SerializeField]
    private Shader _shadowMapShader;
    [SerializeField]
    private Texture2D _shadowMap;
    public Texture2D ShadowMap
    {
        set { _shadowMap = value; }
    }

    [SerializeField]
    private float _bias = 0.2f;
    [SerializeField]
    private TextureSize _size = TextureSize.size1024;
    [SerializeField]
    private bool _realTimeShadow = false;
    //
    private Matrix4x4 _offset;
    private Camera _camera;

    private void Start()
    {
        _offset = Matrix4x4.TRS(Vector3.one * 0.5f, Quaternion.identity, Vector3.one * 0.5f);
        _camera = GetComponent<Camera>();
        _camera.aspect = 1;
    }

    private void Update()
    {
        if (_realTimeShadow)
        {
            Bake();
        }
        else
        {
            if (_shadowMap != null)
            {
                Shader.SetGlobalTexture("_ShadowMap", _shadowMap);
            }
        }

        Shader.SetGlobalMatrix("_ShadowMapMat", _offset * _camera.projectionMatrix * _camera.worldToCameraMatrix);
        Shader.SetGlobalMatrix("_ShadowMapMV", _camera.worldToCameraMatrix);
        Shader.SetGlobalVector("_CameraSettings", new Vector4(_camera.farClipPlane + _bias, 0, 0, 0));
    }

    public void Bake()
    {
        int shadowSize = (int)_size;

        RenderTexture renderTexture = RenderTexture.GetTemporary(shadowSize, shadowSize, 16, RenderTextureFormat.ARGB32);

        Render(_camera, renderTexture);

        Shader.SetGlobalTexture("_ShadowMap", renderTexture);

        RenderTexture.ReleaseTemporary(renderTexture);
    }

    public void Render(Camera cam, RenderTexture renderTexture)
    {
        cam.renderingPath = RenderingPath.VertexLit;
        cam.enabled = false;
        cam.orthographic = true;
        cam.targetTexture = renderTexture;
        cam.aspect = 1;
        cam.RenderWithShader(_shadowMapShader, "RenderType");
    }

    public void BakeShadow(Texture2D outputTexture)
    {
        int shadowSize = outputTexture.width;

        RenderTexture renderTexture = RenderTexture.GetTemporary(shadowSize, shadowSize, 16, RenderTextureFormat.ARGB32);

        Render(_camera, renderTexture);

        RenderTexture.active = renderTexture;
        outputTexture.ReadPixels(new Rect(0, 0, shadowSize, shadowSize), 0, 0);
        outputTexture.Apply();

        _realTimeShadow = false;

        RenderTexture.ReleaseTemporary(renderTexture);
    }
}
