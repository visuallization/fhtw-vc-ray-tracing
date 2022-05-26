#include "Common.hlsl"

struct STriVertex
{
	float3 vertex;
	float4 color;
};

StructuredBuffer<STriVertex> BTriVertex : register(t0);


cbuffer Colors : register(b0)
{
	float3 A[3];
	float3 B[3];
	float3 C[3];
}

[shader("closesthit")] 
void ClosestHit(inout HitInfo payload, Attributes attrib) 
{
	float3 barycentrics = float3(1.f - attrib.bary.x - attrib.bary.y, attrib.bary.x, attrib.bary.y);
	
	int instanceID = InstanceID();

	float3 hitColor = float3(0.6, 0.7, 0.6);
	// Shade only the first 3 instances (triangles)
	if (instanceID < 3)
	{
		hitColor = A[instanceID] * barycentrics.x + B[instanceID] * barycentrics.y + C[instanceID] * barycentrics.z;
	}
	
	payload.colorAndDistance = float4(hitColor, RayTCurrent());
}
