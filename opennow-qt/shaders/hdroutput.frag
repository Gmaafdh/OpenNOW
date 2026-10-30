#version 440
#extension GL_GOOGLE_include_directive : enable
#include "hdrcolor.glsl"
layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 fragColor;
layout(binding = 1) uniform sampler2D linearScene;
void main()
{
    vec4 scene = texture(linearScene, uv);
    // Qt renders premultiplied alpha. Preserve it through the HDR10 output
    // pass so transparent native-overlay pixels stay transparent.
    vec3 linearColor = scene.a > 0.00001 ? scene.rgb / scene.a : vec3(0.0);
    fragColor = vec4(outputColor(linearColor * 80.0, 2.0, 203.0) * scene.a, scene.a);
}
