// Scanlines from https://github.com/Matsilagi/RSRetroArch/blob/main/Shaders/NTSC_RetroArch.fx

sampler backbuffer : register(s0);
float4 p0 : register(c0);
float4 p1 : register(c1);

#define width  (p0[0])
#define height (p0[1])

#define framecount (p0[3])

#define screenSize (float2(width, height))

#define px (p1[0]) //one_over_width 
#define py (p1[1]) //one_over_height

#define display_sizeX 320
	// ui_type = "drag";
	// ui_min = 1.0;
	// ui_max = BUFFER_WIDTH;
	// ui_label = "Screen Width (NTSC)";

#define display_sizeY 240
	// ui_type = "drag";
	// ui_min = 1.0;
	// ui_max = BUFFER_HEIGHT;
	// ui_label = "Screen Height (NTSC)";

#define NTSC_DISPLAY_GAMMA 2.1
// 	ui_type = "drag";
// 	ui_min = 1.0;
// 	ui_max = 10.0;
// 	ui_step = 0.1;
// 	ui_label = "NTSC Display Gamma (NTSC)";
// > = 2.1;

#define NTSC_CRT_GAMMA 2.5
// 	ui_type = "drag";
// 	ui_min = 1.0;
// 	ui_max = 10.0;
// 	ui_step = 0.1;
// 	ui_label = "NTSC CRT Gamma (NTSC)";
// > = 2.5;

#define display_size int2(display_sizeX,display_sizeY)
// #define display_size int2(width,height)

float4 NTSCGaussPS( float2 texcoord : TEXCOORD0)
{
	float2 pix_no = texcoord * display_size * float2( 4.0, 1.0 );
	float2 one = float2(px, py);

	#define TEX(off) pow(tex2D(backbuffer, texcoord + float2(0.0, (off) * one.y)).rgb, float3(NTSC_CRT_GAMMA,NTSC_CRT_GAMMA,NTSC_CRT_GAMMA))

	float3 frame0 = TEX(-2.0);
	float3 frame1 = TEX(-1.0);
	float3 frame2 = TEX(0.0);
	float3 frame3 = TEX(1.0);
	float3 frame4 = TEX(2.0);

	float offset_dist = frac(pix_no.y) - 0.5;
	float dist0 =  2.0 + offset_dist;
	float dist1 =  1.0 + offset_dist;
	float dist2 =  0.0 + offset_dist;
	float dist3 = -1.0 + offset_dist;
	float dist4 = -2.0 + offset_dist;

	float3 scanline = frame0 * exp(-5.0 * dist0 * dist0);
	scanline += frame1 * exp(-5.0 * dist1 * dist1);
	scanline += frame2 * exp(-5.0 * dist2 * dist2);
	scanline += frame3 * exp(-5.0 * dist3 * dist3);
	scanline += frame4 * exp(-5.0 * dist4 * dist4);

	return float4(pow(1.15 * scanline, float3(1.0 / NTSC_DISPLAY_GAMMA, 1.0 / NTSC_DISPLAY_GAMMA, 1.0 / NTSC_DISPLAY_GAMMA)), 1.0);
}

float4 main( float2 texcoord : TEXCOORD0) : COLOR
{
	return NTSCGaussPS(texcoord);
}
