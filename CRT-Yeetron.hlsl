/*
	Ripped from Sonic Mania
    https://github.com/luluco250/FXShaders/blob/master/Shaders/CRT_Yeetron.fx

	Note, will look best when MPC-HC is fullscreen
*/

sampler s0 : register(s0);
float4 p0 : register(c0);

#define width  (p0[0])
#define height (p0[1])

#define screenSize (float2(width, height))

#define crt_width 1280
#define crt_height 800

#define i2Resolution float2(crt_width, crt_height)

#define fDownScale 1.2

float4 cmp(float4 src0, float4 src1, float4 src2) {
	return float4(
		src0.x >= 0 ? src1.x : src2.x,
		src0.y >= 0 ? src1.y : src2.y,
		src0.z >= 0 ? src1.z : src2.z,
		src0.w >= 0 ? src1.w : src2.w
	);
}

float4 main(float2 TexCoord : TEXCOORD0) : COLOR
{
	//Declare parameters
	//viewSize
	const float4 c2 = screenSize.xyyy;
	//pixelSize
	const float4 c0 = c2 / float4(c2.x / c2.y, 1, 1, 1);
	//textureSize
	const float4 c1 = i2Resolution.xyyy / fDownScale;
	
	//Declare constants
	const float4 c3 = float4(1.5, 0.800000012, 1.25, 0.75);
    const float4 c4 = float4(6.28318548, -3.14159274, 0.25, -0.25);
    const float4 c5 = float4(1, 0.5, 720, 3);
    const float4 c6 = float4(0.166666672, -0.333000004, -0.666000009, 0.899999976);
    const float4 c7 = float4(0.899999976, 1.10000002, 0, 0);
    const float4 c8 = float4(-0.5, -0.25, 2, 0.5);

	//Declare registers
	float4 r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, oC0;

	//Code starts here
	float4 v0 = TexCoord.xyyy;
	//dcl_2d s0
	r0.x = 1.0 / c0.x;
	r0.y = 1.0 / c0.y;
	r0.xy = (r0 * c1).xy;
	r0.xy = (r0 * v0).xy;
	r0.xy = (r0 * c2).xy;
	r0.zw = frac(r0.xyxy).zw;
	r0.xy = (-r0.zwzw + r0).xy;
	r0.xy = (r0 + c8.wwww).xy;
	r0.x = r0.y * c5.w + r0.x;
	r0.x = r0.x * c6.x;
	r0.x = frac(r0.x);
	r0.xy = (r0.xxxx + c6.yzzw).xy;
	r1.yz = (r0.y >= 0 ? c7.xxyw : c7.xyxw).yz;
	r1.x = c6.w;
	r0.xyz = (r0.x >= 0 ? r1 : c7.yxxw).xyz;
	r1.xy = (c1 * v0).xy;
	r0.w = r1.y * c8.w + c8.w;
	r0.w = frac(r0.w);
	r0.w = r0.w * c4.x + c4.y;
	r2.y = sin(r0.w);
	r1.zw = (abs(r2).yyyy + c4).zw;
	r1.z = clamp(r1.z, 0.0, 1.0);
	r0.w = r1.w >= 0 ? r1.z : c8.w;
	r2 = frac(r1.xyxy);
	r1.xy = (r1 + -r2.zwzw).xy;
	r2 = r2 + c8.xxyy;
	r1.zw = (r1.xyxy + c8.wwww).zw;
	r1.zw = (v0.xyxy * -c1.xyxy + r1).zw;
	r1.w = r1.w + r1.w;
	r1.z = r1.z * c8.w;
	r1.z = -abs(r1).z + c3.x;
	r3.x = max(c3.y, r1.z);
	r4.x = min(r3.x, c3.z);
	r1.zw = (-abs(r1).wwww + c3).zw;
	r1.z = clamp(r1.z, 0.0, 1.0);
	r1.z = r1.w >= 0 ? r1.z : c8.w;
	r4.y = r0.w + r1.z;
	r0.w = r0.w * r4.x;
	r1.z = r1.z * r4.x;
	r3.xy = (r4 * c5).xy;
	r1.w = r3.y * r3.x;
    r2.z = cmp(r2, r2.xyxy, c8.yyyy).z;
    r3.xy = max(c8.yyyy, -r2.zwzw).xy;
    r2.xy = (r2 + r3).xy;
    r1.xy = (r2 * c8.zzzz + r1).xy;
    r1.xy = (r1 + c8.wwww).xy;
    r2.x = 1.0 / c1.x;
    r2.y = 1.0 / c1.y;
    r1.xy = (r1 * r2).xy;
    r2 = tex2D(s0, r1.xy);
    r3.x = r0.w * r2.x;
    r3.yz = (r1.xzww * r2).yz;
    oC0.w = r2.w;
    r0.xyz = (r0 * r3).xyz;
    r1.z = c5.z;
    r0.w = r1.z + -c2.y;
    oC0.xyz = (r0.w >= 0 ? r3 : r0).xyz;

    return oC0;
}
