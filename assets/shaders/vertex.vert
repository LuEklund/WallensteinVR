#version 460
#extension GL_EXT_multiview : enable
layout(location = 0) in vec3 vertex;
layout(location = 1) in vec2 uv;
layout(location = 2) in vec3 normal;

layout(location = 0) out vec3 outColor;
layout(location = 1) out vec3 outNormal;
layout(set = 0, binding = 0) uniform Matrices {
    mat4 projection[2];
    mat4 view[2];
} matrices;

layout(push_constant) uniform Push {
    mat4 model;
    vec4 color;
} push;


void main()
{
    gl_Position = matrices.projection[gl_ViewIndex] * matrices.view[gl_ViewIndex] * push.model * vec4(vertex, 1);
    
    float redChannel = push.color[0];
    float blueChannel = push.color[1];
    float greenChannel = push.color[2];
    outColor =  vec3(redChannel, blueChannel,greenChannel);
    outNormal = normal;
}
