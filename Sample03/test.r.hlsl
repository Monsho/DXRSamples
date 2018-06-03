struct SceneCB
{
	float4x4	mtxProjToWorld;
	float4		camPos;
	float4		lightDir;
	float4		lightColor;
};

struct MyAttribute
{
	float3		normal;
};

struct Sphere
{
	float4		centerAndRadius;
	float4		color;
};

struct HitData
{
	float4 color;
};

RaytracingAccelerationStructure		Scene			: register(t0, space0);
StructuredBuffer<Sphere>			Spheres			: register(t1, space0);
RWTexture2D<float4>					RenderTarget	: register(u0);
ConstantBuffer<SceneCB>				cbScene			: register(b0);


[shader("raygeneration")]
void RayGenerator()
{
	// ピクセル中心座標をクリップ空間座標に変換
	uint2 index = DispatchRaysIndex();
	float2 xy = (float2)index + 0.5;
	float2 clipSpacePos = xy / DispatchRaysDimensions() * float2(2, -2) + float2(-1, 1);

	// クリップ空間座標をワールド空間座標に変換
	float4 worldPos = mul(float4(clipSpacePos, 0, 1), cbScene.mtxProjToWorld);

	// ワールド空間座標とカメラ位置からレイを生成
	worldPos.xyz /= worldPos.w;
	float3 origin = cbScene.camPos.xyz;
	float3 direction = normalize(worldPos.xyz - origin);

	// Let's レイトレ！
	RayDesc ray = { origin, 0.0f, direction, 10000.0f };
	HitData payload = { float4(0, 0, 0, 0) };
	TraceRay(Scene, RAY_FLAG_CULL_BACK_FACING_TRIANGLES, ~0, 0, 1, 0, ray, payload);

	// Write the raytraced color to the output texture.
	RenderTarget[index] = payload.color;
}

bool SolveQuadratic(in float a, in float b, in float c, out float t0, out float t1)
{
	float discr = b * b - 4 * a * c;
	if (discr < 0) return false;
	else if (discr == 0) t0 = t1 = -0.5 * b / a;
	else
	{
		float q = (b > 0) ?
			-0.5 * (b + sqrt(discr)) :
			-0.5 * (b - sqrt(discr));
		t0 = q / a;
		t1 = c / q;
	}

	return true;
}

bool IntersectToSphere(float3 s_center, float s_radius, float3 ray_origin, float3 ray_dir, out float t, out float3 normal)
{
	float t0, t1;

	float3 L = ray_origin - s_center;
	float a = dot(ray_dir, ray_dir);
	float b = 2 * dot(ray_dir, L);
	float c = dot(L, L) - s_radius * s_radius;
	
	if (!SolveQuadratic(a, b, c, t0, t1)) return false;

	if (t0 > 0 || t0 < t1)
		t = t0;
	else if (t1 > 0)
		t = t1;
	else
		return false;

	float3 p = ray_origin + ray_dir * t;
	normal = normalize(p - s_center);

	return true;
}

[shader("intersection")]
void IntersectionProcessor()
{
#if 1
	Sphere sphere = Spheres[PrimitiveIndex()];
	float3 w_origin = WorldRayOrigin();
	float3 w_dir = WorldRayDirection();
	float3 ray_origin = w_origin + w_dir * RayTMin();
	float3 ray_dir = w_dir * (RayTCurrent() - RayTMin());

	float Thit = 0.0;
	float3 normal;
	if (IntersectToSphere(sphere.centerAndRadius.xyz, sphere.centerAndRadius.w, ray_origin, ray_dir, Thit, normal))
	{
		MyAttribute attr;
		attr.normal = normal;
		ReportHit(Thit, 0, attr);
	}
#else
	MyAttribute attr;
	attr.normal = float3(PrimitiveIndex().xxx);
	ReportHit(RayTCurrent() * 0.5, 0, attr);
#endif
}

[shader("closesthit")]
void ClosestHitProcessor(inout HitData payload : SV_RayPayload, in MyAttribute attr : SV_IntersectionAttributes)
{
#if 1
	Sphere sphere = Spheres[PrimitiveIndex()];

	// 平行光源のライティング計算
	float NoL = saturate(dot(attr.normal, -cbScene.lightDir.xyz));
	float3 finalColor = sphere.color.rgb * cbScene.lightColor.rgb * NoL;

	payload.color = float4(finalColor, 1);
#else
	payload.color = float4(attr.normal, 1);
#endif
}

[shader("miss")]
void MissProcessor(inout HitData payload : SV_RayPayload)
{
	payload.color = float4(0, 0, 1, 1);
}

// EOF
