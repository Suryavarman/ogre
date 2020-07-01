/*
-----------------------------------------------------------------------------
This source file is part of OGRE
(Object-oriented Graphics Rendering Engine)
For the latest info, see http://www.ogre3d.org

Copyright (c) 2000-2014 Torus Knot Software Ltd
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
-----------------------------------------------------------------------------
*/
//-----------------------------------------------------------------------------
// Program Name: SGXLib_IntegratedPSSM
// Program Desc: Integrated PSSM functions.
// Program Type: Vertex/Pixel shader
// Language: GLSL
//-----------------------------------------------------------------------------

#ifdef DEBUG_PSSM
vec3 pssm_lod_info = vec3(0);
#endif

//-----------------------------------------------------------------------------
void SGX_ApplyShadowFactor_Diffuse(in vec4 ambient, 
					  in vec4 lightSum, 
					  in float fShadowFactor, 
					  out vec4 oLight)
{
	oLight.rgb = ambient.rgb + (lightSum.rgb - ambient.rgb) * fShadowFactor;
	oLight.a   = lightSum.a;

#ifdef DEBUG_PSSM
	oLight.rgb += pssm_lod_info;
#endif
}
	
//-----------------------------------------------------------------------------
void SGX_ShadowPCF4(in sampler2D shadowMap, in vec4 shadowMapPos, in vec2 offset, out float c)
{
	shadowMapPos = shadowMapPos / shadowMapPos.w;
#ifndef OGRE_REVERSED_Z
	shadowMapPos.z = shadowMapPos.z * 0.5 + 0.5; // convert -1..1 to 0..1
#endif
	vec2 uv = shadowMapPos.xy;
	vec3 o = vec3(offset, -offset.x) * 0.3;

    // clamp depth value to near & far of current frustum
    shadowMapPos.z = clamp(shadowMapPos.z, 0.0, 1.0);

	// Note: We using 2x2 PCF. Good enough and is a lot faster.
	c =	 (shadowMapPos.z <= texture2D(shadowMap, uv.xy - o.xy).r) ? 1.0 : 0.0; // top left
	c += (shadowMapPos.z <= texture2D(shadowMap, uv.xy + o.xy).r) ? 1.0 : 0.0; // bottom right
	c += (shadowMapPos.z <= texture2D(shadowMap, uv.xy + o.zy).r) ? 1.0 : 0.0; // bottom left
	c += (shadowMapPos.z <= texture2D(shadowMap, uv.xy - o.zy).r) ? 1.0 : 0.0; // top right
		
	c /= 4.0;
#ifdef OGRE_REVERSED_Z
    c = 1.0 - c;
#endif
}

void SGX_ShadowPCF4(in sampler2DShadow shadowMap, in vec4 shadowMapPos, out float c)
{
#ifndef OGRE_REVERSED_Z
    shadowMapPos.z = shadowMapPos.z * 0.5 + 0.5 * shadowMapPos.w; // convert -1..1 to 0..1
#endif
    c = vec4(shadow2DProj(shadowMap, shadowMapPos)).r; // avoid scalar swizzle with textureProj
}

//-----------------------------------------------------------------------------
void SGX_ComputeShadowFactor_PSSM3(in float fDepth,
							in vec4 vSplitPoints,	
							in vec4 lightPosition0,
							in sampler2D shadowMap0,
							in vec2 invShadowMapSize0,
							in vec4 lightPosition1,
							in sampler2D shadowMap1,
							in vec2 invShadowMapSize1,
							in vec4 lightPosition2,
							in sampler2D shadowMap2,
							in vec2 invShadowMapSize2,
							out float oShadowFactor)
{
	if (fDepth  <= vSplitPoints.x)
	{									
		SGX_ShadowPCF4(shadowMap0, lightPosition0, invShadowMapSize0, oShadowFactor);
#ifdef DEBUG_PSSM
        pssm_lod_info.r = 1.0;
#endif
	}
	else if (fDepth <= vSplitPoints.y)
	{									
		SGX_ShadowPCF4(shadowMap1, lightPosition1, invShadowMapSize1, oShadowFactor);
#ifdef DEBUG_PSSM
        pssm_lod_info.g = 1.0;
#endif
	}
	else
	{										
		SGX_ShadowPCF4(shadowMap2, lightPosition2, invShadowMapSize2, oShadowFactor);
#ifdef DEBUG_PSSM
        pssm_lod_info.b = 1.0;
#endif
	}
}

void SGX_ComputeShadowFactor_PSSM3(in float fDepth,
							in vec4 vSplitPoints,
							in vec4 lightPosition0,
							in sampler2DShadow shadowMap0,
							in vec4 lightPosition1,
							in sampler2DShadow shadowMap1,
							in vec4 lightPosition2,
							in sampler2DShadow shadowMap2,
							out float oShadowFactor)
{
	if (fDepth  <= vSplitPoints.x)
	{
        SGX_ShadowPCF4(shadowMap0, lightPosition0, oShadowFactor);
#ifdef DEBUG_PSSM
        pssm_lod_info.r = 1.0;
#endif
	}
	else if (fDepth <= vSplitPoints.y)
	{
        SGX_ShadowPCF4(shadowMap1, lightPosition1, oShadowFactor);
#ifdef DEBUG_PSSM
        pssm_lod_info.g = 1.0;
#endif
	}
	else
	{
        SGX_ShadowPCF4(shadowMap2, lightPosition2, oShadowFactor);
#ifdef DEBUG_PSSM
        pssm_lod_info.b = 1.0;
#endif
	}
}