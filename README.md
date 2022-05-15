# Raytrace A Triangle

This repo is based on the raytracing tutorial by nvidia. You can find it here: [Part 1](https://developer.nvidia.com/rtx/raytracing/dxr/dx12-raytracing-tutorial-part-1) & [Part 2](https://developer.nvidia.com/rtx/raytracing/dxr/dx12-raytracing-tutorial-part-2)

## Important (Read before continue)

Unfortunately the tutorial seems to be broken (missing code due to parsing issues on their website) but I tried my best to recreate their markdown.

You can find the cleaned mark down files here: [Tutorial Part 1](01Tutorial.md) & [Tutorial Part 2](02Tutorial.md)
I did my best to clean the files and make sure the formating is correct, but there will be most probably still some errors.
Also I havent't  updated the image urls in the markdown files, so they won't be displayed at the moment.
If you find such an error or want update the image urls, feel free to fix it and create a pull request.

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