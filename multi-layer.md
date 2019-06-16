# Layers in WebXR

## Why layers? What are the benefits?
Other XR APIs (such as OpenXR, Oculus PC & Mobile SDKs, Unreal & Unity game engines, more? tbd) support so called 'composition' layers. The benefits of layers are as follows:
* Performance and judder
  
  Composition layers are presented at the frame rate of the compositor (i.e. native refresh rate of HMD) rather than at the application frame rate. Even when the application is not updating the layer's rendering at the native refresh rate of the compositor, the compositor still might be able to re-project the existing rendering to the proper pose. This means smoother rendering and less judder.
  
  A powerful feature of layers is that each of them may have different resolution. This allows the application to scale down the main eye buffer resolution on low performance systems, but keeping essential information, such as text or a map, in a different layer at a higher resolution.

* Legibility / visual fidelity 
  
  The resolution for eye-buffers for 3D world rendering can be set to relatively low values especially on low performance systems. It would be impossible to render high fidelity content, such as text, in this case. As it was mentioned above, each layer may have its own resolution and it will be re-sampled only once by the compositor (in contrary to the traditional approach with rendering layers via WebGL where the layer's content got re-sampled at least twice: once when rendering into WebGL eye-buffer (and losing a lot of details due to limited eye-buffer resolution) and the second time by the compositor).

* Power consumption / battery life

  Power consumption is super critical for mobile AR/VR headsets. Due to reduced rendering pipeline, lack of double sampling, no need to update the layer's rendering each frame the power consumption is expected to be improved versus traditional way of rendering and compositing layers via WebGL.

* Latency

  Pose sampling for composition layers may occur at the very end of the frame and then certain reprojection techniques could be used to update the layer's pose to match it with the most recent HMD pose. This may significantly reduce the effective latency for the layers' rendering and as a result improve overall experience.

### Examples of use cases

Composition layers are useful for displaying information, text, video, or textures that are intended to be focal objects in your scene. Composition layers could also be useful for displaying simple environments and backgrounds to your scene.

One of the very common use cases of WebXR is 180 and/or 360 photos or videos, both - equirect and cubemaps. Usual implementation involves a lot of CPU and GPU power and the result is usually pretty poor in terms of visual quality, latency and power consumption (the latter is especially critical for mobile / standalone devices, such as Oculus Go, Quest, Vive Focus, ML1, HoloLens, etc).

Another example where composition layers are going to shine is displaying text or high resolution textures in the virtual world. Since composition layers allow to sample source texture at full resolution without downsampling to the resolution of the eye buffers (which is usually much lower than the physical resolution of the device's screen(s)) the readability of the text is going to be significantly improved.


## Goals of the proposal
The purpose of this document is to unlock the ability for User Agents to experiment with multiple layers. 
* Introduce a concept of layers into WebXR spec and the way how layers should be provided from user's code to Browser;
* Define ways to get layers capabilities, such as maximum number of supported layers, supported types of layers, etc;
* Make sure the layers' part of the WebXR spec is extensible for any future additions and minimizing need for breaking changes in future. The modified API should be compatible with all User Agents whether they support multiple layers or not. 

## Non-goals
* This document doesn't provide definitions for any specific layer types.
* Particular details of implementation will be provided in a different [document](details.md)


## Proposed changes

Current WebXR spec is written with layers in mind (see [XRLayer interface](https://immersive-web.github.io/webxr/#xrlayer-interface)), however, only a single layer ([baseLayer](https://immersive-web.github.io/webxr/#dom-xrrenderstate-baselayer)) is currently supported.

To support multiple layers the following changes are proposed:
* Replace the [XRRenderState](https://immersive-web.github.io/webxr/#xrrenderstate-interface)'s [baseLayer](https://immersive-web.github.io/webxr/#dom-xrrenderstate-baselayer) with the sequence of [XRLayer](https://immersive-web.github.io/webxr/#xrlayer-interface)s;
* Layers are drawn in the same order as they are specified in via `XRSession/updateRenderState`, with the
0th layer drawn first. Layers are drawn with a "painter’s algorithm," with each successive layer potentially overwriting the destination layers whether or not the new layers are virtually closer to the
viewer.
* Introduce a way to determine which layers are supported and what is the maximum amount of the layers supported (fingerprinting?);
* Add common properties to [XRLayer](https://immersive-web.github.io/webxr/#xrlayer-interface) (such as chromatic aberration or alpha blending flags);

The proposed IDL at the end of this document is for a reference only and not final by any means.

### Changes in XRRenderState

The proposed change to replace the [baseLayer](https://immersive-web.github.io/webxr/#dom-xrrenderstate-baselayer) in [XRRenderStateInit](https://immersive-web.github.io/webxr/#xrrenderstate-interface) and [XRRenderState](https://immersive-web.github.io/webxr/#xrrenderstate-interface) by the sequence of [XRLayer](https://immersive-web.github.io/webxr/#xrlayer-interface)s.

```webidl
dictionary XRRenderStateInit {
....
  sequence<XRLayer>? layers;
};

[SecureContext, Exposed=Window] interface XRRenderState {
....
  readonly attribute FrozenArray<XRLayer>? layers;
};
```

### Layers composition 
As was mentioned before, the drawing algorithm is a simple "painter's algorithm" where layers render in order of their appearance in the sequence, with the 0th layer drawn first (usually, the 0th layer is the eye-buffer one). Each successive layer potentially overwriting the destination layers whether or not the new layers are virtually closer to the viewer. There is no depth testing between the layers. 
Layer's visibility is controlled by presence (or absence) the layer in the sequence. To hide or show a layer - call [updateRenderState](https://immersive-web.github.io/webxr/#dom-xrsession-updaterenderstate) and provide a new sequence of layers.

### Adding layers capabilities
> **TODO** Introduce a way to determine which layers are supported and what is the maximum amount of the layers supported (fingerprinting?) 

## IDL (excerpts)

```webidl
typedef (WebGLRenderingContext or WebGL2RenderingContext) XRWebGLRenderingContext;

partial dictionary XRRenderStateInit {
  // baseLayer is removed

  sequence<XRLayer>? layers;
};

[SecureContext, Exposed=Window] partial interface XRRenderState {
  // baseLayer is removed

  readonly attribute FrozenArray<XRLayer>? layers;
};

```

## TO DO
This is a Work-In-Progress document and the following topics are not covered in details here. The topics which will be touched in separate documents:
* Specify each layer type (quad, cylinder, equirect, cubemap), provide details for properties / methods for each layer;
* DOM layers details; 
* Video layer details; 
* Hit-testable layers.
* Provide full IDL.
* Based on the foundation described in this document, a next set of functionality is being explored [here](details.md) that goes into more details about common parts of a multilayer system and enumerates potential layer types.```


## References
* [Khronos OpenXR API](https://www.khronos.org/openxr)
* [Oculus Mobile SDK Reference](https://developer.oculus.com/reference/mobile/1.18/)
* [Oculus PC SDK Reference](https://developer.oculus.com/documentation/pcsdk/latest/concepts/book-dg/)
* [Unreal Engine compositor layers](https://developer.oculus.com/documentation/unreal/latest/concepts/unreal-overlay/)
* [Unity Engine compositor layers](https://developer.oculus.com/documentation/unity/latest/concepts/unity-ovroverlay/)
* [Example of IDL for Quad layer](quad.md)
* [Example of IDL for Cylinder layer](cylinder.md)
* [Example of IDL for Equirect layer](equirect.md)
* [Example of IDL for Cubemap layer](cubemap.md)
* [Some more thoughts about details of layers implementation](details.md)






