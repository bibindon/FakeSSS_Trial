float4x4 g_matWorldViewProj;
float4 g_lightPos = float4(-10.f, 10.f, -10.f, 0.0f);
float4 g_cameraPos = float4(10.f, 5.f, 10.f, 0.0f);
float3 g_ambient = float3(0.4f, 0.4f, 0.4f);
//float3 g_ambient = float3(0.f, 0.f, 0.f);

// �s�N�Z���E�X�y�L����
float g_SpecPower = 32.0f;
float g_SpecIntensity = 0.5f;
float3 g_SpecColor = float3(1, 1, 1);

// �� �e�̐F����i�f�t�H���g�́u�ق�̏����ʓx�A�b�v���킸���Ɋ��F�ցv�j
float g_ShadowHueDegrees = +.0f; // �e�ŉ񂷐F��(�x)�B+�Œg�F���A-�Ŋ��F���
float g_ShadowSatBoost = 2.15f; // �e�̍ʓx�{��-1�i0.15��+15%�j
float g_ShadowStrength = 2.6f; // �e�F�̃u�����h���x�i0�`1�j
float g_ShadowGamma = 5.2f; // �e����̃J�[�u�i>1�Łg���Õ������h�Ɍ����j

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
    float3 opos : TEXCOORD0; // �I�u�W�F�N�g���W�iWorld=I�z��j
    float3 onrm : TEXCOORD1; // �I�u�W�F�N�g�@��
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

// --- YIQ �ŐF����]���ʓx�X�P�[���i�����E����Ȃ��j
float3 AdjustHueSat_YIQ(float3 rgb, float hueRad, float satMul)
{
    // RGB��YIQ
    float Y = dot(rgb, float3(0.299, 0.587, 0.114));
    float I = dot(rgb, float3(0.596, -0.274, -0.322));
    float Q = dot(rgb, float3(0.212, -0.523, 0.311));

    // �ʓx�iI,Q �̐U���j���g��E�k��
    float2 iq = float2(I, Q) * satMul;

    // �F����]
    float s = sin(hueRad);
    float c = cos(hueRad);
    float2 iqR = float2(c * iq.x - s * iq.y,
                        s * iq.x + c * iq.y);

    // YIQ��RGB
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

    // ----------------- �e�����F��/�ʓx�𑀍� -----------------
    // t: 0=�悭�������Ă���, 1=���S�ɉe�Bgamma�Ő[�����Ɍ�������
    float t = saturate(pow(1.0f - NdotL, g_ShadowGamma));

    // �e�ʂɉ����ăp�����[�^�����炩�ɑ��₷
    float hueRad = (g_ShadowHueDegrees * 0.01745329252f) * t; // deg��rad
    float satMul = 1.0f + (g_ShadowSatBoost * t);

    float3 albedoShadowed = AdjustHueSat_YIQ(albedo, hueRad, satMul);
    albedoShadowed *= 1.5f;

    // �e�̃u�����h�i���邢���͌��F�A�Â����ق� albedoShadowed�j
    float3 albedoFinal = lerp(albedo, albedoShadowed, saturate(g_ShadowStrength * t));

    // ----------------- �ʏ�̃��C�e�B���O -----------------
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
