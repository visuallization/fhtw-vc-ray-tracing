# DirectX Raytracing (DXR) Tutorial

This repo is based on the raytracing tutorial by nvidia. You can find it here: [Part 1](https://developer.nvidia.com/rtx/raytracing/dxr/dx12-raytracing-tutorial-part-1) & [Part 2](https://developer.nvidia.com/rtx/raytracing/dxr/dx12-raytracing-tutorial-part-2)

## Important (Read before you continue)

Unfortunately the tutorial seems to be broken (missing code due to parsing issues on their website) but I tried my best to recreate their markdown.

You can find the cleaned mark down files in the [/tutorials](tutorials/) folder. To get started, go directly to [Tutorial Part 1](tutorials/01Tutorial.md) & [Tutorial Part 2](tutorials/02Tutorial.md).

I did my best to clean the files and make sure the formating is correct, but there will be most probably still some errors.
If you find such an error feel free to fix it and create a pull request.

Further more this tutorial will only work if you have an nvidia graphics card which supports raytracing.
I added the following line in `Main.cpp` so that the programm will use the nvidia card per default
```
// add this to run program with nvidia graphics card
extern "C" {
	_declspec(dllexport) DWORD NvOptimusEnablement = 0x00000001;
}
```

I also experienced some issues in the post building step of the solution because it wasn't able to copy 2 relevant dlls.
I downloaded the missing dlls from here:
- [dxcompiller.dll](https://windll.com/de/dll/microsoft-corporation/dxcompiler)
- [dxil.dll](https://windll.com/de/dll/microsoft-corporation/dxi)

Then I copied the `dxcompiller.dll` and `dxil.dll` into the solutions `Debug` (\HelloTriangle\bin\x64\Debug) and `Release` (HelloTriangle\bin\x64\Release) folder.

This should make sure that your program runs without any dll related errors

## Troubleshooting

If you get some memory access errors they might be (but not necessarily) related to missing or wrong versions of visual studio tools.
In the "Visual Studio Installer" install the packages "Universal Windows Platform Development", "Desktopdevelopment C++" and "Windows SDK Version 10.0.18362" and see if it fixes the issues if you restart the project and select the corresponding sdk version. (Shoutout to Marius for reporting and finding the solution to this issue! 🥳)