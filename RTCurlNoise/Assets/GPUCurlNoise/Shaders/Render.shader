Shader "GPUParticleSystem/ParticleRender" {
	Properties {
		_PositionTex ("Position Buffer", 2D) = "" {}
		_VelocityTex ("Velocity Buffer", 2D) = "" {}
	}

	Category {
    	Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }
		Blend SrcAlpha OneMinusSrcAlpha
		//Blend One One
		Cull Off Lighting Off ZWrite Off
		
		SubShader {
			Pass{
				LOD 200
		
				CGPROGRAM
					#pragma glsl
					#pragma target   3.0
					#pragma vertex   vert
					#pragma fragment frag
					#include "UnityCG.cginc"

					
					struct appdata_t {
						float4 vertex   : POSITION;
						fixed4 color    : COLOR;
						float2 texcoord : TEXCOORD0;
					};
					
					struct v2f {
						float4	vertex   : POSITION;
						float4  color    : COLOR;
						//float2  texcoord : TEXCOORD1;
					};

					uniform sampler2D 	_PositionTex;
					float4 _PositionTex_ST;
					uniform sampler2D 	_VelocityTex;
					float4 _VelocityTex_ST;
					
					// Vertex Shader ------------------------------------------------
					v2f vert (appdata_t v)
					{
						v2f o;
						//#if !defined(SHADER_API_OPENGL)
						fixed4 pos  = tex2Dlod (_PositionTex, float4(v.texcoord.xy, 0, 0));
						v.vertex.x = pos.x;
						v.vertex.y = pos.y;
						v.vertex.z = pos.z;
						//#endif
						o.vertex   = mul(UNITY_MATRIX_MVP, v.vertex);
						//o.color    = v.color;
						o.color    = tex2Dlod (_VelocityTex, float4(v.texcoord.xy, 0, 0)) * 2.5;
						//o.texcoord = TRANSFORM_TEX(v.texcoord, _PositionTex);
						
						return o;
					}

					// Fragment Shader -----------------------------------------------
					fixed4 frag (v2f input) : COLOR {
						return input.color;
					}
				ENDCG
			}
		}	 
	}
}
