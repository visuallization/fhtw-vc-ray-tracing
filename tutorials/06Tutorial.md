# DXR Tutorial Extra : Indexed Geometry
Welcome to the next section of the tutorial. If you miss the first tutorial, it is [here](01Tutorial.md)
The bases of this tutorial starts at the end of the previous one.
You can download the entire project [here](https://developer.nvidia.com/rtx/raytracing/dxr/tutorial/Files/dxr_tutorial.zip)
The first tutorial only shows a triangle, which can feel a bit simplistic:
![](https://developer.nvidia.com/sites/default/files/pictures/2018/dx12_rtx_tutorial/Extra/originalRender.png)
In this tutorial, we will convert the plane triangle to a three dimensional one, a tetrahedron.
Do do this, we will convert the simple triangle to an indexed version of it.
Add the new resources
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
ComPtr<ID3D12Resource> m_indexBuffer;
D3D12_INDEX_BUFFER_VIEW m_indexBufferView;
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## LoadAssets
Instead of a simple triangle, let's create a [tetrahedron](https://en.wikipedia.org/wiki/Tetrahedron), which requires 4 vertices.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
Vertex triangleVertices[] = { 
    {{std::sqrtf(8.f / 9.f), 0.f, -1.f / 3.f}, {1.f, 0.f, 0.f, 1.f}}, 
    {{-std::sqrtf(2.f / 9.f), std::sqrtf(2.f / 3.f), -1.f / 3.f}, {0.f, 1.f, 0.f, 1.f}}, 
    {{-std::sqrtf(2.f / 9.f), -std::sqrtf(2.f / 3.f), -1.f / 3.f}, {0.f, 0.f, 1.f, 1.f}}, 
    {{0.f, 0.f, 1.f}, {1, 0, 1, 1}}
};
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Then, we need to create and set the indices right after setting `m_vertexBufferView`.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
//----------------------------------------------------------------------------------------------
// Indices
std::vector<UINT> indices = {0, 1, 2, 0, 3, 1, 0, 2, 3, 1, 3, 2};
const UINT indexBufferSize = static_cast<UINT>(indices.size()) * sizeof(UINT);
CD3DX12_HEAP_PROPERTIES heapProperty = CD3DX12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_UPLOAD);
CD3DX12_RESOURCE_DESC bufferResource = CD3DX12_RESOURCE_DESC::Buffer(indexBufferSize);
ThrowIfFailed(m_device->CreateCommittedResource( &heapProperty, D3D12_HEAP_FLAG_NONE, &bufferResource, D3D12_RESOURCE_STATE_GENERIC_READ, nullptr, IID_PPV_ARGS(&m_indexBuffer)));
// Copy the triangle data to the index buffer.
UINT8* pIndexDataBegin;
ThrowIfFailed(m_indexBuffer->Map(0, &readRange, reinterpret_cast<void**>(&pIndexDataBegin)));
memcpy(pIndexDataBegin, indices.data(), indexBufferSize);
m_indexBuffer->Unmap(0, nullptr);
// Initialize the index buffer view.
m_indexBufferView.BufferLocation = m_indexBuffer->GetGPUVirtualAddress();
m_indexBufferView.Format = DXGI_FORMAT_R32_UINT;
m_indexBufferView.SizeInBytes = indexBufferSize;
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## PopulateCommandList
To draw the tetrahedron in the raster, you simply need to change how it is drawn, by making the
following changes in `PopulateCommandList()`.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
m_commandList->IASetVertexBuffers(0, 1, &m_vertexBufferView);
m_commandList->IASetIndexBuffer(&m_indexBufferView);
m_commandList->DrawIndexedInstanced(12, 1, 0, 0, 0);
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The result image is not great an will be quite flat
![](https://developer.nvidia.com/sites/default/files/pictures/2018/dx12_rtx_tutorial/Extra/tetra_flat.png)

## CreateBottomLevelAS
To see this geometry in the raytracing path, we need to improve the `CreateBottomLevelAS` method to support
indexed geometry. We first change the signature of the method to include index buffers:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ C
AccelerationStructureBuffers CreateBottomLevelAS( std::vector<std::pair<ComPtr<ID3D12Resource>, uint32_t>> vVertexBuffers, std::vector<std::pair<ComPtr<ID3D12Resource>, uint32_t>> vIndexBuffers = {});
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
We then replace the beginning of the method as follows so that the bottom-level AS helper is called
with indexing if needed:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
// #DXR Extra: Indexed Geometry
D3D12HelloTriangle::AccelerationStructureBuffers D3D12HelloTriangle::CreateBottomLevelAS(std::vector<std::pair<ComPtr<ID3D12Resource>, uint32_t>> vVertexBuffers, std::vector<std::pair<ComPtr<ID3D12Resource>, uint32_t>> vIndexBuffers) {
	nv_helpers_dx12::BottomLevelASGenerator bottomLevelAS;
	// Adding all vertex buffers and not transforming their position. 
	for (size_t i = 0; i < vVertexBuffers.size(); i++) {
		if (i < vIndexBuffers.size() && vIndexBuffers[i].second > 0) {
			bottomLevelAS.AddVertexBuffer(vVertexBuffers[i].first.Get(), 0, vVertexBuffers[i].second, sizeof(Vertex), vIndexBuffers[i].first.Get(), 0, vIndexBuffers[i].second, nullptr, 0, true);
		}
		else {
			bottomLevelAS.AddVertexBuffer(vVertexBuffers[i].first.Get(), 0, vVertexBuffers[i].second, sizeof(Vertex), 0, 0);
		}
	}
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## CreateAccelerationStructures
The acceleration structure build calls also need to be updated to reflect the new interface as well as to add the new geometry:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
// Build the bottom AS from the Triangle vertex buffer
AccelerationStructureBuffers bottomLevelBuffers = CreateBottomLevelAS({{m_vertexBuffer.Get(), 4}}, {{m_indexBuffer.Get(), 12}});
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
But the shading is not correct with the raytracer. This is because we are accessing invalid data in the Hit Shader.
![Shading issue](https://developer.nvidia.com/sites/default/files/pictures/2018/dx12_rtx_tutorial/Extra/tetra_rt_issue.png width=400)

## Hit Shader
In the hit shader, we will need to access the indices
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
StructuredBuffer<int> indices: register(t1);
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Then in the shader access the right vertex
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C 
float3 hitColor = BTriVertex[indices[vertId + 0]].color * barycentrics.x + BTriVertex[indices[vertId + 1]].color * barycentrics.y + BTriVertex[indices[vertId + 2]].color * barycentrics.z;
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## CreateHitSignature
Changing the shader is not enough, we need to inform the shader that more information is needed.
Do to this, change the signature in `CreateHitSignature`.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
rsc.AddRootParameter(D3D12_ROOT_PARAMETER_TYPE_SRV, 0 /*t0*/); // vertices and colors
rsc.AddRootParameter(D3D12_ROOT_PARAMETER_TYPE_SRV, 1 /*t1*/); // indices
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## CreateShaderBindingTable
Finally, we need to bind the new data to the shader and we are doing it in the `CreateShaderBindingTable` by modifying
the data pass to the `HitGroup`.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
m_sbtHelper.AddHitGroup(L"HitGroup", {(void*)(m_vertexBuffer->GetGPUVirtualAddress()), (void*)(m_indexBuffer->GetGPUVirtualAddress())});
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Now the result in the raytracer is similar to the rasterizer. Note that if you have other hit groups attached to the same root signature,
you would have to adjust their list of root parameters as well.
![](https://developer.nvidia.com/sites/default/files/pictures/2018/dx12_rtx_tutorial/Extra/tetra_rt_flat.png)

# Perspective & Depth & Plane
An orthographic view and single geometry does not help seeing the geometry right.
Follow the tutorials:
* [Perspective](https://developer.nvidia.com/rtx/raytracing/dxr/DX12-Raytracing-tutorial/Extra/dxr_tutorial_extra_perspective): Adding a camera perspective
* [Instance Data](https://developer.nvidia.com/rtx/raytracing/dxr/DX12-Raytracing-tutorial/Extra/dxr_tutorial_extra_per_instance_data): Adding a plane
* [Depth Buffer](https://developer.nvidia.com/rtx/raytracing/dxr/DX12-Raytracing-tutorial/Extra/dxr_tutorial_extra_depth_buffer): Adding the depth buffer to the raster
This will give following result:
![](https://developer.nvidia.com/sites/default/files/pictures/2018/dx12_rtx_tutorial/Extra/tetra_rt_3d.png)

# Menger Sponge fractal
In the following part of the tutorial we will add some more complex geometry, using indexed vertex buffers. The geometry itself is a randomized variation of the Menger Sponge fractal.
Add the following declarations in the header file:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
// #DXR Extra: Indexed Geometry
void CreateMengerSpongeVB();
ComPtr< ID3D12Resource > m_mengerVB;
ComPtr< ID3D12Resource > m_mengerIB;
D3D12_VERTEX_BUFFER_VIEW m_mengerVBView;
D3D12_INDEX_BUFFER_VIEW m_mengerIBView;
UINT m_mengerIndexCount;
UINT m_mengerVertexCount;
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The procedural generation code is provided in the `DXRHelpers.h`. This function also provides normal information, that we will not use in this tutorial.
For compatibility, add the following constructors to the `Vertex` structure:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
// #DXR Extra: Indexed Geometry
Vertex(XMFLOAT4 pos, XMFLOAT4 /*n*/, XMFLOAT4 col)
	:position(pos.x, pos.y, pos.z), color(col) {}
Vertex(XMFLOAT3 pos, XMFLOAT4 col)
	:position(pos), color(col) {}
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
At the end of the source file, add the implementation of the creation of the geometry buffers for the Menger Sponge. This method
creates a vertex buffer and an index buffer, as well as views on those buffers for later use in the rasterization path.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
// #DXR Extra: Indexed Geometry
void D3D12HelloTriangle::CreateMengerSpongeVB()
{ 
	std::vector< Vertex > vertices; 
	std::vector< UINT > indices; 
	nv_helpers_dx12::GenerateMengerSponge(3, 0.75, vertices, indices); 
	{ 
		const UINT mengerVBSize = static_cast<UINT>(vertices.size()) * sizeof(Vertex); 
		// Note: using upload heaps to transfer static data like vert buffers is not 
		// recommended. Every time the GPU needs it, the upload heap will be 
		// marshalled over. Please read up on Default Heap usage. An upload heap is 
		// used here for code simplicity and because there are very few verts to 
		// actually transfer. 
		CD3DX12_HEAP_PROPERTIES heapProperty = CD3DX12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_UPLOAD);
		CD3DX12_RESOURCE_DESC bufferResource = CD3DX12_RESOURCE_DESC::Buffer(mengerVBSize); 
		ThrowIfFailed(m_device->CreateCommittedResource( &heapProperty, D3D12_HEAP_FLAG_NONE, &bufferResource, D3D12_RESOURCE_STATE_GENERIC_READ, nullptr, IID_PPV_ARGS(&m_mengerVB)));

		// Copy the triangle data to the vertex buffer. 
		UINT8* pVertexDataBegin; 
		CD3DX12_RANGE readRange(0, 0); 
		// We do not intend to read from this resource on the CPU. 
		ThrowIfFailed(m_mengerVB->Map(0, &readRange, reinterpret_cast<void**>(&pVertexDataBegin))); 
		memcpy(pVertexDataBegin, vertices.data(), mengerVBSize); 
		m_mengerVB->Unmap(0, nullptr); 
		
		// Initialize the vertex buffer view. 
		m_mengerVBView.BufferLocation = m_mengerVB->GetGPUVirtualAddress(); 
		m_mengerVBView.StrideInBytes = sizeof(Vertex); 
		m_mengerVBView.SizeInBytes = mengerVBSize; 
	} 
	
	{ 
		const UINT mengerIBSize = static_cast<UINT>(indices.size()) * sizeof(UINT); 
		// Note: using upload heaps to transfer static data like vert buffers is not 
		// recommended. Every time the GPU needs it, the upload heap will be 
		// marshalled over. Please read up on Default Heap usage. An upload heap is 
		// used here for code simplicity and because there are very few verts to 
		// actually transfer. 
		CD3DX12_HEAP_PROPERTIES heapProperty = CD3DX12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_UPLOAD); 
		CD3DX12_RESOURCE_DESC bufferResource = CD3DX12_RESOURCE_DESC::Buffer(mengerIBSize); 
		ThrowIfFailed(m_device->CreateCommittedResource( &heapProperty, D3D12_HEAP_FLAG_NONE, &bufferResource, D3D12_RESOURCE_STATE_GENERIC_READ, nullptr, IID_PPV_ARGS(&m_mengerIB))); 
		
		// Copy the triangle data to the index buffer. 
		UINT8* pIndexDataBegin; 
		CD3DX12_RANGE readRange(0, 0); 
		// We do not intend to read from this resource on the CPU. 
		ThrowIfFailed(m_mengerIB->Map(0, &readRange, reinterpret_cast<void**>(&pIndexDataBegin))); 
		memcpy(pIndexDataBegin, indices.data(), mengerIBSize); 
		m_mengerIB->Unmap(0, nullptr); 
		
		// Initialize the index buffer view. 
		m_mengerIBView.BufferLocation = m_mengerIB->GetGPUVirtualAddress(); 
		m_mengerIBView.Format = DXGI_FORMAT_R32_UINT; 
		m_mengerIBView.SizeInBytes = mengerIBSize; 
		m_mengerIndexCount = static_cast<UINT>(indices.size()); 
		m_mengerVertexCount = static_cast<UINT>(vertices.size()); 
	}
}
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## LoadAssets
Call the geometry generation method right after the initialization of `m_vertexBufferView`:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
// #DXR Extra: Indexed Geometry
CreateMengerSpongeVB();
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## PopulateCommandList
We can now draw the geometry in the raster path, by adding the draw calls right after drawing the triangle:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
// #DXR Extra: Indexed Geometry
// In a way similar to triangle rendering, rasterize the Menger Sponge
m_commandList->IASetVertexBuffers(0, 1, &m_mengerVBView);
m_commandList->IASetIndexBuffer(&m_mengerIBView);
m_commandList->DrawIndexedInstanced(m_mengerIndexCount, 1, 0, 0, 0);
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## CreateAccelerationStructures
The acceleration structure build calls also need to be updated to reflect the new interface as well as to add the new geometry:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
// #DXR Extra: Indexed Geometry
// Build the bottom AS from the Menger Sponge vertex buffer
// #DXR Extra: Indexed Geometry
// Build the bottom AS from the Menger Sponge vertex buffer
AccelerationStructureBuffers mengerBottomLevelBuffers = CreateBottomLevelAS({{m_mengerVB.Get(), m_mengerVertexCount}}, {{m_mengerIB.Get(), m_mengerIndexCount}});
// Add both the triangle and the indexed geometry
m_instances = { {bottomLevelBuffers.pResult, XMMatrixIdentity()}, { mengerBottomLevelBuffers.pResult, XMMatrixIdentity() }
};
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## CreateShaderBindingTable
We shouldn't forget to add the binding of the new instance in `CreateShaderBindingTable`
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
m_sbtHelper.AddHitGroup(L"HitGroup", {(void*)(m_mengerVB->GetGPUVirtualAddress()), (void*)(m_mengerIB->GetGPUVirtualAddress())});
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The geometry is now visible in both rasterization and raytracing:
![Raster](https://developer.nvidia.com/sites/default/files/pictures/2018/dx12_rtx_tutorial/Extra/mengerSpongePerspectiveRaster.png)
![Raytracing](https://developer.nvidia.com/sites/default/files/pictures/2018/dx12_rtx_tutorial/Extra/mengerSpongePerspectiveRaytracing.png)