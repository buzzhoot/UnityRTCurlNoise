Shader "GPUParticleSystem/ParticleRender" {
	Properties {
		_PositionTex		("Position Reference Texture", 	2D)	= "black" {}
		_ColorReferenceTex          ("Color Reference Texture",     2D) = "white" {}
		_Color		("Color",		 Color) = (1,1,1,1)
		_Intensity ("Intensity", Float) = 1.0
	}

	Category {
    	Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }
		//Blend SrcAlpha OneMinusSrcAlpha
		Blend One One
		AlphaTest Greater .01
		ColorMask RGB
		Cull Off Lighting Off ZWrite Off
		BindChannels {
			Bind "Color", color
			Bind "Vertex", vertex
			Bind "TexCoord", texcoord
		}
    	
		SubShader {
			Pass{
				LOD 200
		
				CGPROGRAM
					#pragma glsl
					#pragma target 3.0
					#pragma vertex vert
					#pragma fragment frag
					#pragma fragmentoption ARB_precision_hint_fastest
					#pragma multi_compile_particles
					
					#pragma exclude_renderers gles
					
					#include "UnityCG.cginc"

					
					struct appdata_t {
						float4 vertex   : POSITION;
						fixed4 color    : COLOR;
						float2 texcoord : TEXCOORD0;
					};
					
					struct v2f {
						float4	vertex   : POSITION;
						float4  color    : COLOR;
						float2  texcoord : TEXCOORD1;
					};

					uniform sampler2D 	_PositionTex;
					uniform float4		_Color;
					uniform float       _Intensity;
					uniform sampler2D   _ColorReferenceTex;
					
					float4 _MainTex_ST;
					float4 _PositionTex_ST;
					
					// Vertex Shader ------------------------------------------------
					float rand(float2 co){
    				return frac(sin(dot(co.xy ,float2(12.98,78.233))) * 43758.5453);
					}

					v2f vert (appdata_t v)
					{
						v2f o;
						//#if !defined(SHADER_API_OPENGL)
						fixed4 pos  = tex2Dlod (_PositionTex, float4(v.texcoord.xy,0,0));
						//v.vertex.xyz = posTex.xyz;
						v.vertex.x = pos.x;
						v.vertex.y = pos.y;
						v.vertex.z = pos.z;
						//#endif
						o.vertex   = mul(UNITY_MATRIX_MVP, v.vertex);
						o.color    = v.color;
						o.texcoord = TRANSFORM_TEX(v.texcoord, _PositionTex);
						
						return o;
					}

					// Fragment Shader -----------------------------------------------
					fixed4 frag (v2f input) : COLOR {
						fixed4 tex  = tex2D (_ColorReferenceTex, input.texcoord.xy);
						fixed4 col 	= _Color; //* _SpriteTex.Sample(sampler_SpriteTex, input.tex0);
						return fixed4 (tex.xyz, 1.0) * _Intensity;
					}
				ENDCG
			}
		}	 
	}
}
