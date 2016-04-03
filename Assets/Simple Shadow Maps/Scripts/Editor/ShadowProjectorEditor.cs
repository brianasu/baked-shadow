using UnityEngine;
using System.Collections;
using UnityEditor;
using System.Collections.Generic;
using System.IO;

[CustomEditor(typeof(ShadowProjector))]
public class ShadowProjectorEditor : Editor
{
	private SerializedProperty _sizeProp;
	
	[MenuItem("GameObject/Create Other/Shadow Map Baker")]
	public static void CreateCamera()
	{
		GameObject shadowCam = new GameObject("Shadow Camera");
		shadowCam.AddComponent<ShadowProjector>();
		
		var camera = shadowCam.GetComponent<Camera>();
		camera.transform.position = new Vector3(0, 10, 0);
		camera.transform.rotation = Quaternion.Euler(60, 45, 0);
		camera.renderingPath = RenderingPath.VertexLit;
		camera.enabled = false;
		camera.orthographic = true;
		camera.clearFlags = CameraClearFlags.Color;
		camera.backgroundColor = Color.white;
		camera.orthographicSize = 10;
		camera.aspect = 0.5f;
		camera.nearClipPlane = 1f;
		camera.farClipPlane = 20;
	}
	
	public void OnEnable()
	{
		_sizeProp = serializedObject.FindProperty("_size");
	}
	
	private void OnDestroy()
	{
	}
	
	public override void OnInspectorGUI()
	{
		EditorGUILayout.HelpBox(
			"The camera needs to be orthographic to work. " +
			"Reduce the size, near and far of the camera to improve shadow quality. " +
			"Adjust the bias to remove shadow acne", MessageType.Warning);
			
		base.OnInspectorGUI();
		
		
		if(GUILayout.Button("Bake"))
		{
			string directory = EditorUtility.SaveFilePanel("Save Shadow Map", Application.dataPath, "shadowmap", "png");
			
			if(!string.IsNullOrEmpty(directory))
			{
				ShadowProjector projector = (ShadowProjector)target;
				
				string relativePath = "Assets" + directory.Replace(Application.dataPath, "");
				
				Texture2D outputTexture = new Texture2D(_sizeProp.intValue, _sizeProp.intValue, TextureFormat.ARGB32, false);
				projector.BakeShadow(outputTexture);
				
				byte[] bytes = outputTexture.EncodeToPNG();
				File.WriteAllBytes(directory, bytes);
				
				DestroyImmediate(outputTexture);
				
				TextureImporter importer = AssetImporter.GetAtPath(relativePath) as TextureImporter;
				importer.textureFormat = TextureImporterFormat.ARGB32;
				importer.mipmapEnabled = false;
				AssetDatabase.ImportAsset(relativePath);
				AssetDatabase.Refresh();
				
				projector.ShadowMap = AssetDatabase.LoadAssetAtPath(relativePath, typeof(Texture2D)) as Texture2D;
			}
		}
	}
}
