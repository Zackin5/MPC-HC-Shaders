/**
 * Deband shader by haasn
 * https://github.com/haasn/gentoo-conf/blob/xor/home/nand/.mpv/shaders/deband-pre.glsl
 *
 * Copyright (c) 2015 Niklas Haas
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * Modified and optimized for ReShade by JPulowski
 * https://reshade.me/forum/shader-presentation/768-deband
 *
 * Do not distribute without giving credit to the original author(s).
 *
 * 1.0  - Initial release
 * 1.1  - Replaced the algorithm with the one from MPV
 * 1.1a - Minor optimizations
 *      - Removed unnecessary lines and replaced them with ReShadeFX intrinsic counterparts
 * 2.0  - Replaced "grain" with CeeJay.dk's ordered dithering algorithm and enabled it by default
 *      - The configuration is now more simpler and straightforward
 *      - Some minor code changes and optimizations
 *      - Improved the algorithm and made it more robust by adding some of the madshi's
 *        improvements to flash3kyuu_deband which should cause an increase in quality. Higher
 *        iterations/ranges should now yield higher quality debanding without too much decrease
 *        in quality.
 *      - Changed licensing text and original source code URL
 * 3.0  - Replaced the entire banding detection algorithm with modified standard deviation and
 *        Weber ratio analyses which give more accurate and error-free results compared to the
 *        previous algorithm
 *      - Added banding map debug view
 *      - Added and redefined UI categories
 *      - Added depth detection (credits to spiro) which should be useful when banding only
 *        occurs in the sky texture for example
 *      - Fixed a bug in random number generation which was causing artifacts on the upper left
 *        side of the screen
 *      - Dithering is now applied only when debanding a pixel as it should be which should
 *        reduce the overall noise in the final texture
 *      - Minor code optimizations
 * 3.1  - Switched to chroma-based analysis from luma-based analysis which was causing artifacts
 *        under some scenarios
 *      - Changed parts of the code which was causing compatibility issues on some renderers
 */
 
 
sampler s0 : register(s0);
float4 p0 : register(c0);
float4 p1 : register(c1);

#define width  (p0[0])
#define height (p0[1])
#define timer (p0[3])
#define a (p0[8])

#define aspectRatio (width / height)
#define screenSize (float2(width, height))


// -- config  -- //
#define enable_weber true
/* uniform bool enable_weber <
    ui_category = "Banding analysis";
    ui_label = "Weber ratio";
    ui_tooltip = "Weber ratio analysis that calculates the ratio of the each local pixel's intensity to average background intensity of all the local pixels.";
    ui_type = "radio";
> = true; */

#define enable_sdeviation true
/* uniform bool enable_sdeviation <
    ui_category = "Banding analysis";
    ui_label = "Standard deviation";
    ui_tooltip = "Modified standard deviation analysis that calculates nearby pixels' intensity deviation from the current pixel instead of the mean.";
    ui_type = "radio";
> = true; */

#define t1 0.016
/* uniform float t1 <
    ui_category = "Banding analysis";
    ui_label = "Standard deviation threshold";
    ui_max = 0.5;
    ui_min = 0.0;
    ui_step = 0.001;
    ui_tooltip = "Standard deviations lower than this threshold will be flagged as flat regions with potential banding.";
    ui_type = "slider";
> = 0.007; */

#define t2 0.14
/* uniform float t2 <
    ui_category = "Banding analysis";
    ui_label = "Weber ratio threshold";
    ui_max = 2.0;
    ui_min = 0.0;
    ui_step = 0.01;
    ui_tooltip = "Weber ratios lower than this threshold will be flagged as flat regions with potential banding.";
    ui_type = "slider";
> = 0.04; */

#define range 64.0
/* uniform float range <
    ui_category = "Banding detection & removal";
    ui_label = "Radius";
    ui_max = 32.0;
    ui_min = 1.0;
    ui_step = 1.0;
    ui_tooltip = "The radius increases linearly for each iteration. A higher radius will find more gradients, but a lower radius will smooth more aggressively.";
    ui_type = "slider";
> = 24.0; */

#define iterations 1
/* uniform int iterations <
    ui_category = "Banding detection & removal";
    ui_label = "Iterations";
    ui_max = 4;
    ui_min = 1;
    ui_tooltip = "The number of debanding steps to perform per sample. Each step reduces a bit more banding, but takes time to compute.";
    ui_type = "slider";
> = 1; */

#define BIT_DEPTH 8
/* uniform int BIT_DEPTH <
	ui_type = "slider";
	ui_min = 4; ui_max = 10;
    ui_label = "Bit depth of data to be debanded";
> = 8; */

#define debug_output 0
/* uniform int debug_output <
    ui_category = "Debug";
    ui_items = "None\0Blurred (LPF) image\0Banding map\0";
    ui_label = "Debug view";
    ui_tooltip = "Blurred (LPF) image: Useful when tweaking radius and iterations to make sure all banding regions are blurred enough.\nBanding map: Useful when tweaking analysis parameters, continuous green regions indicate flat (i.e. banding) regions.";
    ui_type = "combo";
> = 0; */

// Reshade uses C rand for random, max cannot be larger than 2^15-1
// uniform int drandom < source = "random"; min = 0; max = 32767; >;

int drandom()
{
	return timer % 32767;
}

float rand(float x)
{
    return frac(x / 41.0);
}

float permute(float x)
{
    return ((34.0 * x + 1.0) * x) % 289.0;
}

float4 main(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
    float3 ori = tex2Dlod(s0, float4(texcoord, 0.0, 0.0)).rgb;

    // Initialize the PRNG by hashing the position + a random uniform
    float3 m = float3(texcoord + 1.0, (drandom() / 32767.0) + 1.0);
    float h = permute(permute(permute(m.x) + m.y) + m.z);

    // Compute a random angle
    float dir  = rand(permute(h)) * 6.2831853;
    float2 o;
    sincos(dir, o.y, o.x);
    
    // Distance calculations
    float2 pt;
    float dist;

    for (int i = 1; i <= iterations; ++i) {
        dist = rand(h) * range * i;
        pt = dist * (1.0/screenSize);
    
        h = permute(h);
    }
    
    // Sample at quarter-turn intervals around the source pixel
    float3 ref[4] = {
        tex2Dlod(s0, float4(mad(pt,                  o, texcoord), 0.0, 0.0)).rgb, // SE
        tex2Dlod(s0, float4(mad(pt,                 -o, texcoord), 0.0, 0.0)).rgb, // NW
        tex2Dlod(s0, float4(mad(pt, float2(-o.y,  o.x), texcoord), 0.0, 0.0)).rgb, // NE
        tex2Dlod(s0, float4(mad(pt, float2( o.y, -o.x), texcoord), 0.0, 0.0)).rgb  // SW
    };

    // Calculate weber ratio
    float3 mean = (ori + ref[0] + ref[1] + ref[2] + ref[3]) * 0.2;
    float3 k = abs(ori - mean);
    for (int j = 0; j < 4; ++j) {
        k += abs(ref[j] - mean);
    }

    k = k * 0.2 / mean;

    // Calculate std. deviation
    float3 sd = 0.0;

    for (int j2 = 0; j2 < 4; ++j2) {
        sd += pow(ref[j2] - ori, 2);
    }

    sd = sqrt(sd * 0.25);

    // Generate final output
    float3 output;

    if (debug_output == 2)
        output = float3(0.0, 1.0, 0.0);
    else
        output = (ref[0] + ref[1] + ref[2] + ref[3]) * 0.25;

    // Generate a binary banding map
    bool3 banding_map = true;

    if (debug_output != 1) {
        if (enable_weber)
            banding_map = banding_map && k <= t2 * iterations;

        if (enable_sdeviation)
            banding_map = banding_map && sd <= t1 * iterations;
    }

	/*------------------------.
	| :: Ordered Dithering :: |
	'------------------------*/
	//Calculate grid position
	float grid_position = frac(dot(texcoord, (screenSize * float2(1.0 / 16.0, 10.0 / 36.0)) + 0.25));

	//Calculate how big the shift should be
	float dither_shift = 0.25 * (1.0 / (pow(2, BIT_DEPTH) - 1.0));

	//Shift the individual colors differently, thus making it even harder to see the dithering pattern
	float3 dither_shift_RGB = float3(dither_shift, -dither_shift, dither_shift); //subpixel dithering

	//modify shift acording to grid position.
	dither_shift_RGB = lerp(2.0 * dither_shift_RGB, -2.0 * dither_shift_RGB, grid_position); //shift acording to grid position.
    
    return float4(banding_map ? output + dither_shift_RGB : ori, 1.0);
}