// Image -> CC cells, one fragment per cell.
// Output pixel: R = char byte, G = color index, B = highlight index (all / 255).
//
// For each cell: pick the best single palette color, then the best second color,
// then try every allowed character (both ways round) and keep the closest match.
shader_type canvas_item;
render_mode unshaded, blend_disabled;

// The image resized to (width * 6) x (height * 9): one pixel per CC pixel.
uniform sampler2D source : filter_nearest;
// 54 x 256: texel (pixel, char) is white when that glyph pixel is lit.
uniform sampler2D masks : filter_nearest;
// 256 x 1: texel (char, 0) is white when the converter may use that char.
uniform sampler2D allowed : filter_nearest;
uniform vec4 palette[16];
uniform bool use_color = true;
uniform ivec2 grid_size = ivec2(1, 1);

const int PIXEL_COUNT = 54;

float colorDistance(vec3 a, vec3 b) {
	vec3 d = (a - b) * 255.0;
	return 2.0 * d.r * d.r + 4.0 * d.g * d.g + 3.0 * d.b * d.b;
}

bool isCandidate(int k) {
	return use_color || k == 0 || k == 15;
}

void fragment() {
	ivec2 cell = clamp(ivec2(floor(UV * vec2(grid_size))), ivec2(0), grid_size - 1);
	vec3 pixels[PIXEL_COUNT];
	for (int i = 0; i < PIXEL_COUNT; i++) {
		vec4 s = texelFetch(source, cell * ivec2(6, 9) + ivec2(i % 6, i / 6), 0);
		pixels[i] = s.rgb * s.a;
	}

	// Best single color.
	int first = 0;
	float firstCost = 1e30;
	for (int k = 0; k < 16; k++) {
		if (!isCandidate(k)) continue;
		float cost = 0.0;
		for (int i = 0; i < PIXEL_COUNT; i++) cost += colorDistance(pixels[i], palette[k].rgb);
		if (cost < firstCost) { firstCost = cost; first = k; }
	}

	// Best second color to go with it.
	int second = first;
	float secondCost = firstCost;
	float bestPair = 1e30;
	for (int k = 0; k < 16; k++) {
		if (!isCandidate(k) || k == first) continue;
		float pairCost = 0.0;
		float ownCost = 0.0;
		for (int i = 0; i < PIXEL_COUNT; i++) {
			float a = colorDistance(pixels[i], palette[first].rgb);
			float b = colorDistance(pixels[i], palette[k].rgb);
			pairCost += min(a, b);
			ownCost += b;
		}
		if (pairCost < bestPair) { bestPair = pairCost; second = k; secondCost = ownCost; }
	}

	// cost(char, color = first, highlight = second) = secondCost + sum of difference over lit pixels
	float difference[PIXEL_COUNT];
	for (int i = 0; i < PIXEL_COUNT; i++) {
		difference[i] = colorDistance(pixels[i], palette[first].rgb) - colorDistance(pixels[i], palette[second].rgb);
	}
	float best = 1e30;
	int bestChar = 32;
	int bestColor = first;
	int bestHighlight = second;
	// n = -1 tries space first, so it wins ties for flat cells.
	for (int n = -1; n < 256; n++) {
		int character = n < 0 ? 32 : n;
		if (n == 32) continue;
		if (texelFetch(allowed, ivec2(character, 0), 0).r < 0.5) continue;
		float litSum = 0.0;
		for (int i = 0; i < PIXEL_COUNT; i++) {
			if (texelFetch(masks, ivec2(i, character), 0).r > 0.5) litSum += difference[i];
		}
		float costA = secondCost + litSum;
		if (costA < best) { best = costA; bestChar = character; bestColor = first; bestHighlight = second; }
		float costB = firstCost - litSum;
		if (costB < best) { best = costB; bestChar = character; bestColor = second; bestHighlight = first; }
	}
	COLOR = vec4(float(bestChar) / 255.0, float(bestColor) / 255.0, float(bestHighlight) / 255.0, 1.0);
}
