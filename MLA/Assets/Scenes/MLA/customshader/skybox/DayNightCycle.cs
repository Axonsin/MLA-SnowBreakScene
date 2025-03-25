using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DayNightCycle : MonoBehaviour
{
    [Header("Time Settings")]
    public float dayDuration = 120f; // 昼夜循环的总时长（秒）
    public float maxSunIntensity = 3f; // 白天太阳光的最大强度
    public float minSunIntensity = 0f; // 夜晚太阳光的最小强度
    public bool initTimeFromSunPosition = true; // 是否根据太阳位置初始化时间

    [Header("Light Settings")]
    public Light sunLight; // 场景中的方向光
    public Gradient lightColor; // 太阳光颜色随时间变化
    
    
    [Header("Moon Settings")]
    public GameObject moonObject; // 月球对象
    public float moonOrbitRadius = 500f; // 月球轨道半径
    public Light moonLight; // 月球光源(可选)
    public float moonLightIntensity = 0.3f; // 月光强度

    [Range(0, 1)]
    public float timeOfDay = 0f; // 当前时间

    private float timeSpeed; // 时间推进速度
    private bool isInitialized = false; // 是否已初始化
    
    [Header("Bloom Settings")]
    public Volume postProcessingVolume; // 后处理 Volume
    private Bloom bloom; // 用于控制 Bloom 的引用
    public float maxBloomIntensity = 3f; // 最大的 Bloom 强度
    public float minBloomIntensity = 1f; // 最小的 Bloom 强度
    
    [Header("Shadow Settings")]
    public float maxShadowStrength = 1.0f;
    public float minShadowStrength = 0.0f;
    
    
    [Header("Skybox Lighting Settings")]
    public float daytimeAmbientIntensity = 1.0f;
    public float nighttimeAmbientIntensity = 0.1f;

 void Start()
    {
        // 计算时间推进速度
        timeSpeed = 1f / dayDuration;
        
        // 初始化Bloom组件
        if (postProcessingVolume != null)
        {
            // 尝试获取Bloom组件
            if (!postProcessingVolume.profile.TryGet(out bloom))
            {
                Debug.LogError("无法获取Bloom组件！请确保Volume中添加了Bloom效果。");
            }
        }
        else
        {
            Debug.LogError("未指定Post Processing Volume！");
        }
        
        // 如果启用根据太阳位置初始化时间
        if (initTimeFromSunPosition && sunLight != null)
        {
            InitializeTimeFromSunPosition();
        }
        
        // 设置全局 Shader 属性
        Shader.SetGlobalFloat("_TimeOfDay", timeOfDay);
        
        isInitialized = true;
    }
    
    /// <summary>
    /// 根据太阳当前旋转角度计算时间值
    /// </summary>
    private void InitializeTimeFromSunPosition()
    {
        if (sunLight != null)
        {
            // 获取太阳的当前仰角（X轴旋转）
            float currentElevation = sunLight.transform.rotation.eulerAngles.x;
            
            // 转换到我们使用的角度系统
            // 我们的系统: timeOfDay=0 对应 elevation=-90度(午夜)
            // timeOfDay=0.5 对应 elevation=90度(正午)
            
            // 将Unity 0-360度系统转换为-180到180度
            if (currentElevation > 180f)
                currentElevation = currentElevation - 360f;
                
            // 将太阳角度转换为时间值
            // 公式来自UpdateSunRotation: elevation = (timeOfDay * 360f) - 90f
            timeOfDay = (currentElevation + 90f) / 360f;
            
            // 确保timeOfDay在0-1范围内循环
            timeOfDay = Mathf.Repeat(timeOfDay, 1.0f);
            
            Debug.Log($"基于太阳角度初始化: 角度={currentElevation}, 时间值={timeOfDay:F2}");
        }
    }

    void Update()
    {
        // 如果已初始化，更新时间
        if (isInitialized)
        {
            // 更新时间
            timeOfDay += timeSpeed * Time.deltaTime;
            // 循环日夜，平滑过渡
            if (timeOfDay > 1f)
            {
                timeOfDay = timeOfDay - 1f;
            }
        }

        // 更新全局 Shader 属性
        Shader.SetGlobalFloat("_TimeOfDay", timeOfDay);
        
        // 调整太阳的角度
        UpdateSunRotation();

        // 调整太阳的颜色
        UpdateSunColor();

        // 调整太阳的强度
        UpdateSunIntensity();
        
        // 调整月球的位置
        UpdateMoonPosition();
        
        //调整bloom强度
        UpdateBloomIntensity();
        
        // 调整环境光
        UpdateAmbientLightFromSkybox();
        
        //Debug
         if (bloom != null)
         {
             Debug.Log($"Bloom intensity: {bloom.intensity.value}, Time: {timeOfDay}");
         }
         else
         {
             Debug.LogWarning("Bloom is null!");
         }
    }

    private void UpdateSunRotation()
    {
        if (sunLight != null)
        {
            // 使用 timeOfDay 计算太阳的角度
            float elevation = (timeOfDay * 360f) - 90f;
            // 使用 timeOfDay 计算太阳的角度
            sunLight.transform.rotation = Quaternion.Euler(new Vector3((timeOfDay * 360f) - 90f, 90f, 0f));
            // 确保阴影类型是开启的
            sunLight.shadows = LightShadows.Soft;
        
            // 调整阴影强度 - 当太阳角度低时增强阴影
            float normalizedElevation = Mathf.Clamp01((elevation + 90f) / 180f);
        
            // 当太阳在地平线附近(早晨/黄昏)时，阴影最长且最明显
            float shadowFactor = 0;
            if (normalizedElevation > 0.1f && normalizedElevation < 0.9f) 
            {
                // 在地平线上方时有阴影
                shadowFactor = Mathf.Sin(normalizedElevation * Mathf.PI);
            }
        
            sunLight.shadowStrength = 1;
        
            // 调试信息
            Debug.Log($"Sun elevation: {elevation}, Shadow strength: {sunLight.shadowStrength}");
        }
    }

    private void UpdateSunColor()
    {
        if (sunLight != null && lightColor != null)
        {
            // 根据 Gradient 随时间改变光的颜色
            sunLight.color = lightColor.Evaluate(timeOfDay);
        }
    }

    private void UpdateSunIntensity()
    {
        if (sunLight != null)
        {
            // 正午时间在0.5，将日出时间调整为0.25-0.5，日落时间为0.5-0.75
            if (timeOfDay >= 0.25f && timeOfDay <= 0.5f)
            {
                // 日出，太阳强度从最小渐渐增加到最大
                sunLight.intensity = Mathf.Lerp(minSunIntensity, maxSunIntensity, (timeOfDay - 0.25f) / 0.25f);
            }
            else if (timeOfDay > 0.5f && timeOfDay <= 0.75f)
            {
                // 日落，太阳强度从最大渐渐减少到最小
                sunLight.intensity = Mathf.Lerp(maxSunIntensity, minSunIntensity, (timeOfDay - 0.5f) / 0.25f);
            }
            else
            {
                // 夜晚保持最小强度
                sunLight.intensity = minSunIntensity;
            }
        }
        Debug.Log($"Sun intensity: {sunLight.intensity}, Time: {timeOfDay}");
    }
    
    private void UpdateMoonPosition()
    {
        if (moonObject != null && sunLight != null)
        {
            // 计算月球时间 - 与太阳相差半个周期，但保持相同的旋转方向
            float moonTimeOfDay = Mathf.Repeat(timeOfDay + 0.5f, 1.0f);
            
            // 使用与太阳相同的角度计算方式，保持相同的运动方向
            float moonElevation = (moonTimeOfDay * 360f) - 90f;
            
            // 关键：使用与太阳相同的Y旋转值，确保运动方向一致
            Vector3 moonRotation = new Vector3(moonElevation, 90f, 0f);
            Quaternion moonQuaternion = Quaternion.Euler(moonRotation);
            
            // 计算月球位置 - 使用与太阳相同的方向计算方式
            Vector3 moonDirection = moonQuaternion * Vector3.forward;
            moonObject.transform.position = Vector3.zero - moonDirection * moonOrbitRadius;
            
            // 让月球始终面向世界原点
            moonObject.transform.LookAt(Vector3.zero);
            
            // 如果有月球光源，更新月球光照强度
            if (moonLight != null)
            {
                // 在夜晚(timeOfDay < 0.25 || timeOfDay > 0.75)时月光最强,这里可以更改强度。本质上是lerp的显式表达式
                float nightFactor = 1f;
                if (timeOfDay < 0.20f)
                {
                    nightFactor = 4f - (timeOfDay / 0.25f);
                }
                else if (timeOfDay > 0.75f)
                {
                    nightFactor = (timeOfDay - 0.75f) / 0.25f +3f;
                }
                
                moonLight.intensity = moonLightIntensity * nightFactor;
            }
            Debug.Log($"Moon intensity: {moonLight.intensity}, Time: {timeOfDay}");
        }
    }
    
    private void UpdateBloomIntensity()
    {
        if (bloom != null)
        {
            // 日出和日落时间段逐渐增加 Bloom 强度
            if (timeOfDay >= 0.2f && timeOfDay <= 0.3f)
            {
                // 日出期间逐渐增加 Bloom
                float t = Mathf.InverseLerp(0.2f, 0.3f, timeOfDay);
                bloom.intensity.value = Mathf.Lerp(minBloomIntensity, maxBloomIntensity, t);
            }
            else if (timeOfDay >= 0.7f && timeOfDay <= 0.8f)
            {
                // 日落期间逐渐增加 Bloom
                float t = Mathf.InverseLerp(0.7f, 0.8f, timeOfDay);
                bloom.intensity.value = Mathf.Lerp(minBloomIntensity, maxBloomIntensity, t);
            }
            else
            {
                // 其他时间段逐渐减弱 Bloom
                bloom.intensity.value = Mathf.Lerp(bloom.intensity.value, minBloomIntensity, Time.deltaTime * 2f);
            }
        }
    }
    
    private void UpdateAmbientLightFromSkybox()
    {
        // 设置环境光源为天空盒
        RenderSettings.ambientMode = AmbientMode.Skybox;

        float intensity;
    
        // time < 0.2: 保持夜晚强度
        if (timeOfDay < 0.2f)
        {
            intensity = nighttimeAmbientIntensity;
        }
        // time 0.2-0.3: 日出过渡期
        else if (timeOfDay < 0.3f)
        {
            float t = Mathf.InverseLerp(0.2f, 0.3f, timeOfDay);
            intensity = Mathf.Lerp(nighttimeAmbientIntensity, daytimeAmbientIntensity, t);
        }
        // time 0.3-0.7: 保持白天强度
        else if (timeOfDay < 0.7f)
        {
            intensity = daytimeAmbientIntensity;
        }
        // time 0.7-0.8: 日落过渡期
        else if (timeOfDay < 0.8f)
        {
            float t = Mathf.InverseLerp(0.7f, 0.8f, timeOfDay);
            intensity = Mathf.Lerp(daytimeAmbientIntensity, nighttimeAmbientIntensity, t);
        }
        // time > 0.8: 保持夜晚强度
        else
        {
            intensity = nighttimeAmbientIntensity;
        }

        // 应用计算出的强度
        RenderSettings.ambientIntensity = intensity;

        // 为了更好的效果，确保启用环境反射
        RenderSettings.defaultReflectionMode = DefaultReflectionMode.Skybox;
        RenderSettings.reflectionIntensity = intensity;

        // 如果使用URP，更新光照探针
        DynamicGI.UpdateEnvironment();
        Debug.Log($"Environment intensity: {intensity}");
    }
}