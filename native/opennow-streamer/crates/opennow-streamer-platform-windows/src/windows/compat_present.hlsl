// DirectX 10 compatibility present.
//
// Feature level 10_0 and 10_1 reject Shader Model 5.0 bytecode, so this pair is compiled at
// vs_4_0 and ps_4_0. It draws the CPU-converted RGBA8 video texture into the letterboxed
// viewport of a bitblt-model back buffer; DXGI does no scaling and the CPU does none either.
//
// The fullscreen triangle carries its own texture coordinates, so the draw needs no constant
// buffer and does not depend on how SV_Position is reported inside a viewport.
Texture2D<float4> video_rgba : register(t0);
SamplerState video_sampler : register(s0);

struct VertexOutput {
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

VertexOutput vertex_main(uint id : SV_VertexID)
{
    VertexOutput output;
    // id 0, 1, 2 -> corners (0,0), (2,0), (0,2): one triangle that covers the whole viewport.
    float2 corner = float2((id << 1) & 2, id & 2);
    output.position = float4(corner * float2(2, -2) + float2(-1, 1), 0, 1);
    output.uv = corner;
    return output;
}

float4 pixel_main(VertexOutput input) : SV_Target
{
    // Bilinear filtering scales the video-sized source into the fitted destination rectangle,
    // matching the video processor's output on capable hardware.
    return float4(video_rgba.Sample(video_sampler, input.uv).rgb, 1.0);
}
