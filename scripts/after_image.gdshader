shader_type canvas_item;

uniform vec4 silhouette_color : source_color = vec4(0.6, 0.6, 0.6, 0.6);
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    float alpha = texture(TEXTURE, UV).a;
    COLOR = vec4(silhouette_color.rgb, alpha * silhouette_color.a * fade_alpha);
}