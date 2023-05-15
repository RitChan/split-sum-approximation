using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
public class MRT : MonoBehaviour
{
    public Material material;
    private CommandBuffer cb;
    private Camera AttachedCam => gameObject.GetComponent<Camera>();
    private RenderTexture aoRT;

    void OnEnable()
    {
        cb = new CommandBuffer();
        cb.name = "MRT Test";
        aoRT = new RenderTexture(AttachedCam.pixelWidth, AttachedCam.pixelHeight, 0, RenderTextureFormat.RFloat);
        aoRT.useMipMap = true;
        AttachedCam.AddCommandBuffer(CameraEvent.BeforeLighting, cb);
    }

    void OnDisable() 
    { 
        AttachedCam.RemoveCommandBuffer(CameraEvent.BeforeLighting, cb);
        cb.Release();
    }

    void OnPreRender()
    {
        cb.Clear();
        float near = AttachedCam.nearClipPlane;
        float far = AttachedCam.farClipPlane;
        cb.SetGlobalVector("_DEPTH_PARAM", new Vector4((far - near) * 0.5f, (far + near) * 0.5f, 0.0f, 0.0f));
        cb.SetGlobalMatrix("_MATRIX_P_INV", GL.GetGPUProjectionMatrix(AttachedCam.projectionMatrix, false).inverse);
        cb.SetGlobalMatrix("_MATRIX_P", GL.GetGPUProjectionMatrix(AttachedCam.projectionMatrix, false));
        cb.SetGlobalMatrix("_MATRIX_V", AttachedCam.worldToCameraMatrix);
        cb.Blit(null, aoRT, material, 0);
        cb.SetGlobalTexture("_AO_TEX", aoRT);
        cb.Blit(null, BuiltinRenderTextureType.CameraTarget, material, 1);
    }

    void OnGUI()
    {
        // var text = "Supported MRT count: ";
        // text += SystemInfo.supportedRenderTargetCount;
        // GUI.Label(new Rect(0, 0, 200, 200), text);
    }
}
