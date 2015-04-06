// GPUFlocking/Kernels
// 
//
// Kernel 0 - initialize position.
// Kernel 1 - initialize rotation.
// Kernel 2 - initialize velocity.
// Kernel 3 - update Velocity.
// Kernel 4 - update Position.

Shader "GPUCurlNoise/Kernels"
{
	Properties
	{
		_MainTex            ("-", 2D    ) = "" {}
		_EmitterPos         ("-", Vector) = (0, 0, 0, 0)
        _EmitterSize        ("-", Vector) = (1, 1, 1, 0)
		_Config             ("-", Vector) = (1, 1, 0, 0) // (throttle, life, random seed, dT)
		_PositionTex        ("-", 2D    ) = "" {}
		_AccelerationTex    ("-", 2D    ) = "" {}
		_VelocityTex        ("-", 2D    ) = "" {}
		_BufferWidth        ("-", Float ) = 1.0
		_BufferHeight       ("-", Float ) = 1.0
	
		_AreaSize           ("-", Float ) = 5.0
		
		_DX            ("DX",               Float) = 0.0
		_RDX           ("RDX",              Float) = 0.0
		_Offset        ("Offset",           Float) = 0.0
		_SpaceScale    ("SpaceScale",       Float) = 0.0
		_VelocityScale ("VelocityScale",    Float) = 0.0
	}
	
	CGINCLUDE
	
	#include "UnityCG.cginc"
	//#include "ClassicNoise3D.cginc"
	#include "SimplexNoise.cginc"
	
	#define PI2 6.2831830718
	
	sampler2D _MainTex;
	
	uniform float3    _EmitterSize;
	uniform float3    _EmitterPos;
	uniform float4    _Config;
	
	uniform sampler2D _PositionTex;
	float4 _PositionTex_TexelSize;
	uniform sampler2D _VelocityTex;
	float4 _VelocityTex_TexelSize;
	
	uniform float     _BufferWidth;
	uniform float     _BufferHeight;
	
	uniform float     _DX;
	uniform float     _RDX;
	uniform float     _Offset;
	uniform float     _SpaceScale;
	uniform float     _VelocityScale;
	
	uniform float     _AreaSize;
	
	float3 limit (float3 vec, float max) {
		float lengthSquared = (vec.x*vec.x + vec.y*vec.y + vec.z*vec.z);
		if (lengthSquared > max*max && lengthSquared > 0) {
			float ratio = max / (float)sqrt(lengthSquared);
			vec.x *= ratio;
			vec.y *= ratio;
			vec.z *= ratio;
		}
		return vec;
	}
	
	float4 limit (float4 vec, float max) {
		float lengthSquared = (vec.x*vec.x + vec.y*vec.y + vec.z*vec.z + vec.w*vec.w);
		if (lengthSquared > max*max && lengthSquared > 0) {
			float ratio = max / (float)sqrt(lengthSquared);
			vec.x *= ratio;
			vec.y *= ratio;
			vec.z *= ratio;
			vec.w *= ratio;
		}
		return vec;
	}
	
	// PRNG function.
    float nrand(float2 uv, float salt)
    {
        uv += float2(salt, _Config.y);
        return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
    }
	
	// Quaternion multiplication.
    // http://mathworld.wolfram.com/Quaternion.html
    float4 qmul(float4 q1, float4 q2)
    {
        return float4(
            q2.xyz * q1.w + q1.xyz * q2.w + cross(q1.xyz, q2.xyz),
            q1.w * q2.w - dot(q1.xyz, q2.xyz)
        );
    }
	
    // Generate a new particle.
    float4 new_particle_position(float2 uv)
    {
        float t = _Time.x;

        // Random position.
        float3 p = float3(nrand(uv, t + 1), nrand(uv, t + 2), nrand(uv, t + 3));
        p = (p - (float3)0.5) * _EmitterSize + _EmitterPos;

        // Throttling: discard the particle emission by adding offset.
        float4 offs = float4(1e10, 1e10, 1e10, -1) * (uv.x > _Config.x);

        return float4(p, 1) + offs;
    }
    
    float4 new_particle_rotation(float2 uv)
    {
        // Random scale factor.
        float s = nrand(uv, 5);

        // Uniform random unit quaternion.
        // http://tog.acm.org/resources/GraphicsGems/gemsiii/urot.c
        float r = nrand(uv, 6);
        float r1 = sqrt(1.0 - r);
        float r2 = sqrt(r);
        float t1 = PI2 * nrand(uv, 7);
        float t2 = PI2 * nrand(uv, 8);

        // To get the quaternion, 4th component should be 'cos(t2) * r2',
        // but we replace it with the scale factor.
        return float4(sin(t1) * r1, cos(t1) * r1, sin(t2) * r2, s);
    }
    
    float4 new_particle_acceleration(float2 uv)
    {
        float4 acc = float4(0,0,0,0);
      
        return acc;
    }
    
    float4 new_particle_velocity(float2 uv) {
   		float t = _Time.x;

        // Random position.
        float3 vel = float3(nrand(uv, t + 1), nrand(uv, t + 2), nrand(uv, t + 3));
        vel = (vel - (float3)0.5);

        return float4(vel, 1);// + offs;
    }
    
    
    // Kernel 0 - initialize position.
    float4 frag_init_position(v2f_img i) : SV_Target 
    {
        return new_particle_position(i.uv);
    }
    
    // Kernel 1 - initialize rotation.
    float4 frag_init_rotation(v2f_img i) : SV_Target 
    {
        return new_particle_rotation(i.uv);
    }
    
    // Kernel 2 - initialize velocity.
    float4 frag_init_velocity(v2f_img i) : SV_Target
    {
    	//return new_particle_velocity(i.uv);
    	return float4(0,0,0,0);
    }
    
    // Kernel 3 - update Velocity.
    float4 frag_update_velocity(v2f_img i) : SV_Target
    {	
    
    	float3 pos = tex2D (_PositionTex, i.uv.xy).rgb;
		
		float3 vel = float3 (
			0.5 * _RDX * (
				(simplexNoise(float3(pos.x, pos.y + _DX, pos.z + _Offset)) - simplexNoise(float3(pos.x, pos.y - _DX, pos.z + _Offset)))
			  - (simplexNoise(float3(pos.x, pos.y + _Offset, pos.z + _DX)) - simplexNoise(float3(pos.x, pos.y + _Offset, pos.z - _DX)))),
			0.5 * _RDX * (
				(simplexNoise(float3(pos.x + _Offset, pos.y, pos.z + _DX)) - simplexNoise(float3(pos.x + _Offset, pos.y, pos.z - _DX)))
			  - (simplexNoise(float3(pos.x + _DX, pos.y, pos.z + _Offset)) - simplexNoise(float3(pos.x - _DX, pos.y, pos.z + _Offset)))),
			0.5 * _RDX * (
				(simplexNoise(float3(pos.x + _DX, pos.y + _Offset, pos.z)) - simplexNoise(float3(pos.x - _DX, pos.y + _Offset, pos.z)))
			  - (simplexNoise(float3(pos.x + _Offset, pos.y + _DX, pos.z)) - simplexNoise(float3(pos.x + _Offset, pos.y - _DX, pos.z))))
		);
								
		return half4(_VelocityScale * vel.xyz, 1.0);
		
    }
    
    // Kernel 4 - update Position.
    float4 frag_update_position(v2f_img i) : SV_Target
    {
    	float4 pos = tex2D(_PositionTex, i.uv);
    	float4 vel = tex2D(_VelocityTex, i.uv);
    	
    	vel = limit (vel * _Config.z, _Config.y);
    	
    	pos += vel * _Config.w;
    	
    	
    	
    	float size = _AreaSize;
    	
    	if (pos.x < -size) {
    		pos.x = size;
    	}
    	if (pos.x > size) {
    		pos.x = -size;
    	}
    	if (pos.y < -size) {
    		pos.y = size;
    	}
    	if (pos.y > size) {
    		pos.y = -size;
    	}
    	if (pos.z < -size) {
    		pos.z = size;
    	}
    	if (pos.z > size) {
    		pos.z = -size;
    	}
    	
    	return pos;
    }
    
	
	ENDCG
	
	SubShader {
		
		// Kernel 0 - initialize position.
		Pass {
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0
			#pragma glsl
			#pragma vertex vert_img
			#pragma fragment frag_init_position
			ENDCG
		}
		
		// Kernel 1 - initialize rotation.
		Pass {
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0
			#pragma glsl
			#pragma vertex vert_img
			#pragma fragment frag_init_rotation
			ENDCG
		}
		
		// Kernel 2 - initialize velocity.
		Pass {
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0
			#pragma glsl
			#pragma vertex vert_img
			#pragma fragment frag_init_velocity
			ENDCG
		}
		
		// Kernel 3 - update Velocity.
		Pass {
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0
			#pragma glsl
			#pragma vertex vert_img
			#pragma fragment frag_update_velocity
			ENDCG
		}
		
		// Kernel 4 - update Position.
		Pass {
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0
			#pragma glsl
			#pragma vertex vert_img
			#pragma fragment frag_update_position
			ENDCG
		}
					
	} 
	
}
