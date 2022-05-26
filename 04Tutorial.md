# DXR Tutorial Extra : Per Instance Data
Welcome to the next section of the tutorial. If you miss the first tutorial, it is [here](/rtx/raytracing/dxr/DX12-Raytracing-tutorial-Part-1)
The bases of this tutorial starts at the end of the previous one.
You can download the entire project [here](/rtx/raytracing/dxr/tutorial/Files/dxr_tutorial.zip)
This tutorial covers the creation of object instances, each having its own shaders and resources. In order to see all the objects created
in this tutorial, we strongly advise [adding a perspective camera](dxr_tutorial_extra_perspective).
We will create more instances of the triangle, each of which uses its own vertex colors provided by constant buffers. We also create a plane,
which uses a constant buffer as well as a specific shader.

# Adding More Instances
Adding more instances of the triangle is fairly simple, as it only requires adding those in the top-level acceleration structure.

## CreateAccelerationStructures
In `CreateAccelerationStructures`, modify the instance list to create 3 instances instead of one, each with its
own transform matrix.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// #DXR Extra: Per-Instance Data
// 3 instances of the triangle
m_instances = {
    {bottomLevelBuffers.pResult, XMMatrixIdentity()},
    {bottomLevelBuffers.pResult, XMMatrixTranslation(-.6f, 0, 0)},
    {bottomLevelBuffers.pResult, XMMatrixTranslation(.6f, 0, 0)}
};

CreateTopLevelAS(m_instances);
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
![](/sites/default/files/pictures/2018/dx12_rtx_tutorial/Extra/3Triangles.png)

## Hit.hlsl
In the Hit program, DXR provides the built-in `InstanceID()` function, which returns the ID we have
passed in the third argument of `AddInstance` in `CreateTopLevelAS`.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// #DXR Extra: Per-Instance Data
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
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
![](/sites/default/files/pictures/2018/dx12_rtx_tutorial/Extra/3TrianglesId.png)

# Adding a Plane
We also add the creation of the vertex buffer for the plane, along with the view on the buffer for rasterization:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
// #DXR Extra: Per-Instance Data
ComPtr<ID3D12Resource> m_planeBuffer;
D3D12_VERTEX_BUFFER_VIEW m_planeBufferView;
void CreatePlaneVB();
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
At the end of the source file, add the vertex buffer creation code:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
//-----------------------------------------------------------------------------
//
// Create a vertex buffer for the plane
//
// #DXR Extra: Per-Instance Data
void D3D12HelloTriangle::CreatePlaneVB() {
	// Define the geometry for a plane. 
	Vertex planeVertices[] = {
		{{-1.5f, -.8f, 01.5f}, {1.0f, 1.0f, 1.0f, 1.0f}}, // 0 
		{{-1.5f, -.8f, -1.5f}, {1.0f, 1.0f, 1.0f, 1.0f}}, // 1 
		{{01.5f, -.8f, 01.5f}, {1.0f, 1.0f, 1.0f, 1.0f}}, // 2 
		{{01.5f, -.8f, 01.5f}, {1.0f, 1.0f, 1.0f, 1.0f}}, // 2 
		{{-1.5f, -.8f, -1.5f}, {1.0f, 1.0f, 1.0f, 1.0f}}, // 1 
		{{01.5f, -.8f, -1.5f}, {1.0f, 1.0f, 1.0f, 1.0f}} // 4 
	};
	const UINT planeBufferSize = sizeof(planeVertices);

	// Note: using upload heaps to transfer static data like vert buffers is not 
	// recommended. Every time the GPU needs it, the upload heap will be 
	// marshalled over. Please read up on Default Heap usage. An upload heap is 
	// used here for code simplicity and because there are very few verts to 
	// actually transfer. 
	CD3DX12_HEAP_PROPERTIES heapProperty = CD3DX12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_UPLOAD);
	CD3DX12_RESOURCE_DESC bufferResource = CD3DX12_RESOURCE_DESC::Buffer(planeBufferSize);
	ThrowIfFailed(m_device->CreateCommittedResource(&heapProperty, D3D12_HEAP_FLAG_NONE, &bufferResource, D3D12_RESOURCE_STATE_GENERIC_READ, nullptr, IID_PPV_ARGS(&m_planeBuffer))); 

	// Copy the triangle data to the vertex buffer. 
	UINT8* pVertexDataBegin;
	CD3DX12_RANGE readRange(0, 0);

	// We do not intend to read from this resource on the CPU. 
	ThrowIfFailed(m_planeBuffer->Map(0, &readRange, reinterpret_cast<void**>(&pVertexDataBegin)));
	memcpy(pVertexDataBegin, planeVertices, sizeof(planeVertices));
	m_planeBuffer->Unmap(0, nullptr);

	// Initialize the vertex buffer view. 
	m_planeBufferView.BufferLocation = m_planeBuffer->GetGPUVirtualAddress();
	m_planeBufferView.StrideInBytes = sizeof(Vertex);
	m_planeBufferView.SizeInBytes = planeBufferSize;
}
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## LoadAssets
The plane buffers are added in `LoadAssets`, immediately after initializing `m_vertexBufferView`:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
// #DXR - Per Instance
// Create a vertex buffer for a ground plane, similarly to the triangle definition above
CreatePlaneVB();
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## CreateAccelerationStructures
After creating the bottom-level AS of the triangle, add the creation of the BLAS of the plane:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
// #DXR Extra: Per-Instance Data
AccelerationStructureBuffers planeBottomLevelBuffers = CreateBottomLevelAS({{m_planeBuffer.Get(), 6}});
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Then we add a reference to the bottom-level AS of the plane in the instance list:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
// 3 instances of the triangle + a plane
m_instances = {
    {bottomLevelBuffers.pResult, XMMatrixIdentity()},
    {bottomLevelBuffers.pResult, XMMatrixTranslation(.6f, 0, 0)},
    {bottomLevelBuffers.pResult, XMMatrixTranslation(-.6f, 0, 0)},
    {planeBottomLevelBuffers.pResult, XMMatrixTranslation(0, 0, 0)}
};
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## PopulateCommandList
To be visible in the rasterization path, we add the following lines after the `DrawInstanced` call for the triangle:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
// #DXR Extra: Per-Instance Data
// In a way similar to triangle rendering, rasterize the plane
m_commandList->IASetVertexBuffers(0, 1, &m_planeBufferView);
m_commandList->DrawInstanced(6, 1, 0, 0);
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!!! Warning This is enough to add the plane, but we cannot see it!<br/> Add a [perspective camera](dxr_tutorial_extra_perspective) to see it.
![Adding a plane in raytracing mode](/sites/default/files/pictures/2018/dx12_rtx_tutorial/Extra/3TrianglesPlane.png)

# Using a Constant Buffer
Constant buffer are used to send read-only data from the CPU side to the shaders. Here we will create
a constant buffer containing color data, used in the shader to alter the vertex colors.
Add the declarations in the header file:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
// #DXR Extra: Per-Instance Data
void D3D12HelloTriangle::CreateGlobalConstantBuffer();
ComPtr<ID3D12Resource> m_globalConstantBuffer;
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Add the buffer allocation method at the end of the source file.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
//-----------------------------------------------------------------------------
//
// #DXR Extra: Per-Instance Data
void D3D12HelloTriangle::CreateGlobalConstantBuffer()
{ // Due to HLSL packing rules, we create the CB with 9 float4 (each needs to start on a 16-byte // boundary) XMVECTOR bufferData[] = { // A XMVECTOR{1.0f, 0.0f, 0.0f, 1.0f}, XMVECTOR{0.7f, 0.4f, 0.0f, 1.0f}, XMVECTOR{0.4f, 0.7f, 0.0f, 1.0f}, // B XMVECTOR{0.0f, 1.0f, 0.0f, 1.0f}, XMVECTOR{0.0f, 0.7f, 0.4f, 1.0f}, XMVECTOR{0.0f, 0.4f, 0.7f, 1.0f}, // C XMVECTOR{0.0f, 0.0f, 1.0f, 1.0f}, XMVECTOR{0.4f, 0.0f, 0.7f, 1.0f}, XMVECTOR{0.7f, 0.0f, 0.4f, 1.0f}, }; // Create our buffer m_globalConstantBuffer = nv_helpers_dx12::CreateBuffer( m_device.Get(), sizeof(bufferData), D3D12_RESOURCE_FLAG_NONE, D3D12_RESOURCE_STATE_GENERIC_READ, nv_helpers_dx12::kUploadHeapProps); // Copy CPU memory to GPU uint8_t* pData; ThrowIfFailed(m_globalConstantBuffer->Map(0, nullptr, (void**)&pData)); memcpy(pData, bufferData, sizeof(bufferData)); m_globalConstantBuffer->Unmap(0, nullptr);
}
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## OnInit
The creation of the constant buffer can be added right after the call to `CreateRayTracingPipeline`:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// #DXR Extra: Per-Instance Data
// Create a constant buffers, with a color for each vertex of the triangle, for each
// triangle instance
CreateGlobalConstantBuffer();
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## CreateHitSignature
Now the geometry is set with the triangles, but the shaders have not been adapted yet to use the constant buffer.
We first need to modify the root signature of the hit shader to use a constant buffer passed as a root parameter. Contrary to the
buffers passed on the heap, root parameters can be passed per instance. Since this is the first constant buffer we declare in the
root signature, we bind it to register 0: it will be accessible as `register(b0)` in the HLSL code.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// #DXR Extra: Per-Instance Data
// The vertex colors may differ for each instance, so it is not possible to
// point to a single buffer in the heap. Instead we use the concept of root
// parameters, which are defined directly by a pointer in memory. In the
// shader binding table we will associate each hit shader instance with its
// constant buffer. Here we bind the buffer to the first slot, accessible in
// HLSL as register(b0)
rsc.AddRootParameter(D3D12_ROOT_PARAMETER_TYPE_CBV, 0);
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## CreateShaderBindingTable
The hit group for the triangle needs to access the constant buffer.
For this, we add the pointer to the constant buffer in GPU memory to the set of resources accessed by the hit group.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// #DXR Extra: Per-Instance Data
// Adding the triangle hit shader and constant buffer data
m_sbtHelper.AddHitGroup(L"HitGroup", {(void*)m_globalConstantBuffer->GetGPUVirtualAddress()});
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Hit.hlsl
To access the constant buffer we replicate its structure in the HLSL code, and indicate the buffer is bound to the `b0` register:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// #DXR Extra: Per-Instance Data
cbuffer Colors : register(b0)
{ float3 A[3]; float3 B[3]; float3 C[3];
}
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
In the shader, we can directly access the buffer using the instance ID of the triangles to obtain a different color for each instance.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// #DXR Extra: Per-Instance Data
float3 hitColor = float3(0.6, 0.7, 0.6);
// Shade only the first 3 instances (triangles)
if (InstanceID() < 3)
{ hitColor = A[InstanceID()] * barycentrics.x + B[InstanceID()] * barycentrics.y + C[InstanceID()] * barycentrics.z;
}
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
![](/sites/default/files/pictures/2018/dx12_rtx_tutorial/Extra/constantbuffer.png)
## Accessing memory differently
In the previous section we replicated the structure of the constant buffer exactly in the HLSL code. However, the mapping from the original
data to the shader is arbitrary. For example, we could map it as an array of structures.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// #DXR Extra: Per-Instance Data
struct MyStructColor
{ float4 a; float4 b; float4 c;
};
cbuffer Colors : register(b0)
{ MyStructColor Tint[3];
}
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
For each instance, we can now access the data this way:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// #DXR Extra: Per-Instance Data
int instanceID = InstanceID();
float3 hitColor = Tint[instanceID].a * barycentrics.x + Tint[instanceID].b * barycentrics.y + Tint[instanceID].c * barycentrics.z;
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
![](/sites/default/files/pictures/2018/dx12_rtx_tutorial/Extra/constantbuffer2.png)
# Using Per-Instance Constant Buffer
In most practical cases, the constant buffers are defined per-instance so that they can be managed independently.
Add the declaration of an array of per-instance buffers in the header file:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// #DXR Extra: Per-Instance Data
void CreatePerInstanceConstantBuffers();
std::vector<ComPtr<ID3D12Resource>> m_perInstanceConstantBuffers;
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
We can now add the allocation and setup of those buffers at the end of the source file. We create one buffer for each
triangle.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//-----------------------------------------------------------------------------
//
// #DXR Extra: Per-Instance Data
void D3D12HelloTriangle::CreatePerInstanceConstantBuffers()
{ // Due to HLSL packing rules, we create the CB with 9 float4 (each needs to start on a 16-byte // boundary) XMVECTOR bufferData[] = { // A XMVECTOR{1.0f, 0.0f, 0.0f, 1.0f}, XMVECTOR{1.0f, 0.4f, 0.0f, 1.0f}, XMVECTOR{1.f, 0.7f, 0.0f, 1.0f}, // B XMVECTOR{0.0f, 1.0f, 0.0f, 1.0f}, XMVECTOR{0.0f, 1.0f, 0.4f, 1.0f}, XMVECTOR{0.0f, 1.0f, 0.7f, 1.0f}, // C XMVECTOR{0.0f, 0.0f, 1.0f, 1.0f}, XMVECTOR{0.4f, 0.0f, 1.0f, 1.0f}, XMVECTOR{0.7f, 0.0f, 1.0f, 1.0f}, }; m_perInstanceConstantBuffers.resize(3); int i(0); for (auto& cb : m_perInstanceConstantBuffers) { const uint32_t bufferSize = sizeof(XMVECTOR) * 3; cb = nv_helpers_dx12::CreateBuffer(m_device.Get(), bufferSize, D3D12_RESOURCE_FLAG_NONE, D3D12_RESOURCE_STATE_GENERIC_READ, nv_helpers_dx12::kUploadHeapProps); uint8_t* pData; ThrowIfFailed(cb->Map(0, nullptr, (void**)&pData)); memcpy(pData, &bufferData[i * 3], bufferSize); cb->Unmap(0, nullptr); ++i; }
}
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## OnInit
The creation of the constant buffer can be added right after the call to `CreateRayTracingPipeline`:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// #DXR Extra: Per-Instance Data
CreatePerInstanceConstantBuffers();
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## CreateShaderBindingTable
The hit groups for each instance and the actual pointers to the constant buffer are then set in the Shader Binding Table.
We will add a hit group for each triangle, and one for the plane, so that each can point to its own constant buffer. Replace the triangle hit group by:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// #DXR Extra: Per-Instance Data
// We have 3 triangles, each of which needs to access its own constant buffer
// as a root parameter in its primary hit shader. The shadow hit only sets a
// boolean visibility in the payload, and does not require external data
for (int i = 0; i < 3; ++i) { m_sbtHelper.AddHitGroup( L"HitGroup", {(void *)(m_perInstanceConstantBuffers[i]->GetGPUVirtualAddress())});
}
// The plane also uses a constant buffer for its vertex colors
m_sbtHelper.AddHitGroup(L"HitGroup",
{ (void*)(m_perInstanceConstantBuffers[0]->GetGPUVirtualAddress())});
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The triangles will then all invoke the same shader, but use different constant buffers. The plane uses the same constant buffer
as the first triangle for simplicity.
## CreateTopLevelAS
Now the instances are independent, we need to associate the instances with their own hit group in the SBT. This is done by modifying the `AddInstance` call by indicating that
the instance index `i` is also the index of the hit group to use in the SBT. This way, hitting the i-th triangle will invoke the first hit group defined in
the SBT, itself referencing `m_perInstanceConstantBuffers[i]`:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// #DXR Extra: Per-Instance Data
for (size_t i = 0; i < instances.size(); i++)
{ m_topLevelASGenerator.AddInstance(instances[i].first.Get(), instances[i].second, static_cast<UINT>(i), static_cast<UINT>(i));
}
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Hit.hlsl
Now, for each hit, DXR will bind the associated constant buffer, hence avoiding the need to declare and dereference arrays:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// #DXR Extra: Per-Instance Data
cbuffer Colors : register(b0)
{ float3 A; float3 B; float3 C;
}
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The computation of the final color is then simplified by accessing the member of the constant buffer directly:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// #DXR Extra: Per-Instance Data
float3 hitColor = A * barycentrics.x + B * barycentrics.y + C * barycentrics.z;
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
![](/sites/default/files/pictures/2018/dx12_rtx_tutorial/Extra/constantbuffers.png)
# Adding a Specific Hit Shader for the Plane
Until now all the geometry used a single shader. In practice, a scene with different object type will most likely require as many different shaders.
In this section we will apply a separate shader for the plane.
# Hit.hlsl
Add a new shader in the file:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// #DXR Extra: Per-Instance Data
[shader("closesthit")]
void PlaneClosestHit(inout HitInfo payload, Attributes attrib)
{ float3 barycentrics = float3(1.f - attrib.bary.x - attrib.bary.y, attrib.bary.x, attrib.bary.y); float3 hitColor = float3(0.7, 0.7, 0.3); payload.colorAndDistance = float4(hitColor, RayTCurrent());
}
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## CreateRaytracingPipeline
This new shader has to be added to the raytracing pipeline, first by adding its symbol when adding `m_hitLibrary`:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// #DXR Extra: Per-Instance Data
pipeline.AddLibrary(m_hitLibrary.Get(), {L"ClosestHit", L"PlaneClosestHit"});
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
We also need to add a new hit group after adding `HitGroup`, called `PlaneHitGroup`:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// #DXR Extra: Per-Instance Data
pipeline.AddHitGroup(L"PlaneHitGroup", L"PlaneClosestHit");
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
We also add its root signature association. Since it has the same root signature as the existing `HitGroup`, both
can be associated to the same root signature. Modify the `AddRootSignatureAssociation` call as follows:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// #DXR Extra: Per-Instance Data
pipeline.AddRootSignatureAssociation(m_hitSignature.Get(), {L"HitGroup", L"PlaneHitGroup"});
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## CreateShaderBindingTable
The 4th hit group of the SBT is the one corresponding to the plane. Instead of using `HitGroup`, we now
associate it to our newly created hit group, `PlaneHitGroup`. Since this shader does not require any external data,
we can leave its input resources empty.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// #DXR Extra: Per-Instance Data
// Adding the plane
m_sbtHelper.AddHitGroup(L"PlaneHitGroup", {});
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
![](/sites/default/files/pictures/2018/dx12_rtx_tutorial/Extra/PlaneClosestHit.png)