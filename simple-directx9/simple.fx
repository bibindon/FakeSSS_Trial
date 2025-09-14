float4x4 g_matWorldViewProj;
float4 g_lightPos = float4(-10.f, 10.f, -10.f, 0.0f);
float4 g_cameraPos = float4(10.f, 5.f, 10.f, 0.0f);
float3 g_ambient = float3(0.4f, 0.4f, 0.4f);
//float3 g_ambient = float3(0.f, 0.f, 0.f);

// ピクセル・スペキュラ
float g_SpecPower = 32.0f;
float g_SpecIntensity = 0.5f;
float3 g_SpecColor = float3(1, 1, 1);

// ★ 影の色操作（デフォルトは「ほんの少し彩度アップ＆わずかに寒色へ」）
float g_ShadowHueDegrees = +.0f; // 影で回す色相(度)。+で暖色寄り、-で寒色寄り
float g_ShadowSatBoost = 2.15f; // 影の彩度倍率-1（0.15で+15%）
float g_ShadowStrength = 2.6f; // 影色のブレンド強度（0～1）
float g_ShadowGamma = 5.2f; // 影判定のカーブ（>1で“より暗部だけ”に効く）

texture texture1;
sampler textureSampler = sampler_state
{
    Texture = (texture1);
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

struct VSIn
{
    float4 pos : POSITION;
    float3 nrm : NORMAL0;
    float2 uv : TEXCOORD0;
};

struct VSOut
{
    float4 pos : POSITION;
    float3 opos : TEXCOORD0; // オブジェクト座標（World=I想定）
    float3 onrm : TEXCOORD1; // オブジェクト法線
    float2 uv : TEXCOORD2;
};

VSOut VertexShader1(VSIn i)
{
    VSOut o;
    o.pos = mul(i.pos, g_matWorldViewProj);
    o.opos = i.pos.xyz;
    o.onrm = i.nrm;
    o.uv = i.uv;
    return o;
}

// --- YIQ で色相回転＆彩度スケール（高速・分岐なし）
float3 AdjustHueSat_YIQ(float3 rgb, float hueRad, float satMul)
{
    // RGB→YIQ
    float Y = dot(rgb, float3(0.299, 0.587, 0.114));
    float I = dot(rgb, float3(0.596, -0.274, -0.322));
    float Q = dot(rgb, float3(0.212, -0.523, 0.311));

    // 彩度（I,Q の振幅）を拡大・縮小
    float2 iq = float2(I, Q) * satMul;

    // 色相回転
    float s = sin(hueRad);
    float c = cos(hueRad);
    float2 iqR = float2(c * iq.x - s * iq.y,
                        s * iq.x + c * iq.y);

    // YIQ→RGB
    float3 outRGB;
    outRGB.r = Y + 0.956 * iqR.x + 0.621 * iqR.y;
    outRGB.g = Y - 0.272 * iqR.x - 0.647 * iqR.y;
    outRGB.b = Y - 1.106 * iqR.x + 1.703 * iqR.y;
    return outRGB;
}

float4 PixelShader1(VSOut i) : COLOR0
{
    float3 N = normalize(i.onrm);
    float3 L = normalize(g_lightPos.xyz - i.opos);
    float3 V = normalize(g_cameraPos.xyz - i.opos);
    float3 H = normalize(L + V);

    float NdotL = saturate(dot(N, L));
    //NdotL = (NdotL + 1.f) / 2;
    float NdotH = saturate(dot(N, H));

    float3 albedo = tex2D(textureSampler, i.uv).rgb;

    // ----------------- 影だけ色相/彩度を操作 -----------------
    // t: 0=よく当たっている, 1=完全に影。gammaで深部寄りに効かせる
    float t = saturate(pow(1.0f - NdotL, g_ShadowGamma));

    // 影量に応じてパラメータを滑らかに増やす
    float hueRad = (g_ShadowHueDegrees * 0.01745329252f) * t; // deg→rad
    float satMul = 1.0f + (g_ShadowSatBoost * t);

    float3 albedoShadowed = AdjustHueSat_YIQ(albedo, hueRad, satMul);
    albedoShadowed *= 1.5f;

    // 影のブレンド（明るい所は元色、暗い所ほど albedoShadowed）
    float3 albedoFinal = lerp(albedo, albedoShadowed, saturate(g_ShadowStrength * t));

    // ----------------- 通常のライティング -----------------
    float3 diffuse = albedoFinal * NdotL;
    float3 ambient = albedoFinal * g_ambient;

    float3 spec = g_SpecColor * (pow(NdotH, g_SpecPower) * g_SpecIntensity);

    float3 color = ambient + diffuse + spec;
    return float4(saturate(color), 1.0f);
}

technique Technique1
{
    pass P0
    {
        VertexShader = compile vs_3_0 VertexShader1();
        PixelShader = compile ps_3_0 PixelShader1();
    }
}
