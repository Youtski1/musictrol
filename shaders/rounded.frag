#version 440
// Скруглённые углы и обрезка «по заполнению» прямо при выводе картинки —
// без промежуточных текстур и маски (дешевле MultiEffect по памяти и GPU).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;   // размер элемента в пикселях
    vec2 crop;       // какая доля текстуры видна по x и y (PreserveAspectCrop)
    float radius;    // радиус скругления в пикселях
};

layout(binding = 1) uniform sampler2D source;

void main() {
    // Обрезка с заполнением: берём центральную часть текстуры.
    vec2 uv = 0.5 + (qt_TexCoord0 - 0.5) * crop;

    // Расстояние до скруглённого прямоугольника (SDF), мягкий край в 1 px.
    vec2 p = qt_TexCoord0 * itemSize;
    vec2 q = abs(p - itemSize * 0.5) - (itemSize * 0.5 - vec2(radius));
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    float alpha = 1.0 - smoothstep(-0.75, 0.75, d);

    fragColor = texture(source, uv) * alpha * qt_Opacity;
}
