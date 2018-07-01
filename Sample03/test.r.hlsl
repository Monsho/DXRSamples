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

struct AABB
{
	float3		aabbMin, aabbMax;
	float4		color;
};

struct Instance
{
	float4x4	mtxLocalToWorld;
	float4x4	mtxWorldToLocal;
	float4		color;
};

struct HitData
{
	float4 color;
};

RaytracingAccelerationStructure		Scene			: register(t0, space0);
StructuredBuffer<Instance>			Instances		: register(t1, space0);
StructuredBuffer<AABB>				InnerBoxAABBs	: register(t2, space0);
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
	HitData payload = { float4(0, 0, 0, 1) };
	TraceRay(Scene, RAY_FLAG_CULL_BACK_FACING_TRIANGLES, ~0, 0, 1, 0, ray, payload);

	// Write the raytraced color to the output texture.
	RenderTarget[index] = payload.color;
}

bool SolveQuadraticEqn(float a, float b, float c, out float x0, out float x1)
{
	float discr = b * b - 4 * a * c;
	if (discr < 0) return false;
	else if (discr == 0) x0 = x1 = -0.5 * b / a;
	else {
		float q = (b > 0) ?
			-0.5 * (b + sqrt(discr)) :
			-0.5 * (b - sqrt(discr));
		x0 = q / a;
		x1 = c / q;
	}
	if (x0 > x1)
	{
		float tmp = x0;
		x0 = x1;
		x1 = tmp;
	}

	return true;
}

float3 CalculateNormalForARaySphereHit(float3 s_center, float3 ray_origin, float3 ray_dir, float thit)
{
	float3 hitPosition = ray_origin + thit * ray_dir;
	return normalize(hitPosition - s_center);
}

bool SolveRaySphereIntersectionEquation(float3 s_center, float s_radius, float3 ray_origin, float3 ray_dir, out float tmin, out float tmax)
{
	float3 L = ray_origin - s_center;
	float a = dot(ray_dir, ray_dir);
	float b = 2 * dot(ray_dir, L);
	float c = dot(L, L) - s_radius * s_radius;
	return SolveQuadraticEqn(a, b, c, tmin, tmax);
}

bool IntersectToSphere(float3 s_center, float s_radius, float3 ray_origin, float3 ray_dir, out float t, out float3 normal)
{
	float t0, t1;
	if (!SolveRaySphereIntersectionEquation(s_center, s_radius, ray_origin, ray_dir, t0, t1))
		return false;

	if ((RayTMin() < t0 && t0 < RayTCurrent()))
		t = t0;
	else if ((RayTMin() < t1 && t1 < RayTCurrent()))
		t = t1;
	else
		return false;
	normal = CalculateNormalForARaySphereHit(s_center, ray_origin, ray_dir, t);
	return true;
}

bool IntersectToAABBDetail(float3 aabb[2], float3 ray_origin, float3 ray_dir, out float tmin, out float tmax)
{
	float3 tmin3, tmax3;
	int3 sign3 = ray_dir > 0;
	tmin3.x = (aabb[1 - sign3.x].x - ray_origin.x) / ray_dir.x;
	tmax3.x = (aabb[sign3.x].x - ray_origin.x) / ray_dir.x;

	tmin3.y = (aabb[1 - sign3.y].y - ray_origin.y) / ray_dir.y;
	tmax3.y = (aabb[sign3.y].y - ray_origin.y) / ray_dir.y;

	tmin3.z = (aabb[1 - sign3.z].z - ray_origin.z) / ray_dir.z;
	tmax3.z = (aabb[sign3.z].z - ray_origin.z) / ray_dir.z;

	tmin = max(max(tmin3.x, tmin3.y), tmin3.z);
	tmax = min(min(tmax3.x, tmax3.z), tmax3.z);

	return tmax > tmin && tmax >= RayTMin() && tmin <= RayTCurrent();
}

bool IntersectToAABB(float3 aabbMin, float3 aabbMax, float3 ray_origin, float3 ray_dir, out float t, out float3 normal)
{
	float tmin, tmax;
	float3 aabb[2] = { aabbMin, aabbMax };
	if (IntersectToAABBDetail(aabb, ray_origin, ray_dir, tmin, tmax))
	{
		t = tmin >= RayTMin() ? tmin : tmax;

		// Set a normal to the normal of a face the hit point lays on.
		float3 hitPosition = ray_origin + t * ray_dir;
		float3 distanceToBounds[2] = {
			abs(aabb[0] - hitPosition),
			abs(aabb[1] - hitPosition)
		};
		const float eps = 0.0001;
		if (distanceToBounds[0].x < eps) normal = float3(-1, 0, 0);
		else if (distanceToBounds[0].y < eps) normal = float3(0, -1, 0);
		else if (distanceToBounds[0].z < eps) normal = float3(0, 0, -1);
		else if (distanceToBounds[1].x < eps) normal = float3(1, 0, 0);
		else if (distanceToBounds[1].y < eps) normal = float3(0, 1, 0);
		else if (distanceToBounds[1].z < eps) normal = float3(0, 0, 1);

		return true;
	}
	return false;
}

[shader("intersection")]
void IntersectionSphereProcessor()
{
	Instance instance = Instances[InstanceIndex()];
	float3 w_origin = WorldRayOrigin();
	float3 w_dir = WorldRayDirection();
	float3 ray_origin = w_origin + w_dir * RayTMin();
	float3 ray_dir = w_dir;

	float Thit = 0.0;
	float3 normal;
	float3 center = instance.mtxLocalToWorld._m30_m31_m32;
	float radius = instance.mtxLocalToWorld._m00;
	if (IntersectToSphere(center, radius, ray_origin, ray_dir, Thit, normal))
	{
		MyAttribute attr;
		attr.normal = normal;
		ReportHit(Thit, 0, attr);
	}
}

[shader("intersection")]
void IntersectionInnerBoxProcessor()
{
	AABB aabb = InnerBoxAABBs[PrimitiveIndex()];
	float3 w_origin = WorldRayOrigin();
	float3 w_dir = WorldRayDirection();
	float3 ray_origin = w_origin + w_dir * RayTMin();
	float3 ray_dir = w_dir;

	float Thit = 0.0;
	float3 normal;
	if (IntersectToAABB(aabb.aabbMin, aabb.aabbMax, ray_origin, ray_dir, Thit, normal))
	{
		MyAttribute attr;
		attr.normal = normal;
		ReportHit(Thit, 0, attr);
	}
}

[shader("closesthit")]
void ClosestHitSphereProcessor(inout HitData payload : SV_RayPayload, in MyAttribute attr : SV_IntersectionAttributes)
{
	Instance instance = Instances[InstanceIndex()];

	float3 lightDir = normalize(-cbScene.lightDir.xyz);

	// シャドウチェック
	float shadow = 1.0;
	{
		float3 origin = WorldRayOrigin() + WorldRayDirection() * RayTCurrent();
		RayDesc ray = { origin, 1e-4, lightDir, 10000.0f };
		HitData shadow_payload = { float4(0, 0, 0, 0) };
		TraceRay(Scene, RAY_FLAG_CULL_BACK_FACING_TRIANGLES | RAY_FLAG_ACCEPT_FIRST_HIT_AND_END_SEARCH, ~0, 1, 1, 1, ray, shadow_payload);
		shadow = shadow_payload.color.x;
	}

	// 平行光源のライティング計算
	float NoL = saturate(dot(attr.normal, lightDir));
	float3 finalColor = instance.color.rgb * cbScene.lightColor.rgb * (NoL * shadow + 0.2);

#if 0
	// 反射
	if (payload.color.a > 0)
	{
		float3 origin = WorldRayOrigin() + WorldRayDirection() * RayTCurrent();
		float3 reflection = dot(attr.normal, -WorldRayDirection()) * 2.0 * attr.normal + WorldRayDirection();
		RayDesc ray = { origin, 1e-5, reflection, 10000.0f };
		HitData refl_payload = { float4(0, 0, 0, 0) };
		TraceRay(Scene, RAY_FLAG_CULL_BACK_FACING_TRIANGLES, ~0, 0, 1, 2, ray, refl_payload);

		NoL = saturate(dot(attr.normal, reflection));
		finalColor += instance.color.rgb * refl_payload.color.rgb * NoL;
	}
#endif

	payload.color = float4(finalColor, 1);
}

[shader("closesthit")]
void ClosestHitInnerBoxProcessor(inout HitData payload : SV_RayPayload, in MyAttribute attr : SV_IntersectionAttributes)
{
	AABB aabb = InnerBoxAABBs[PrimitiveIndex()];

	float3 lightDir = normalize(-cbScene.lightDir.xyz);

	// シャドウチェック
	float shadow = 1.0;
	{
		float3 origin = WorldRayOrigin() + WorldRayDirection() * RayTCurrent();
		RayDesc ray = { origin, 1e-4, lightDir, 10000.0f };
		HitData shadow_payload = { float4(0, 0, 0, 0) };
		TraceRay(Scene, RAY_FLAG_CULL_BACK_FACING_TRIANGLES | RAY_FLAG_ACCEPT_FIRST_HIT_AND_END_SEARCH, ~0, 1, 1, 1, ray, shadow_payload);
		shadow = shadow_payload.color.x;
	}

	// 平行光源のライティング計算
	float NoL = saturate(dot(attr.normal, lightDir));
	float3 finalColor = aabb.color.rgb * cbScene.lightColor.rgb * (NoL * shadow + 0.2);

	// 反射
	if (payload.color.a > 0)
	{
		float3 origin = WorldRayOrigin() + WorldRayDirection() * RayTCurrent();
		float3 reflection = dot(attr.normal, -WorldRayDirection()) * 2.0 * attr.normal + WorldRayDirection();
		RayDesc ray = { origin, 1e-5, reflection, 10000.0f };
		HitData refl_payload = { float4(0, 0, 0, 0) };
		TraceRay(Scene, RAY_FLAG_CULL_BACK_FACING_TRIANGLES, ~0, 0, 1, 2, ray, refl_payload);

		NoL = saturate(dot(attr.normal, reflection));
		finalColor += aabb.color.rgb * refl_payload.color.rgb * NoL;
	}

	payload.color = float4(finalColor, 1);
}

[shader("closesthit")]
void ClosestHitShadowProcessor(inout HitData payload : SV_RayPayload, in MyAttribute attr : SV_IntersectionAttributes)
{
	payload.color = float4(0, 0, 0, 1);
}

[shader("miss")]
void MissProcessor(inout HitData payload : SV_RayPayload)
{
	payload.color = float4(0, 0, 1, 1);
}

[shader("miss")]
void MissShadowProcessor(inout HitData payload : SV_RayPayload)
{
	payload.color = float4(1, 1, 1, 1);
}

[shader("miss")]
void MissReflectionProcessor(inout HitData payload : SV_RayPayload)
{
	payload.color = float4(0, 0, 0, 1);
}

// EOF
