/*
#version 430 core

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 vertCouleur;
layout(location = 2) in vec2 texCoord;

layout(location = 0) out vec3 v_VertCouleur;
layout(location = 1) out vec2 v_TexCoord;

void main()
{
    gl_Position = vec4(position, 1.f);
    v_VertCouleur = vertCouleur;
    v_TexCoord = texCoord;
}
*/
#version 450

layout(location = 0) out vec3 fragColor;

vec2 positions[3] = vec2[](
        vec2(0.0, -0.5),
        vec2(0.5, 0.5),
        vec2(-0.5, 0.5)
    );

vec3 colors[3] = vec3[](
        vec3(1.0, 0.0, 0.0),
        vec3(0.0, 1.0, 0.0),
        vec3(0.0, 0.0, 1.0)
    );

void main() {
    gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
    fragColor = colors[gl_VertexIndex];
}
