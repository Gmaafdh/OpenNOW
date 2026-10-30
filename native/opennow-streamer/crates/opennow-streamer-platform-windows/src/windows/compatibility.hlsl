Texture2D<float> source_y : register(t0);
Texture2D<float2> source_uv : register(t1);
SamplerState chroma_sampler : register(s0);
cbuffer Conversion : register(b0) {
    float4 scale_bias;
    float4 yuv_coefficients;
    float4 source; // allocation width/height, aperture x/y
    float4 chroma; // negotiated sample-position offset, visible width/height
};
float4 vertex_main(uint id : SV_VertexID) : SV_Position {
    float2 corner = float2((id << 1) & 2, id & 2);
    return float4(corner * float2(2, -2) + float2(-1, 1), 0, 1);
}
float4 pixel_main(float4 position : SV_Position) : SV_Target {
    float2 p = position.xy + source.zw;
    float y = source_y.Load(int3(p, 0)) * scale_bias.x + scale_bias.y;
    // Clamp to visible chroma samples, not to the padded codec allocation.
    float2 low = floor(source.zw * 0.5) * 2 + 1;
    float2 high = floor((source.zw + chroma.zw - 1) * 0.5) * 2 + 1;
    float2 chroma_position = clamp(p + chroma.xy, low, high);
    float2 uv = source_uv.SampleLevel(chroma_sampler, chroma_position / source.xy, 0)
        * scale_bias.z + scale_bias.w;
    return float4(saturate(float3(y + yuv_coefficients.x * uv.y,
        y + yuv_coefficients.y * uv.x + yuv_coefficients.z * uv.y,
        y + yuv_coefficients.w * uv.x)), 1);
}
