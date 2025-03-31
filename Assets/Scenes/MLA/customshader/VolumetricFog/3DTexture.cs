using UnityEngine;

public class CloudNoiseDebugger : MonoBehaviour
{
    [Header("噪声参数")]
    public int resolution = 128;
    public float scale = 1.0f;
    public float octaves = 4;
    public float persistence = 0.5f;
    public float lacunarity = 2.0f;
    public Vector3 offset;
    public bool autoUpdate = true;

    [Header("调试选项")]
    public bool animateNoise = false;
    public float animationSpeed = 0.1f;
    
    private Texture3D cloudTexture;

    void Start()
    {
        GenerateAndApplyCloudTexture();
    }
    
    void Update()
    {
        if (animateNoise)
        {
            offset.x += Time.deltaTime * animationSpeed;
            offset.z += Time.deltaTime * animationSpeed * 0.5f;
            
            if (autoUpdate)
            {
                GenerateAndApplyCloudTexture();
            }
        }
    }

    public void GenerateAndApplyCloudTexture()
    {
        if (cloudTexture != null)
        {
            Destroy(cloudTexture);
        }
        
        cloudTexture = new Texture3D(resolution, resolution, resolution, TextureFormat.RGBA32, false);
        Color[] colors = new Color[resolution * resolution * resolution];
        
        for (int z = 0; z < resolution; z++)
        {
            for (int y = 0; y < resolution; y++)
            {
                for (int x = 0; x < resolution; x++)
                {
                    float noiseValue = GenerateNoiseValue(x, y, z);
                    Color color = new Color(1, 1, 1, noiseValue);
                    colors[x + y * resolution + z * resolution * resolution] = color;
                }
            }
        }
        
        cloudTexture.SetPixels(colors);
        cloudTexture.wrapMode = TextureWrapMode.Repeat;
        cloudTexture.filterMode = FilterMode.Bilinear;
        cloudTexture.Apply();
        
        // 设置全局纹理 - 使用你的着色器中定义的名称
        Shader.SetGlobalTexture("_FogNoise", cloudTexture);
        // 如果需要设置其他全局参数
        Shader.SetGlobalFloat("_FogNoiseScale", scale);
        Shader.SetGlobalVector("_FogNoiseOffset", offset);
        
        Debug.Log("已更新全局云纹理 [分辨率:" + resolution + "]");
    }
    
    private float GenerateNoiseValue(int x, int y, int z)
    {
        float amplitude = 1;
        float frequency = 1;
        float noiseHeight = 0;
        
        for (int i = 0; i < octaves; i++)
        {
            float sampleX = (x / (float)resolution) * scale * frequency + offset.x;
            float sampleY = (y / (float)resolution) * scale * frequency + offset.y;
            float sampleZ = (z / (float)resolution) * scale * frequency + offset.z;
            
            float perlinValue = Mathf.PerlinNoise(sampleX, sampleY) * 
                               Mathf.PerlinNoise(sampleY, sampleZ) * 
                               Mathf.PerlinNoise(sampleX, sampleZ);
            
            noiseHeight += perlinValue * amplitude;
            
            amplitude *= persistence;
            frequency *= lacunarity;
        }
        
        return Mathf.Clamp01(noiseHeight);
    }
    
    void OnDestroy()
    {
        if (cloudTexture != null)
        {
            Destroy(cloudTexture);
        }
    }
}