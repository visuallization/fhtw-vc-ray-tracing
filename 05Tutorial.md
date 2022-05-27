# DXR Tutorial Extra : Depth Buffering
!!! TIP The purpose of this tutorial is only to improve the rasterization pipeline to obtain rasterized images consistent with raytracing, and is not related to DXR.
Welcome to the next section of the tutorial. If you missed the first tutorial, it is [here](/rtx/raytracing/dxr/DX12-Raytracing-tutorial-Part-1)
The base of this tutorial starts at the end of the previous one.
You can download the entire project [here](/rtx/raytracing/dxr/tutorial/Files/dxr_tutorial.zip)
The first tutorial only shows a triangle, which where there is no need to eliminate hidden surfaces:
![](/sites/default/files/pictures/2018/dx12_rtx_tutorial/Extra/originalRender.png)
However, with more complex geometry such as the one you can add in [this tutorial](/rtx/raytracing/dxr/DX12-Raytracing-tutorial/Extra/dxr_tutorial_extra_indexed_geometry), hidden surface
removal is mandatory. While raytracing inherently addresses this issue, rasterization requires setting a depth buffer to ensure
only the closest surfaces are visible.
We need to add a depth buffer, as well as a specific heap to reference it. Add the following declarations in the header file:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
// #DXR Extra: Depth Buffering
void CreateDepthBuffer();
ComPtr<ID3D12DescriptorHeap> m_dsvHeap;
ComPtr<ID3D12Resource> m_depthStencil;
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Note that this tutorial only considers depth testing, but it is also possible to combine depth and stencil in a single buffer if needed.
At the end of the source file, add the implementation of the creation of the depth buffers and corresponding heap. The format `DXGI_FORMAT_D32_FLOAT` is
where we specify what exactly is stored in the buffer. This is also where a stencil component can be added, for example
using `DXGI_FORMAT_D24_UNORM_S8_UINT` instead.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
//-----------------------------------------------------------------------------
//
// Create the depth buffer for rasterization. This buffer needs to be kept in a separate heap
//
// #DXR Extra: Depth Buffering
void D3D12HelloTriangle::CreateDepthBuffer()
{ 
    // The depth buffer heap type is specific for that usage, and the heap contents are not visible 
    // from the shaders 
    m_dsvHeap = nv_helpers_dx12::CreateDescriptorHeap(m_device.Get(), 1, D3D12_DESCRIPTOR_HEAP_TYPE_DSV, false); 

    // The depth and stencil can be packed into a single 32-bit texture buffer. Since we do not need 
    // stencil, we use the 32 bits to store depth information (DXGI_FORMAT_D32_FLOAT). 
    D3D12_HEAP_PROPERTIES depthHeapProperties = CD3DX12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_DEFAULT); 
    D3D12_RESOURCE_DESC depthResourceDesc = CD3DX12_RESOURCE_DESC::Tex2D(DXGI_FORMAT_D32_FLOAT, m_width, m_height, 1, 1); 
    depthResourceDesc.Flags |= D3D12_RESOURCE_FLAG_ALLOW_DEPTH_STENCIL; 

    // The depth values will be initialized to 1 
    CD3DX12_CLEAR_VALUE depthOptimizedClearValue(DXGI_FORMAT_D32_FLOAT, 1.0f, 0); 

    // Allocate the buffer itself, with a state allowing depth writes 
    ThrowIfFailed(m_device->CreateCommittedResource( &depthHeapProperties, D3D12_HEAP_FLAG_NONE, &depthResourceDesc, D3D12_RESOURCE_STATE_DEPTH_WRITE, &depthOptimizedClearValue, IID_PPV_ARGS(&m_depthStencil))); 

    // Write the depth buffer view into the depth buffer heap 
    D3D12_DEPTH_STENCIL_VIEW_DESC dsvDesc = {}; 
    dsvDesc.Format = DXGI_FORMAT_D32_FLOAT; 
    dsvDesc.ViewDimension = D3D12_DSV_DIMENSION_TEXTURE2D; 
    dsvDesc.Flags = D3D12_DSV_FLAG_NONE; 
    m_device->CreateDepthStencilView(m_depthStencil.Get(), &dsvDesc, m_dsvHeap->GetCPUDescriptorHandleForHeapStart());
}
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## LoadPipeline
The depth buffer is created in the `LoadPipeline` method by adding these lines at the end:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
// #DXR Extra: Depth Buffering
// The original sample does not support depth buffering, so we need to allocate a depth buffer,
// and later bind it before rasterization
CreateDepthBuffer();
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## LoadAssets
We also need to indicate we will use a depth buffer in the graphics pipeline by modifying the pipeline descriptor,
just before calling `CreateGraphicsPipelineState`:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
// #DXR Extra: Depth Buffering
// Add support for depth testing, using a 32-bit floating-point depth buffer
psoDesc.DepthStencilState = CD3DX12_DEPTH_STENCIL_DESC(D3D12_DEFAULT);
psoDesc.DSVFormat = DXGI_FORMAT_D32_FLOAT;
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## PopulateCommandList
Now the buffer is created and the pipeline is set, we just need to activate the depth buffering. Replace the `OMSetRenderTargets` call
by:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~C
// #DXR Extra: Depth Buffering
// Bind the depth buffer as a render target
CD3DX12_CPU_DESCRIPTOR_HANDLE dsvHandle(m_dsvHeap->GetCPUDescriptorHandleForHeapStart());
m_commandList->OMSetRenderTargets(1, &rtvHandle, FALSE, &dsvHandle);
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Before rendering the depth buffer needs to be cleared, by adding this line right before rendering in raster mode:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if (m_raster)
{ // #DXR Extra: Depth Buffering m_commandList->ClearDepthStencilView(dsvHandle, D3D12_CLEAR_FLAG_DEPTH, 1.0f, 0, 0, nullptr);
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Using the simple triangle the resulting image should still be as the one on top of this tutorial. However, using the [more complex geometry](/rtx/raytracing/dxr/DX12-Raytracing-tutorial/Extra/dxr_tutorial_extra_indexed_geometry)
and a [perspective camera](/rtx/raytracing/dxr/DX12-Raytracing-tutorial/Extra/dxr_tutorial_extra_perspective), the rasterization and raytracing now both remove hidden surfaces:
![Rasterized](/sites/default/files/pictures/2018/dx12_rtx_tutorial/Extra/mengerSpongePerspectiveRaster.png)
![Raytraced](/sites/default/files/pictures/2018/dx12_rtx_tutorial/Extra/mengerSpongePerspectiveRaytracing.png)