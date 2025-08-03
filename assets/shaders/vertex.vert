#version 460
#extension GL_EXT_multiview : enable
layout(location = 0) in vec4 vertex;
layout(location = 0) out vec3 color;
layout(binding = 0) uniform Matrices {
    mat4 projection[2];
    mat4 view[2];
    // mat4 model;
} matrices;

layout(push_constant) uniform Push {
    mat4 model;
} push;

// vec3 vertices[3] = vec3[](
//     vec3(1, 1, 4),
//     vec3(-1, -1, 4),
//     vec3(+1, -1, 4)
// );
// vec3 colors[3] = vec3[](
//     vec3(1, 0, 0),
//     vec3(0, 1, 0),
//     vec3(0, 0, 1)
// );

void main()
{
    gl_Position = matrices.projection[gl_ViewIndex] * matrices.view[gl_ViewIndex] * push.model * vertex;
    float greenChannel = (sin(gl_VertexIndex) + 1) / 2;
    float redChannel = (cos(gl_VertexIndex) + 1) / 2;
    float blueChannel = (tan(gl_VertexIndex) + 1) / 2;
    color =  vec3(redChannel, greenChannel, blueChannel);
    //color = abs(vertices[gl_VertexIndex]);
}