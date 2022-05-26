#include "Common.hlsl"

struct STriVertex
{
	float3 vertex;
	float4 color;
};

StructuredBuffer<STriVertex> BTriVertex : register(t0);

struct MyStructColor
{
	float4 a;
	float4 b;
	float4 c;
};

cbuffer Colors : register(b0)
{
	MyStructColor Tint[3];
}

[shader("closesthit")] 
void ClosestHit(inout HitInfo payload, Attributes attrib) 
{
	float3 barycentrics = float3(1.f - attrib.bary.x - attrib.bary.y, attrib.bary.x, attrib.bary.y);
	
	int instanceID = InstanceID();
	
	float3 hitColor = Tint[instanceID].a * barycentrics.x + Tint[instanceID].b * barycentrics.y + Tint[instanceID].c * barycentrics.z;

	payload.colorAndDistance = float4(hitColor, RayTCurrent());
}
