shader_type spatial;
render_mode unshaded;

uniform sampler2D simplified_albedo : source_color;

uniform vec3[8] colors: source_color;
uniform int[256] countryColors;
uniform float colorizeStrength : hint_range(0.0, 1.0);
uniform vec3 water_color: source_color;

uniform sampler2D countryIDs : filter_nearest;
uniform vec3 borderSolvedColor : source_color;
uniform vec3 borderUnsolvedColor : source_color;
uniform vec3 borderSelectedColor : source_color;
uniform float bordersStrength : hint_range(0.0, 1.0);
uniform float outlineStrength : hint_range(0.0, 1.0);
uniform float outlineWidth : hint_range(0.0, 0.002, 0.0001);
uniform uint numCountries;
uniform int selectedID;
uniform bool[256] countriesSolved;
uniform vec2 borderResolution = vec2(5400, 2700);
uniform float borderEpsilon = 0.001;

const mat3 xKernel = mat3(vec3(-1,0,1), vec3(-1,0,1), vec3(-1,0,1));
const mat3 yKernel = mat3(vec3(-1), vec3(0), vec3(1));

void vertex() {
	// Called for every vertex the material is visible on.
}

float convolute_scalar(sampler2D source, mat3 kernel, float divisor, vec2 textureCoords, vec2 resolution) {
	// MATRICES
	// [0] is left
	// [1] is center (above + below)
	// [2] is right
	float result = 0.0;
	for (int i=0; i<9; i++) {
		vec2 offset = vec2(float((i / 3) - 1), float((i % 3) - 1)) / resolution;
		vec2 offsetPos = vec2(textureCoords.x + offset.x, textureCoords.y + offset.y);
		result += (texture(source, offsetPos).r * kernel[i/3][i%3]);
	}
	return abs(result / divisor);
}

float getBorder(vec2 textureCoords) {
	float xConv = convolute_scalar(countryIDs, xKernel, 1.0, textureCoords, borderResolution);
	float yConv = convolute_scalar(countryIDs, yKernel, 1.0, textureCoords, borderResolution);
	return (xConv + yConv)*0.5;
}

void fragment() {
	float bordersInverse = 1.0 - bordersStrength;
	vec3 solvedColor = borderUnsolvedColor * 1.0; // TODO need a bit-field for solve state of each country

	float ID_raw = texture(countryIDs, UV).r;
	float ID_float = ID_raw * 256.0;
	float ID_rem = ID_float - float(int(ID_float));
	int ID = int(ID_float) - 1;
	float edge = getBorder(UV);

	vec3 bordersColor;
	vec3 colorizeColor;
	if (ID >= 0) {
		float drawStrength = bordersStrength;
		float solvedFactor = countriesSolved[ID] ? 1.0 : 0.0;
		float unsolvedFactor = 1.0 - solvedFactor;
		vec3 solvedCombined = borderSolvedColor * solvedFactor + borderUnsolvedColor * unsolvedFactor;
		if (ID == selectedID) {
			solvedCombined = borderSelectedColor * bordersStrength + solvedCombined * bordersInverse;
			drawStrength = 1.0;
		}
		if (edge > borderEpsilon) {
			bordersColor = solvedCombined * drawStrength;
		} else {
			bordersColor = max(solvedCombined * drawStrength - vec3(outlineStrength), 0.0);
		}
		//bordersColor = max(solvedCombined * drawStrength - ((1.0 - diff) * vec3(outlineStrength)), 0.0);

		float drawInverse = 1.0 - drawStrength;
		colorizeColor = colors[countryColors[ID]] * drawInverse + bordersColor * drawStrength;
	}
	else {
		bordersColor = vec3(0.0);
		colorizeColor = water_color;
	}

	float colorizeInverse = 1.0 - colorizeStrength;
	ALBEDO = ((texture(simplified_albedo, UV).rgb + bordersColor) * colorizeInverse + colorizeColor * colorizeStrength);
	// Called for every pixel the material is visible on.
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
