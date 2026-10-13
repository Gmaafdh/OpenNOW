# DirectX 10 compatibility

Windows GPUs that top out at Direct3D feature level 10_0 or 10_1 (for example GeForce
8/9/200 series, Radeon HD 2000–5000, Intel GMA X4500 and first-generation Intel HD
Graphics) can run OpenNOW, but not on the normal embedded video path. This document records
why, what the client does instead, and how to check it on such a machine.

Activation is automatic. There is no DirectX 10 setting, and no user-visible switch to turn
the behaviour on or off.

## Why feature level 10_x used to fail

Three independent limits applied at once:

1. Qt Quick's D3D11 RHI requires Shader Model 5.0, `ID3D11DeviceContext1`, and
   `ConstantBufferOffsetting`. On a 10_x device `QRhi::create` fails and Qt retries with
   `PreferSoftwareRenderer`, so the shell came up on the WARP software rasterizer at feature
   level 11_x. The window worked; every pixel was rasterized by the CPU.
2. The embedded presenter adopted that WARP device. `ID3D11VideoDevice` and
   `ID3D11VideoContext` are optional on it, and WARP plus several 10_x drivers refuse them,
   so adoption aborted with "Qt D3D11 device has no video interface".
3. The capability probe created a device the same way, hit the same missing video interface,
   and reported `d3d11Presentation=false`. That marked every hardware codec unavailable, so
   Settings greyed out DirectX 11 and DirectX 12 and a session ended with "No hardware video
   backend is available for embedded streaming on this device" (issue #980).

All YUV-to-RGB conversion went through `ID3D11VideoProcessor`, which needs feature level
11_0. NV12 and P010 shader resource views need 11_1. Flip-model swap chains,
`DXGI_PRESENT_ALLOW_TEARING`, and the frame-latency waitable object need 11_1 and DXGI 1.3.
D3D12 needs 11_0. Those limits are not implementation choices, so the compatibility path
avoids all of them instead of working around them.

Feature level 10_x does keep everything the path needs: RGBA8 textures, staging and DYNAMIC
textures, `CopySubresourceRegion`, `Map`, bitblt swap chains, Shader Model 4.0/4.1, and DXVA
H.264 hardware decode.

## Detection

`feature_level::requires_compat_conversion` returns true when the device's actual feature
level is below 11_0 **or** when `ID3D11VideoDevice`/`ID3D11VideoContext` are missing. Both
conditions are read from the device that is really being used, never assumed from the adapter
description:

| Site | Where the level comes from |
| --- | --- |
| Embedded presentation | `ID3D11Device::GetFeatureLevel` on the device Qt adopted |
| Standalone presentation and the probe | the level `D3D11CreateDevice` returned |
| Qt shell adapter list | `D3D11CreateDevice` per adapter, before `QGuiApplication` exists |

The recorded level is exposed as `CapabilityProbe.feature_level` and
`CapabilityProbe.video_processor`, and `compat_presentation()` reports whether the
compatibility bridge is in use. An unknown level (a driver reporting something this build does
not know) is treated as an 11_x device, because every gap that matters is still caught by the
missing video interfaces.

WARP is included deliberately. It reports 11_x but refuses the video interfaces on many
systems, so it takes the same path, and the existing `E_NOINTERFACE` skips in the Windows GPU
tests keep their meaning.

## Embedded path (Qt window)

Decode stays on hardware. Only the conversion and the upload change.

1. `CompatDecodeDevice` creates its own D3D11 device with `REQUESTED_FEATURE_LEVELS`
   (11_1 down to 10_0) and its own `IMFDXGIDeviceManager`. If creation fails with video
   support requested, it retries without `D3D11_CREATE_DEVICE_VIDEO_SUPPORT`, since the
   converter no longer needs it. Nothing is shared between this device and Qt's device, so no
   cross-device handle or keyed mutex is involved.
2. Media Foundation decodes into NV12 on that device, as before, and the decoder worker owns
   the whole read-back: `CompatConverter` copies the decoded array slice into an NV12 staging
   texture and maps it, then `nv12_to_rgba8` converts to RGBA8 using the range and matrix the
   stream negotiated (BT.601/BT.709/BT.2020, the same values
   `windows::color::input_color_space` gives the video processor) with left chroma siting by
   2×2 replication. The result travels beside the decoded frame as `CompatPixels`
   (`Arc<Vec<u8>>`) through the existing bounded decoded queue, so it is capped by
   `ADAPTIVE_VIDEO_QUEUE_CAPACITY` (7) and dropped with the frame it belongs to.
3. Qt's render thread only uploads: `CompatUploader` keeps one RGBA8 frame texture per slot,
   created `D3D11_USAGE_DYNAMIC` with `D3D11_BIND_SHADER_RESOURCE` and CPU write access, and
   writes the converted rows into it with `Map(WRITE_DISCARD)`. Write-discard access makes the
   runtime rename the memory, so no GPU copy and no wait on Qt's previous sample of that slot are
   involved. The published frame is `D3d11TextureFormat::Rgba8` in `D3d11ColorSpace::Sdr709`, the
   same combination the 8-bit video-processor path already produces, and Qt imports it through its
   existing native-texture path.

This keeps blocking work off `QSGRenderThread`: the staging read-back waits for the decode GPU
to finish the frame, which is exactly the kind of stall that must not happen on the render
thread. It also keeps `AdoptedResources::record` free of Shader Model 5.0 shaders, video
processor enumerators and GPU waits.

Negotiation is rejected early. `D3d11FrameProducer::new` fails with `InvalidConfig` unless the
format is H.264, NV12, 8-bit SDR, before a decoder or a second device is created.

## Standalone path (native presenter window)

The standalone presenter builds a bitblt swap chain: `DXGI_SWAP_EFFECT_DISCARD`, one back
buffer, `R8G8B8A8_UNORM`, no waitable-object flag, no `SetColorSpace1` and no tearing flag.
`Graphics::present` then converts on the CPU, uploads into a DYNAMIC
RGBA8 texture, clears the back buffer, sets the viewport to the existing `fit_rect` and draws a
fullscreen triangle with a Shader Model 4.0/4.1 pair
(`windows/compat_present.hlsl`). Letterboxing is the viewport's job, and the shader takes its
UVs from the triangle's `TEXCOORD0` rather than from `SV_Position`, so a letterboxed frame
samples the whole video texture.

Ten-bit scan-out is turned off in this mode (`ten_bit_output_supported=false`) and the swap
chain profile is recomputed, so no code path asks a 10_x device for RGB10A2 output.

## Capability ceiling

| Aspect | DirectX 11/12 device | Compatibility path |
| --- | --- | --- |
| Codecs | H.264, H.265, AV1 as the probe reports | H.264 only |
| Pixel formats | NV12, P010, AYUV, Y410 | NV12 only |
| Color depth / transfer | 8-bit and 10-bit, SDR and HDR | 8-bit SDR |
| Conversion | `ID3D11VideoProcessor` | CPU, on the decoder worker |
| Zero-copy texture mode | advertised | never advertised |
| Swap chain | flip model, tearing allowed | bitblt, no tearing |
| Shader model | 5.0 | 4.0/4.1 |

`FeatureTier::allows_format` enforces the codec/format/HDR ceiling, the probe's
`zero_copy_modes` list is emptied, and the per-codec reason in Settings becomes "DirectX 10
compatibility mode supports H.264 8-bit 4:2:0 SDR only". The core resolves Auto against that
report before CloudMatch allocation, as it already did; no protocol or ABI field changed.

Cost: one full-frame NV12 read-back plus one conversion per decoded frame on the worker, and
one full-frame upload per presented frame on the render thread. On the hardware this targets
that is a real budget, which is why the ceiling keeps the resolution and frame rate the service
already negotiated rather than adding a scaling step.

## Qt shell

`GraphicsDeviceSelection::detectAdapters()` runs before `QGuiApplication` and records each
adapter's feature level. If no adapter can host an accelerated RHI, the application sets
`QSG_RHI_PREFER_SOFTWARE_RENDERER=1` itself and logs it, instead of relying on Qt's silent
retry after a failed `QRhi::create`; the window is then never pinned to an adapter that cannot
present it. The Settings GPU picker labels such adapters "DirectX 10 compatibility" and lists
only H.264 for them.

Adapters are still listed in enumeration order, and Automatic still prefers a GPU that can
hardware-decode. Its tie-break now also prefers a GPU that can display, so on a machine with both
a DirectX 10 GPU and a DirectX 11 GPU the DirectX 11 GPU is selected even when it is enumerated
second, keeping the documented promise that the same GPU decodes and displays. Explicitly
selecting the DirectX 10 GPU still routes decode to it; the shell just does not pin its window to
an adapter that cannot present it.

## Checking a DirectX 10 machine

The diagnostics export (Settings → About → Copy diagnostics) is the primary evidence. The
standalone presenter writes:

```
Windows presenter device featureLevel=10_1 tier=Direct3d10
D3D11 video device unavailable (featureLevel=10_1): …
Windows presenter swap chain flipModel=false bufferCount=1 tearing=false waitable=false sync=1
Windows presenter using the DirectX 10 compatibility path (featureLevel=10_1 videoProcessor=false): H.264 8-bit 4:2:0 SDR only
```

and the embedded pipeline writes:

```
Qt D3D11 device has no video interface (featureLevel=11_1): …
DirectX 10 compatibility decode device created featureLevel=10_1 tier=Direct3d10
Embedded D3D11 compatibility path active decodeFeatureLevel=10_1 decodeAdapterLuid=0x… adoptedFeatureLevel=11_1
```

The adopted level is 11_1 there because Qt fell back to WARP, while decode stays on the real
10_1 adapter.

`Embedded D3D11 compatibility conversion dropped a frame: …` means a read-back or conversion
failed and that frame was skipped; a steady stream of them is a defect, not noise.

In Settings, DirectX 11 should be selectable and show "Hardware decoding", color depth should
offer 8-bit 4:2:0 only, HDR should stay off, and DirectX 12 should remain disabled.

## Validation status

Host-runnable unit tests cover the parts that do not need a GPU: feature tiers and the format
ceiling, requested feature level order, swap chain profile selection, NV12-to-RGBA8 conversion
math (limited range, both matrices, chroma siting, aperture offsets), and the compatibility
capability report.

```sh
cargo test --manifest-path native/opennow-streamer/Cargo.toml -p opennow-streamer-platform-windows --lib
cargo test --manifest-path native/opennow-streamer/Cargo.toml -p opennow-streamer-platform --lib
```

The rest needs DirectX 10 hardware and is not covered by CI: the Windows x64 lane runs on a
GitHub-hosted desktop whose D3D11 device exposes no video interfaces, so the existing GPU
tests skip at that probe (`E_NOINTERFACE`), and no runner in this repository presents a real
10_x device. Device creation at 10_0/10_1, staging read-back of a decoded NV12 array slice,
Shader Model 4.0 compilation, the bitblt present, and end-to-end session behaviour on such a
GPU therefore require a manual pass on the target hardware before this is called accepted. See
the [Qt acceptance runbook](qt-acceptance.md).
