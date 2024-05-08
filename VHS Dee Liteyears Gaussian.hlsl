// Simple VHS effect inspired by a Dee Liteyears post: https://twitter.com/DeeLiteyears/status/1445430753836347392
// Currently using a bloom-like Gaussian blur vs the bilinear filter used in the origional tweet

sampler s0 : register(s0);
float4 p0 : register(c0);

#define width  (p0[0])
#define height (p0[1])
#define timer (p0[3])

#define aspectRatio (width / height)
#define screenSize (float2(width, height))

float4 p1 :  register(c1);

#define dx (p1[0])
#define dy (p1[1])
#define dSize (float2(dx, dy))

#define source_res float2(640, 480)
#define color_res float2(40, 448)
#define color_pixel_ratio (screenSize / color_res)
#define luma_res float2(333, 448)
#define luma_pixel_ratio (screenSize / luma_res)
#define image_gamma 2.2
#define output_gamma 2.2
#define output_exposure 1.0
#define output_saturation 1.1

#define sample_count 16
#define sample_edge_curve 48


float4 sample_filtered_pix(float2 pixel_coord, float2 offset, float2 sample_res)
{
	float2 texCoord = (pixel_coord + offset)/sample_res;

	float4 color = pow(tex2D(s0, texCoord), image_gamma);

	// Fade colors that are sourced from out of frame
	float edge_lerp = saturate(1 + (texCoord * sample_edge_curve)) * saturate(1 - ((texCoord - 1) * sample_edge_curve));
	return lerp(float4(0,0,0,0), color, edge_lerp);
}

float4 sample_gaussian(float2 texCoord, float2 sample_width, float2 sample_res)
{
	// float2 pixel_coord = floor(texCoord * sample_res);
	float2 pixel_coord = texCoord * sample_res;
	float4 sample_orig = pow(tex2D(s0, (pixel_coord)/sample_res), image_gamma);

	// Gaussian pass
	float4 sample_plan = float4(0,0,0,0);
	float4 sample_diag = float4(0,0,0,0);
	float4 sample_blurred = float4(0,0,0,0);
	[unroll]
	for (int x=0; x < sample_count; x++) {
		// Left / Right
		sample_plan += sample_filtered_pix(pixel_coord, float2( x *  (sample_width.x / sample_count), 0), sample_res);
		sample_plan += sample_filtered_pix(pixel_coord, float2( x * -(sample_width.x / sample_count), 0), sample_res);

		// Up / Down
		sample_plan += sample_filtered_pix(pixel_coord, float2( 0, x *  (sample_width.y / sample_count)), sample_res);
		sample_plan += sample_filtered_pix(pixel_coord, float2( 0, x * -(sample_width.y / sample_count)), sample_res);

		// Diagonal
		sample_diag += sample_filtered_pix(pixel_coord,
			float2(
				x *  (sample_width.x / sample_count), 
				x * (sample_width.x / sample_count)
			), sample_res);
		sample_diag += sample_filtered_pix(pixel_coord,
			float2(
				x * -(sample_width.x / sample_count), 
				x * (sample_width.x / sample_count)
			), sample_res);
		sample_diag += sample_filtered_pix(pixel_coord,
			float2(
				x *  (sample_width.x / sample_count), 
				x * -(sample_width.x / sample_count)
			), sample_res);
		sample_diag += sample_filtered_pix(pixel_coord,
			float2(
				x * -(sample_width.x / sample_count), 
				x * -(sample_width.x / sample_count)
			), sample_res);

		sample_blurred += (sample_diag + 2 * sample_plan + 4 * sample_orig) * 0.0625;
	}

	sample_blurred /= sample_count * (sample_count / 4.0);

	return sample_blurred;
}

float4 sample_filtered(float2 texCoord, float2 sample_width, float2 sample_res)
{
	// float2 pixel_coord = floor(texCoord * color_res);
	float2 pixel_coord = texCoord * sample_res;
	float4 color = pow(tex2D(s0, floor(pixel_coord)/sample_res), image_gamma);
	float total_samples = 1;

	// Width sample
	[unroll]
	for (int x=0; x < sample_count; x++) {
		color += sample_filtered_pix(pixel_coord, float2( x *  (sample_width.x / sample_count), 0), sample_res);
		color += sample_filtered_pix(pixel_coord, float2( x * -(sample_width.x / sample_count), 0), sample_res);

		// Diagonal
		color += sample_filtered_pix(pixel_coord,
			float2(
				x *  (sample_width.x / sample_count), 
				x * (sample_width.y / sample_count)
			), sample_res);
		color += sample_filtered_pix(pixel_coord,
			float2(
				x * -(sample_width.x / sample_count), 
				x * (sample_width.y / sample_count)
			), sample_res);
		color += sample_filtered_pix(pixel_coord,
			float2(
				x *  (sample_width.x / sample_count), 
				x * -(sample_width.y / sample_count)
			), sample_res);
		color += sample_filtered_pix(pixel_coord,
			float2(
				x * -(sample_width.x / sample_count), 
				x * -(sample_width.y / sample_count)
			), sample_res);
	}
	total_samples += 2;

	// Height sample
	[unroll]
	for (int i=0; i < ceil(sample_count / 2); i++) {
		// Up / Down
		color += sample_filtered_pix(pixel_coord, float2( 0, x *  (sample_width.y / sample_count)), sample_res);
		color += sample_filtered_pix(pixel_coord, float2( 0, x * -(sample_width.y / sample_count)), sample_res);
	}
	total_samples += 6;

	color /= sample_count * total_samples;

	return color;
}


float4 sample_color(float2 texCoord)
{
	float2 pixel_coord = (texCoord * color_res);
	float2 pixel_screen_coord = floor(texCoord * screenSize);
	// float2 sample_width = float2(1.62 * 2, 0.5);
	float2 sample_width = floor(source_res / 2) / color_res;
	// float2 sample_width = source_res / color_res;
	// float2 sample_width = screenSize / color_res;

	return sample_gaussian(texCoord, sample_width, color_res);
}


float sample_luma(float2 texCoord)
{
	float2 pixel_coord = (texCoord * luma_res);
	float2 pixel_screen_coord = floor(texCoord * screenSize);
	// float2 sample_width = float2(1.62 * 2, 0.5);
	float2 sample_width = source_res / luma_res;

	float4 color = sample_gaussian(texCoord, sample_width, luma_res);
	return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
}

// both of the following from https://web.archive.org/web/20200207113336/http://lolengine.net/blog/2013/07/27/rgb-to-hsv-in-glsl
float2 rgb2hs(float3 c)
{
	float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
	float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return float2(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e));
}

float3 hsv2rgb(float3 c)
{
	float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}


float4 main(float2 tex : TEXCOORD0) : COLOR
{
	float4 color = sample_color(tex);	// Sample scene color
	float luma = sample_luma(tex);		// Sample scene luma
	float2 hs = rgb2hs(color.rgb);		// Convert color to hue/saturation
	hs.y *= output_saturation;

	// Blend image channels
	color = float4(hsv2rgb(float3(hs.x, hs.y, luma)).rgb, color.a);
	color.rgb *= output_exposure;	// Exposure adjustment
	color.rgb = pow(color.rgb, 1/output_gamma);	// Gamma adjustment
	return saturate(color);
	// return float4(luma,luma,luma,color.a);
}
