// newpixie CRT
// by Mattias Gustavsson
// adapted for slang by hunterk

/*
------------------------------------------------------------------------------
This software is available under 2 licenses - you may choose the one you like.
------------------------------------------------------------------------------
ALTERNATIVE A - MIT License
Copyright (c) 2016 Mattias Gustavsson
Permission is hereby granted, free of charge, to any person obtaining a copy of 
this software and associated documentation files (the "Software"), to deal in 
the Software without restriction, including without limitation the rights to 
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies 
of the Software, and to permit persons to whom the Software is furnished to do 
so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all 
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE 
SOFTWARE.
------------------------------------------------------------------------------
ALTERNATIVE B - Public Domain (www.unlicense.org)
This is free and unencumbered software released into the public domain.
Anyone is free to copy, modify, publish, use, compile, sell, or distribute this 
software, either in source code form or as a compiled binary, for any purpose, 
commercial or non-commercial, and by any means.
In jurisdictions that recognize copyright laws, the author or authors of this 
software dedicate any and all copyright interest in the software to the public 
domain. We make this dedication for the benefit of the public at large and to 
the detriment of our heirs and successors. We intend this dedication to be an 
overt act of relinquishment in perpetuity of all present and future rights to 
this software under copyright law.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN 
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------
*/
sampler s0 : register(s0);
float4 p0 : register(c0);

#define width  (p0[0])
#define height (p0[1])
#define FCount (p0[3])

#define aspectRatio (width / height)
#define resolution (float2(width, height))
#define pixelSize (1.0 / resolution)

// Parameters
uniform float blur_x = 1.0; // Horizontal Blur (0.0 to 5.0)
uniform float blur_y = 1.0; // Vertical Blur (0.0 to 5.0)

#define curvature 2.0 // Curvature (0.0001 to 4.0)

#define wiggle_toggle false // Interference
#define scanroll false // Rolling Scanlines

float3 tsample( float2 tc )
{
	tc = tc * float2(1.025, 0.92) + float2(-0.0125, 0.04);
    if(max(abs(tc.x-0.5),abs(tc.y-0.5))>0.5)
        return float3(0.0,0.0,0.0);
	float3 s = pow( abs( tex2D( s0, float2( tc.x, 1.0-tc.y ) ).rgb), float3( 2.2,2.2,2.2 ) );
	return s*float3(1.25,1.25,1.25);
}

float3 filmic( float3 LinearColor )
{
	float3 x = max( float3(0.0,0.0,0.0), LinearColor-float3(0.004,0.004,0.004));
    return (x*(6.2*x+0.5))/(x*(6.2*x+1.7)+0.06);
}

float2 curve( float2 uv )
{
    uv=uv*2.0-1.0;
    uv*=float2(
        1.0+(uv.y*uv.y*resolution.x)*curvature*0.0001, 
        1.0+(uv.x*uv.x*resolution.y)*curvature*0.0001);
    return uv*0.5+0.5;
    // uv = (uv - 0.5);// * 2.0;
    // uv *= float2(0.925, 1.095);
    // uv *= curvature;
    // uv.x *= 1.0 + pow((abs(uv.y) / 4.0), 2.0) * pixelSize;
    // uv.y *= 1.0 + pow((abs(uv.x) / 3.0), 2.0) * pixelSize;
    // uv /= curvature;
    // uv += 0.5;
    // uv =  uv *0.92 + 0.04;
    // return uv;
}

float rand(float2 co){ return frac(sin(dot(co.xy ,float2(12.9898,78.233))) * 43758.5453); }

#define mod(x,y) (x-y*floor(x/y))

float4 main(float2 uv_tx : TexCoord) : COLOR
{
    // stop time variable so the screen doesn't wiggle
    float time = mod(FCount, 849.0) * 36.0;
    float2 uv = uv_tx.xy;
    uv.y = 1.0 - uv_tx.y; // Mirror Y axis
    /* Curve */
    // float2 curved_uv = uv;
    // float2 scuv = uv;
    float2 curved_uv = lerp( curve( uv ), uv, 0.4 );
    float scale = -0.101;
    float2 scuv = curved_uv*(1.0-scale)+scale/2.0+float2(0.003, -0.001);
    // float2 scuv = curved_uv;
// 
    /* Main color, Bleed */
    float3 col;

    float x = 0;
    if (wiggle_toggle == true)
        x = sin(0.1*time+curved_uv.y*13.0)*sin(0.23*time+curved_uv.y*19.0)*sin(0.3+0.11*time+curved_uv.y*23.0)*0.0012;
    float o =sin(uv_tx.y*1.5)/resolution.x;
    x+=o*0.25;
   // make time do something again
    time = float(mod(FCount, 640) * 1); 
    col.r = tsample(float2(x+scuv.x+0.0009,scuv.y+0.0009)).x+0.02;
    col.g = tsample(float2(x+scuv.x+0.0000,scuv.y-0.0011)).y+0.02;
    col.b = tsample(float2(x+scuv.x-0.0015,scuv.y+0.0000)).z+0.02;
    float i = clamp(col.r*0.299 + col.g*0.587 + col.b*0.114, 0.0, 1.0 );
    i = pow( 1.0 - pow(i,2.0), 1.0 );
    i = (1.0-i) * 0.85 + 0.15; 

    /* Ghosting */
    float ghs = 0.15;
    float3 r = tsample(float2(x-0.014*1.0, -0.027)*0.85+0.007*float2( 0.35*sin(1.0/7.0 + 15.0*curved_uv.y + 0.9*time), 
        0.35*sin( 2.0/7.0 + 10.0*curved_uv.y + 1.37*time) )+float2(scuv.x+0.001,scuv.y+0.001)).xyz*float3(0.5,0.25,0.25);
    float3 g = tsample(float2(x-0.019*1.0, -0.020)*0.85+0.007*float2( 0.35*cos(1.0/9.0 + 15.0*curved_uv.y + 0.5*time), 
        0.35*sin( 2.0/9.0 + 10.0*curved_uv.y + 1.50*time) )+float2(scuv.x+0.000,scuv.y-0.002));
    float3 b = tsample(float2(x-0.017*1.0, -0.003)*0.85+0.007*float2( 0.35*sin(2.0/3.0 + 15.0*curved_uv.y + 0.7*time), 
        0.35*cos( 2.0/3.0 + 10.0*curved_uv.y + 1.63*time) )+float2(scuv.x-0.002,scuv.y+0.000)).xyz*float3(0.25,0.25,0.5);

    col += float3(ghs*(1.0-0.299),ghs*(1.0-0.299),ghs*(1.0-0.299))*pow(clamp(float3(3.0,3.0,3.0)*r,float3(0.0,0.0,0.0),float3(1.0,1.0,1.0)),float3(2.0,2.0,2.0))*float3(i,i,i);
    col += float3(ghs*(1.0-0.587),ghs*(1.0-0.587),ghs*(1.0-0.587))*pow(clamp(float3(3.0,3.0,3.0)*g,float3(0.0,0.0,0.0),float3(1.0,1.0,1.0)),float3(2.0,2.0,2.0))*float3(i,i,i);
    col += float3(ghs*(1.0-0.114),ghs*(1.0-0.114),ghs*(1.0-0.114))*pow(clamp(float3(3.0,3.0,3.0)*b,float3(0.0,0.0,0.0),float3(1.0,1.0,1.0)),float3(2.0,2.0,2.0))*float3(i,i,i);

    /* Level adjustment (curves) */
    col *= float3(0.95,1.05,0.95);
    col = clamp(col*1.3 + 0.75*col*col + 1.25*col*col*col*col*col,float3(0.0,0.0,0.0),float3(10.0,10.0,10.0));

    /* Vignette */
    float vig = (0.1 + 1.0*16.0*curved_uv.x*curved_uv.y*(1.0-curved_uv.x)*(1.0-curved_uv.y));
    vig = 1.3*pow(vig,0.5);
    col *= vig;

    if (!scanroll)
        time = 0.0;

    /* Scanlines */
    float scans = clamp( 0.35+0.18*sin(6.0*time-curved_uv.y*resolution.y*1.5), 0.0, 1.0);
    float s = pow(scans,0.9);
    col = col * float3(s,s,s);

    /* Vertical lines (shadow mask) */
    col*=1.0-0.23*(clamp((mod(uv_tx.xy.x, 3.0))/2.0,0.0,1.0));

    /* Tone map */
    col = filmic( col );

    /* Noise */
    /*float2 seed = floor(curved_uv*resolution.xy*float2(0.5))/resolution.xy;*/
    float2 seed = curved_uv*resolution.xy;;
    /* seed = curved_uv; */
    col -= 0.015*pow(float3(rand( seed +time ), rand( seed +time*2.0 ), rand( seed +time * 3.0 ) ), float3(1.5,1.5,1.5) );

    /* Flicker */
    col *= (1.0-0.004*(sin(50.0*time+curved_uv.y*2.0)*0.5+0.5));

    /* Clamp */
   if (curved_uv.x < 0.0 || curved_uv.x > 1.0)
       col *= 0.0;
   if (curved_uv.y < 0.0 || curved_uv.y > 1.0)
       col *= 0.0;

    return float4( col, 1.0 );
}
