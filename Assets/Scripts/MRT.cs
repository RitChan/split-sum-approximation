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

    void OnEnable()
    {
        cb = new CommandBuffer();
        cb.name = "MRT Test";
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
        cb.SetGlobalMatrix("_MATRIX_P_INV", GL.GetGPUProjectionMatrix(AttachedCam.projectionMatrix, false).inverse);
        cb.SetGlobalMatrix("_MATRIX_P", GL.GetGPUProjectionMatrix(AttachedCam.projectionMatrix, false));
        cb.SetGlobalMatrix("_MATRIX_V", AttachedCam.worldToCameraMatrix);
        cb.Blit(null, BuiltinRenderTextureType.CameraTarget, material, 0);
    }

    void OnGUI()
    {
        // var text = "Supported MRT count: ";
        // text += SystemInfo.supportedRenderTargetCount;
        // GUI.Label(new Rect(0, 0, 200, 200), text);
    }
}
