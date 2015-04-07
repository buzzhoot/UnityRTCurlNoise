Shader "GPUParticleSystem/ParticleRender" {
	Properties {
		_PositionTex ("Position Buffer", 2D) = "" {}
		_VelocityTex ("Velocity Buffer", 2D) = "" {}
	}
	
	CGINCLUDE
	#include "UnityCG.cginc"
	
	struct appdata_t {
		float4 vertex   : POSITION;
		fixed4 color    : COLOR;
		float2 texcoord : TEXCOORD0;
	};
	
	struct v2f {
		float4	vertex   : POSITION;
		float4  color    : COLOR;
	};
	
	uniform sampler2D 	_PositionTex;
	float4 _PositionTex_ST;
	uniform sampler2D 	_VelocityTex;
	float4 _VelocityTex_ST;
	
	// Vertex Shader ------------------------------------------------
	v2f vert (appdata_t v)
	{
		v2f o;
		fixed4 pos  = tex2Dlod (_PositionTex, float4(v.texcoord.xy, 0, 0));
		v.vertex.x = pos.x;
		v.vertex.y = pos.y;
		v.vertex.z = pos.z;
		o.vertex   = mul(UNITY_MATRIX_MVP, v.vertex);
		o.color    = tex2Dlod (_VelocityTex, float4(v.texcoord.xy, 0, 0)) * 2.5;
		
		return o;
	}

	// Fragment Shader -----------------------------------------------
	fixed4 frag (v2f input) : COLOR {
		return input.color;
	}
	
	ENDCG

	SubShader {
		Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }
		Pass{
			Blend SrcAlpha OneMinusSrcAlpha
			Cull Off Lighting Off ZWrite Off
			CGPROGRAM
			#pragma target 3.0
            #pragma glsl
            #pragma vertex vert
            #pragma fragment frag
			ENDCG
		}
	}
}
