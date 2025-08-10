#version 460

layout(location = 0) in vec3 color;
layout(location = 1) in vec2 fragTexCoord;
layout(location = 2) in vec3 normal;

layout(binding = 1) uniform sampler2D texSampler;

layout(location = 0) out vec4 fragColor;

void main()
{
    vec3 unitNormal = normalize(normal);
    vec3 lightDirection = normalize(vec3(0,1,0));
    float brightness = max(dot(unitNormal, lightDirection), 0.2);
    // fragColor = vec4(color * brightness, 1);
    fragColor = texture(texSampler, fragTexCoord);
}

