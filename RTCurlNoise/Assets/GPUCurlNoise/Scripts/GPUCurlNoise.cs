using UnityEngine;
using System.Collections;
using System.Collections.Generic;



public class GPUCurlNoise : MonoBehaviour {
	
	public  int MaxParticles        = 1000;
	private int MAX_PARTICLES_LIMIT = 65536;
	
	private RenderTexture[] _positionBuffer;
	private RenderTexture[] _rotationBuffer;
	//private RenderTexture[] _accelerationBuffer;
	private RenderTexture[] _velocityBuffer;
	
	public Shader    KernelShader;
	public Shader    RenderShader;
	public Shader    DebugShader;
	
	private Material _kernelMaterial;
	private Material _renderMaterial;
	private Material _debugMaterial;
	
	private int _bufferWidth  = 1;
	private int _bufferHeight = 1;
	
	private int _pingPongIndex = 0;
	
	
	private Mesh _mesh;
	private bool _needsReset = true;
	
	
	// CurlNoise Params.
	public  float SpaceScale;
	public  float VelocityScale;
	public  float Offset;
	public  float DX;
	public  float RDX;

	public  float Speed;
	public  float SpeedLimit;
	
	public float AreaSize           = 5.0f;

	public Texture2D DebugTex;

	// Debug
	public bool IsDebug = false;
	
	
	void Start () {
		
		if (MaxParticles > MAX_PARTICLES_LIMIT) {
			MaxParticles = MAX_PARTICLES_LIMIT;
		}
		
		_bufferWidth  = Mathf.CeilToInt (Mathf.Sqrt (MaxParticles * 1.0f));
		_bufferHeight = _bufferWidth;
		if (_bufferWidth > 255)
			_bufferWidth = 255;
		if (_bufferHeight > 255) {
			_bufferHeight = 255;
		}
		
		MaxParticles = _bufferWidth * _bufferHeight;
		
		_init ();
		
	}
	
	void Update () {
		
		if (_needsReset) _init ();

		// Update Velocity.
		Offset += Time.deltaTime * 0.1f;
		
		if (SpaceScale <= 0.0f) {
			SpaceScale = 0.0001f;
		}
		
		if (VelocityScale <= 0.0f) {
			VelocityScale = 0.0001f;
		}
		
		float dx  = SpaceScale * 1e-3f;
		float rDx = 1f / dx;
		
		_kernelMaterial.SetFloat   ("_DX",            dx                 );
		_kernelMaterial.SetFloat   ("_RDX",           rDx                );
		_kernelMaterial.SetFloat   ("_Offset",        Offset             );
		_kernelMaterial.SetFloat   ("_SpaceScale",    SpaceScale         );
		_kernelMaterial.SetFloat   ("_VelocityScale", VelocityScale      );

		_kernelMaterial.SetFloat   ("_BufferWidth",   _bufferWidth );
		_kernelMaterial.SetFloat   ("_BufferHeight",  _bufferHeight);
		_kernelMaterial.SetFloat   ("_AreaSize",      AreaSize          );

		_kernelMaterial.SetTexture ("_PositionTex",   _positionBuffer [_pingPongIndex == 0 ? 0 : 1]);
		Graphics.Blit (null, _velocityBuffer [0], _kernelMaterial, 3); // update Velocity
	
		// Update Position.
		float dT = Time.deltaTime;
		_kernelMaterial.SetVector  ("_Config", new Vector4 (1.0f, SpeedLimit, Speed, dT));
		_kernelMaterial.SetTexture ("_VelocityTex", _velocityBuffer [_pingPongIndex == 0 ? 1 : 0]);
		_kernelMaterial.SetTexture ("_PositionTex", _positionBuffer [_pingPongIndex == 0 ? 0 : 1]);
		Graphics.Blit (null, _positionBuffer [_pingPongIndex == 0 ? 1 : 0], _kernelMaterial, 4); // update Position

		// Render
		_renderMaterial.SetTexture ("_PositionTex", _positionBuffer[_pingPongIndex == 0 ? 1 : 0]);
		//_renderMaterial.SetTexture ("_PositionTex", DebugTex);
		_renderMaterial.SetTexture ("_VelocityTex", _velocityBuffer[_pingPongIndex == 0 ? 1 : 0]);
		Graphics.DrawMesh (_mesh, transform.position, transform.rotation, _renderMaterial, 0);
		
		_pingPongIndex = _pingPongIndex == 0 ? 1 : 0;
	}
	
	void OnDestroy () {
		
		// Destroy Mesh
		if (_mesh != null) DestroyImmediate (_mesh);
		
		// Destroy Buffers
		if (_positionBuffer != null) for (int i = 0; i < _positionBuffer.Length; i++) DestroyImmediate (_positionBuffer [i]);
		if (_rotationBuffer != null) for (int i = 0; i < _rotationBuffer.Length; i++) DestroyImmediate (_rotationBuffer [i]);
		if (_velocityBuffer != null) for (int i = 0; i < _velocityBuffer.Length; i++) DestroyImmediate (_velocityBuffer [i]);
		
		// Destroy Materials
		if (_kernelMaterial != null) DestroyImmediate (_kernelMaterial);
		if (_renderMaterial != null) DestroyImmediate (_renderMaterial);
		if (_debugMaterial  != null) DestroyImmediate (_debugMaterial );
		
	}
	
	void _init () {
		
		if (_mesh == null) {
			_mesh = _createMesh ();
		}
		
		// Destroy Buffers
		if (_positionBuffer != null) for (int i = 0; i < _positionBuffer.Length; i++) DestroyImmediate (_positionBuffer [i]);
		if (_rotationBuffer != null) for (int i = 0; i < _rotationBuffer.Length; i++) DestroyImmediate (_rotationBuffer [i]);
		
		// Create Buffers
		_positionBuffer = new RenderTexture[2];
		_rotationBuffer = new RenderTexture[2];
		//_accelerationBuffer = new RenderTexture[2];
		_velocityBuffer = new RenderTexture[2];
		_positionBuffer[0] = _createBuffer ();
		_positionBuffer[1] = _createBuffer ();
		_rotationBuffer[0] = _createBuffer ();
		_rotationBuffer[1] = _createBuffer ();
		_velocityBuffer[0] = _createBuffer ();
		_velocityBuffer[1] = _createBuffer ();
		
		// Create Materials
		if (!_kernelMaterial) _kernelMaterial = _createMaterial (KernelShader);
		if (!_renderMaterial) _renderMaterial = _createMaterial (RenderShader);
		if (!_debugMaterial)  _debugMaterial  = _createMaterial (DebugShader);
		
		Texture2D buff = new Texture2D (_bufferWidth, _bufferHeight, TextureFormat.ARGB32, false);
		
		for (int x = 0; x < _bufferWidth; x++) {
			for (int y = 0; y < _bufferHeight; y++) {
				buff.SetPixel (x, y, new Color (Random.Range (0, 1.0f), Random.Range (0, 1.0f), Random.Range (0, 1.0f), 1.0f));
			}
		}
		buff.Apply ();
		//Graphics.Blit (buff, _positionBuffer[0]);
		//Graphics.Blit (buff, _positionBuffer[1]);

		_renderMaterial.SetTexture ("_PositionTex", _positionBuffer [0]);
		
		Graphics.Blit (null, _positionBuffer [0], _kernelMaterial, 0);
		_positionBuffer [1]     = _positionBuffer [0];
		
		Graphics.Blit (null, _rotationBuffer [0], _kernelMaterial, 1);
		_rotationBuffer [1]     = _rotationBuffer [0];

		Graphics.Blit (null, _velocityBuffer [0], _kernelMaterial, 2);
		_velocityBuffer [1]     = _velocityBuffer [0];

		_needsReset = false;
	}
	
	Mesh _createMesh () {
		
		Mesh mesh = new Mesh ();
		
		Vector3[] vertices = new Vector3[MaxParticles];
		Vector3[] normals  = new Vector3[MaxParticles];
		Vector2[] uvs      = new Vector2[MaxParticles];
		int[]     indices  = new int[MaxParticles];
		Color[] colors = new Color[MaxParticles];
		
		for (int i = 0; i < vertices.Length; i++) {
			vertices[i] = Random.insideUnitSphere;
			//vertices[i] = new Vector3 (
			//	Random.Range (-1.0f, 1.0f),
			//	Random.Range (-1.0f, 1.0f),
			//	Random.Range (-1.0f, 1.0f)
			//);
		}
		
		for (int i = 0; i < normals.Length; i++) {
			normals[i] = Vector3.up;
		}
		
		for (int i = 0; i < uvs.Length; i++) {
			float u = (float)(i % _bufferWidth) / _bufferWidth ;
			float v = (float)(i / _bufferHeight) / _bufferHeight;
			uvs[i] = new Vector2 (u, v);
		}
		
		for (int i = 0; i < indices.Length; i++) {
			indices[i] = i;
		}
		
		for (int i = 0; i < colors.Length; i++) {
			colors[i] = new Color(Random.Range (0, 1.0f), Random.Range (0, 1.0f), Random.Range (0, 1.0f), 1.0f);
		}
		
		mesh.vertices = vertices;
		mesh.normals = normals;
		mesh.uv = uvs;
		mesh.colors = colors;
		mesh.SetIndices (indices, MeshTopology.Points, 0);
		
		//mesh.RecalculateBounds ();
		//mesh.UploadMeshData (true);
		mesh.Optimize ();
		mesh.bounds = new Bounds(Vector3.zero, Vector3.one * 1000);
		mesh.hideFlags = HideFlags.DontSave;
		
		return mesh;
	}
	
	Material _createMaterial (Shader shader_) {
		Material m = new Material (shader_);
		m.hideFlags = HideFlags.DontSave;
		return m;
	}
	
	RenderTexture _createBuffer () {
		RenderTexture buffer = new RenderTexture (_bufferWidth, _bufferHeight, 0, RenderTextureFormat.ARGBFloat);
		buffer.hideFlags = HideFlags.DontSave;
		buffer.filterMode = FilterMode.Point;
		buffer.wrapMode = TextureWrapMode.Repeat;
		return buffer;
	}
	
	void _swapBuffer (ref RenderTexture[] buffers_) {
		RenderTexture temp = buffers_ [0];
		buffers_ [0] = buffers_ [1];
		buffers_ [1] = temp;
	}
	
	void OnGUI () {
		
		if (IsDebug && Event.current.type.Equals (EventType.Repaint) && _debugMaterial) {
			
			Rect r1 = new Rect(0,   0, 64, 64);
			Rect r2 = new Rect(0,  64, 64, 64);
			//Rect r3 = new Rect(0, 128, 64, 64);
			Rect r4 = new Rect(0, 192, 64, 64);
			
			if (_positionBuffer     != null && _positionBuffer.Length     > 0) Graphics.DrawTexture (r1, _positionBuffer[0],     _debugMaterial);
			if (_rotationBuffer     != null && _rotationBuffer.Length     > 0) Graphics.DrawTexture (r2, _rotationBuffer[0],     _debugMaterial);
			if (_velocityBuffer     != null && _velocityBuffer.Length     > 0) Graphics.DrawTexture (r4, _velocityBuffer[0],     _debugMaterial);
		}
		
	}
	
}
	