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
