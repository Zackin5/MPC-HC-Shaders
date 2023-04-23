/*=============================================================================

	ReShade 4 effect file
    github.com/martymcmodding

	Support me:
   		paypal.me/mcflypg
   		patreon.com/mcflypg

    Dither / Deband filter

    * Unauthorized copying of this file, via any medium is strictly prohibited
 	* Proprietary and confidential

=============================================================================*/

/*=============================================================================
	Preprocessor settings
=============================================================================*/

/*=============================================================================
	UI Uniforms
=============================================================================*/

#define SEARCH_RADIUS 0.5
/* uniform float SEARCH_RADIUS <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Debanding Search Radius";
> = 0.5; */

#define BIT_DEPTH 6
/* uniform int BIT_DEPTH <
	ui_type = "slider";
	ui_min = 4; ui_max = 10;
    ui_label = "Bit depth of data to be debanded";
> = 8; */

// #define AUTOMATE_BIT_DEPTH true
/* uniform bool AUTOMATE_BIT_DEPTH <
    ui_label = "Automatic bit depth detection";
> = true; */

#define DEBAND_MODE 2
/* uniform int DEBAND_MODE <
	ui_type = "radio";
    ui_label = "Dither mode";
	ui_items = "None\0Dither\0Deband\0";
> = 2; */


sampler s0 : register(s0);
float4 p0 : register(c0);
float4 p1 : register(c1);

#define width  (p0[0])
#define height (p0[1])
#define timer (p0[3])

#define aspectRatio (width / height)
#define screenSize (float2(width, height))

/*=============================================================================
	Pixel Shaders
=============================================================================*/

// void main(in VSOUT i, out float3 o : SV_Target0)
float4 main(float4 vpos : SV_Position, float2 texcoord : TexCoord) : COLOR
{
	float4 color = tex2D(s0, texcoord);
	float3 o = color.rgb;

	const float2 magicdot = float2(0.75487766624669276, 0.569840290998);
    const float3 magicadd = float3(0, 0.025, 0.0125) * dot(magicdot, 1);
    float3 dither = frac(dot(vpos.xy, magicdot) + magicadd);

    // float bit_depth = AUTOMATE_BIT_DEPTH ? BUFFER_COLOR_BIT_DEPTH : BIT_DEPTH;
    float bit_depth = BIT_DEPTH;
    float lsb = rcp(exp2(bit_depth) - 1.0);

    if(DEBAND_MODE == 2)
    {
     	float2 shift;
     	sincos(6.283 * 30.694 * dither.x, shift.x, shift.y);
     	shift = shift * dither.x - 0.5;

     	float3 scatter = tex2Dlod(s0, float4(texcoord + shift * 0.025 * SEARCH_RADIUS, 0, 0)).rgb;
     	float4 diff; 
     	diff.rgb = abs(o.rgb - scatter);
     	diff.w = max(max(diff.x, diff.y), diff.z);

     	o = lerp(o, scatter, diff.w <= lsb);
    }
    else if(DEBAND_MODE == 1)
    {
    	o += (dither - 0.5) * lsb;
    }
	
	return float4(o, color.a);
}