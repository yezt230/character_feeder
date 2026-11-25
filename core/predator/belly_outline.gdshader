shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_size : hint_range(0.1, 3.0, 0.1) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	vec2 px = TEXTURE_PIXEL_SIZE * outline_size;

	float neighbor_alpha = 0.0;

	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2( px.x, 0.0)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0,  px.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);

	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2( px.x,  px.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-px.x,  px.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2( px.x, -px.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-px.x, -px.y)).a);

	// Outer outline only where the sprite itself is transparent.
	float outline_alpha = neighbor_alpha * (1.0 - tex.a);

	vec4 outline = vec4(outline_color.rgb, outline_color.a * outline_alpha);

	// Original sprite goes on top of the outline.
	COLOR = mix(outline, tex, tex.a);
}