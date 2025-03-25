using UnityEngine;
using UnityEditor;

public class ApplyTransform : EditorWindow
{
    [MenuItem("Tools/Apply Transform")]
    static void Apply()
    {
        GameObject selected = Selection.activeGameObject;
        if (selected == null) return;

        // 记录当前世界坐标
        Vector3 worldPos = selected.transform.position;
        Quaternion worldRot = selected.transform.rotation;
        Vector3 worldScale = selected.transform.lossyScale;

        // 创建临时父对象
        GameObject tempParent = new GameObject("TempParent");
        tempParent.transform.position = Vector3.zero;
        tempParent.transform.rotation = Quaternion.identity;
        tempParent.transform.localScale = Vector3.one;

        // 设置父子关系并重置本地变换
        selected.transform.SetParent(tempParent.transform, true);
        selected.transform.localPosition = Vector3.zero;
        selected.transform.localRotation = Quaternion.identity;
        selected.transform.localScale = Vector3.one;

        // 移除父子关系并恢复世界坐标
        selected.transform.SetParent(null, true);
        
        // 销毁临时对象
        DestroyImmediate(tempParent);
    }
}