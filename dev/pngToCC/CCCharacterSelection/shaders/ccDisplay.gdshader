// Draws a whole CC canvas in one pass.
// `cells` is a width x height texture: R = char byte, G = color index, B = highlight index.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D cells : filter_nearest;
uniform sampler2D font_atlas : filter_nearest;
uniform vec4 palette[16];
uniform ivec2 grid_size = ivec2(1, 1);

void fragment() {
	vec2 pos = UV * vec2(grid_size);
	ivec2 cell = clamp(ivec2(floor(pos)), ivec2(0), grid_size - 1);
	vec4 data = texelFetch(cells, cell, 0);
	int character = int(round(data.r * 255.0));
	int color = int(round(data.g * 255.0));
	int highlight = int(round(data.b * 255.0));

	// Glyphs are 12 x 18 px in 16 x 22 px atlas cells starting at (2, 2).
	ivec2 glyph_pixel = clamp(ivec2(floor(fract(pos) * vec2(12.0, 18.0))), ivec2(0), ivec2(11, 17));
	ivec2 atlas_pixel = ivec2(2 + (character % 16) * 16, 2 + (character / 16) * 22) + glyph_pixel;
	float lit = step(0.5, texelFetch(font_atlas, atlas_pixel, 0).a);
	COLOR = vec4(mix(palette[highlight].rgb, palette[color].rgb, lit), 1.0);
}
