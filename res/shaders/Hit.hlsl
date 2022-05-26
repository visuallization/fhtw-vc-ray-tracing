#include "Common.hlsl"

struct STriVertex
{
	float3 vertex;
	float4 color;
};

StructuredBuffer<STriVertex> BTriVertex : register(t0);

[shader("closesthit")] 
void ClosestHit(inout HitInfo payload, Attributes attrib) 
{
	float3 barycentrics = float3(1.f - attrib.bary.x - attrib.bary.y, attrib.bary.x, attrib.bary.y);
	uint vertId = 3 * PrimitiveIndex();

    float3 hitColor = float3(0.7, 0.7, 0.7);

    switch (InstanceID())
    {
    case 0:
        hitColor = BTriVertex[vertId + 0].color * barycentrics.x + BTriVertex[vertId + 1].color * barycentrics.y + BTriVertex[vertId + 2].color * barycentrics.z;
        break;
    case 1:
        hitColor = BTriVertex[vertId + 1].color * barycentrics.x + BTriVertex[vertId + 1].color * barycentrics.y + BTriVertex[vertId + 2].color * barycentrics.z;
        break;
    case 2:
        hitColor = BTriVertex[vertId + 2].color * barycentrics.x + BTriVertex[vertId + 1].color * barycentrics.y + BTriVertex[vertId + 2].color * barycentrics.z;
        break;
    }

	payload.colorAndDistance = float4(hitColor, RayTCurrent());
}
