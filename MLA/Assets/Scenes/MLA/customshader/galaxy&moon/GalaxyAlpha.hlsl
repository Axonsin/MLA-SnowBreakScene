void CalculateGalaxyAlpha_float(float TimeOfDay, out float Alpha)
{
    // 默认初始化 Alpha 为 0（完全透明）
    Alpha = 0.0;
    
    // 定义银河在夜晚完全可见，白天完全透明
    float nightAlpha = 1.0;
    float dayAlpha = 0.0;
    
    // 夜晚时间段: timeOfDay < 0.25 (午夜到日出) 或 timeOfDay > 0.75 (日落到午夜)
    // 白天时间段: 0.25 < timeOfDay < 0.75
    
    if (TimeOfDay < 0.25) {
        // 从午夜到日出，逐渐变透明
        Alpha = lerp(nightAlpha, dayAlpha, smoothstep(0.0, 0.15, TimeOfDay));
    }
    else if (TimeOfDay > 0.75) {
        // 从日落到午夜，逐渐变不透明
        Alpha = lerp(dayAlpha, nightAlpha, smoothstep(0.85, 1.0, TimeOfDay));
    }
    else {
        // 白天时完全透明
        Alpha = dayAlpha;
    }
}