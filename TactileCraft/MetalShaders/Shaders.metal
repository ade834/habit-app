#include <metal_stdlib>
using namespace metal;

// 1. 纸张微颗粒噪点着色器 (Paper Noise Shader)
// 为纸张提供细腻无缝的微颗粒质感，消除数字界面的塑料感
[[stitchable]] half4 paperNoise(float2 position, half4 color, float intensity) {
    // 经典轻量伪随机数生成
    float2 p = position;
    float n = fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
    
    // 生成居中双向微扰动 (-0.5 ... 0.5)
    float delta = (n - 0.5) * intensity;
    
    // 叠加微噪点并保持原有 Alpha 通道
    half3 rgb = clamp(color.rgb + half3(delta), half3(0.0), half3(1.0));
    return half4(rgb, color.a);
}

// 2. 滚筒卷曲透视着色器 (Cylinder Curl Distortion Shader)
// 对打字机纸张顶部做类似卷入滚筒的 Y 轴压缩透视变形
[[stitchable]] float2 cylinderCurl(float2 position, float2 size, float curlThreshold) {
    float y = position.y;
    if (y < curlThreshold) {
        // 归一化顶部距离
        float progress = (curlThreshold - y) / curlThreshold;
        // 沿 Y 轴按正弦加速压缩
        float factor = 1.0 + pow(progress, 1.8) * 0.45;
        return float2(position.x, curlThreshold - ((curlThreshold - y) * factor));
    }
    return position;
}
