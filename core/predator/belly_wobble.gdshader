shader_type canvas_item;

uniform float skew_amount = 1.0;
uniform float progress = 0.5;

void vertex() {
    float skew = sin(progress * 3.14159265) * skew_amount;

    VERTEX.x += VERTEX.y * skew;
}