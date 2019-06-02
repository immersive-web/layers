### Layers in WebXR

Current WebXR spec is written with layers in mind (see [XRLayer interface](https://immersive-web.github.io/webxr/#xrlayer-interface)), however, only a single layer ([baseLayer](https://immersive-web.github.io/webxr/#dom-xrrenderstate-baselayer)) is currently supported.

Other XR APIs (such as OpenXR, Oculus PC & Mobile SDKs, Unreal & Unity game engines, more? tbd) support so called 'composition' or 'timewarp' layers.

### Summary

#### Problems to solve
* Performance and judder
  
  Composition layers are presented at the frame rate of the compositor (i.e. native refresh rate of HMD) rather than at the application frame rate. Even when the application is not updating the layer's rendering at the native refresh rate of the compositor, the compositor still might be able to re-project the existing rendering to the proper pose. This means smoother rendering and less judder.
  
  A powerful feature of layers is that each of them may have different resolution. This allows the application to scale down the main eye buffer resolution on low performance systems, but keeping essential information, such as text or a map, in a different layer at a higher resolution.

* Legibility / visual fidelity 
  
  The resolution for eye-buffers for 3D world rendering can be set to relatively low values especially on low performance systems. It would be impossible to render high fidelity content, such as text, in this case. As it was mentioned above, each layer may have its own resolution and it will be re-sampled only once by the compositor (in contrary to the traditional approach with rendering layers via WebGL where the layer's content got re-sampled at least twice: once when rendering into WebGL eye-buffer (and losing a lot of details due to limited eye-buffer resolution) and the second time by the compositor).

* Power consumption / battery life

  Power consumption is super critical for mobile AR/VR headsets. Due to reduced rendering pipeline, lack of double sampling, no need to update the layer's rendering each frame the power consumption is expected to be improved versus traditional way of rendering and compositing layers via WebGL.

* Latency

  Pose sampling for composition layers may occur at the very end of the frame and then certain techniques could be used to update the layer's pose to match it with the most recent HMD pose. Such techniques include, but not limited to, Asynchronous Timewarp, Asynchronous Spacewarp, Positional Timewarp, etc. This may significantly reduce the effective latency for the layers' rendering and as a result improve overall experience.

#### Goals of the proposal
The idea of the proposal is to add pretty basic concept of the layers into WebXR spec and agree on general approach. 
* Introduce a concept of layers into WebXR spec and the way how layers should be provided from user's code to Browser;
* Define ways to get layers capabilities, such as maximum number of supported layers, supported types of layers, etc;
* Define ways to provide image source to layers; such image sources should be able to wrap internal high-efficient zero-copying render targets (such as "compositor swapchains");
* Make sure the layers' part of the WebXR spec is extensible for any future additions and minimizing need for breaking changes in future.

### Examples of use cases

Composition layers are useful for displaying information, text, video, or textures that are intended to be focal objects in your scene. Composition layers could also be useful for displaying simple environments and backgrounds to your scene.

One of the very common use cases of WebXR is 180 and/or 360 photos or videos, both - equirect and cubemaps. Usual implementation involves a lot of CPU and GPU power and the result is usually pretty poor in terms of visual quality, latency and power consumption (the latter is especially critical for mobile / standalone devices, such as Oculus Go, Quest, Vive Focus, ML1, HoloLens, etc).

Another example where composition layers are going to shine is displaying text or high resolution textures in the virtual world. Since composition layers allow to sample source texture at full resolution without downsampling to the resolution of the eye buffers (which is usually much lower than the physical resolution of the device's screen(s)) the readability of the text is going to be significantly improved.


### Implementation overview

A very high-level description of the implementation could be this:
* Replace the [XRRenderState](https://immersive-web.github.io/webxr/#xrrenderstate-interface)'s [baseLayer](https://immersive-web.github.io/webxr/#dom-xrrenderstate-baselayer) with the sequence of [XRLayer](https://immersive-web.github.io/webxr/#xrlayer-interface)s;
* Layers are drawn in the same order as they are specified in via `XRSession/updateRenderState`, with the
0th layer drawn first. Layers are drawn with a "painter’s algorithm," with each successive layer potentially overwriting the destination layers whether or not the new layers are virtually closer to the
viewer.
* Introduce a way to determine which layers are supported and what is the maximum amount of the layers supported (fingerprinting?);
* Add common properties to [XRLayer](https://immersive-web.github.io/webxr/#xrlayer-interface) (such as chromatic aberration or alpha blending flags);
* Introduce a concept of "image source" for layers and a way to create / request image sources from the UA;
* Optionally, change [XRWebGLLayer](https://immersive-web.github.io/webxr/#xrwebgllayer-interface) to comply with the new concepts of XRLayer and image source. Or, we can leave it as is and replace it with `XRLayerProjection` once we are ready;
* Introduce different subtypes to [XRLayer](https://immersive-web.github.io/webxr/#xrlayer-interface) which will have all the necessary attributes for each layer.

All of these changes could be split into two categories: "breaking changes" and "additive changes".

### Breaking changes

#### Changes in XRRenderState

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

##### Drawing layers 
As was mentioned before, the drawing algorithm is as simple as a "painter's algorithm" where layers render in order of their appearance in the sequence, with the 0th layer drawn first (usually, the 0th layer is the eye-buffer one). Each successive layer potentially overwriting the destination layers whether or not the new layers are virtually closer to the viewer. There is no depth testing between the layers. 
Layer's visibility is controlled by presence (or absence) the layer in the sequence. To hide or show a layer - call [updateRenderState](https://immersive-web.github.io/webxr/#dom-xrsession-updaterenderstate) and provide a new sequence of layers.

#### Optional changes to XRWebGLLayer
Having XRLayerSourceImage concept introduced, shouldn't we modify XRWebGLLayer to use it instead of explicit reference to framebuffer or texture array (for the XRWebGLArrayLayer)? By doing this, we could avoid introducing an extra XRWebGLArrayLayer type for multiview support in this case. Alternatively, we can introduce a new layer type - `XRLayerProjection`, similarly to what OpenXR has.

### Additive changes

#### Changes to XRLayer / XRLayerInit
```webidl
dictionary XRLayerInit {
  boolean chromaticAberrationCorrection = false;
  boolean blendTextureSourceAlpha = false;
};

[ SecureContext, Exposed=Window ] interface XRLayer {
  readonly attribute boolean chromaticAberrationCorrection;
  readonly attribute boolean blendTextureSourceAlpha;
  
  void requestUpdate();
};
```
There are certain properties / attributes of layers which are common across all types of the layers. Such common attributes should be declared in base XRLayer and XRLayerInit types:
* `chromaticAberrationCorrection` - controls chromatic aberration correction on per-layer basis. This would be beneficial for the layers like Quads and Cylinders, especially with the text.
* `blendTextureSourceAlpha` - enables the layer's texture alpha channel; when it is set to `true` then the layer composition uses the alpha channel for the blending of the layer's image against the destination. The image's color channels must be encoded with premultiplied alpha. When the image has no alpha channel then this flag is ignored. If this flag is not set then the image is treated as if each texel is opaque, regardless of the presence of an alpha channel.
The blending opration between the source and destination is an addition. The formula for the blending of each color component is as follows: `destination_color = (source_color + (destination_color * (1 - source_alpha)))`.
> **TODO** Verify with WebGL folks

##### Added methods to XRLayer
* `void requestUpdate()` - the method that should be called to indicate the layer's content changed; by default, browser should assume that the content of the layers (image source) is not updated.
> **TODO** Should we add a way to control layer's visibility or, just use `XRSession/updateRenderState` if layer's visibility changes?

#### Layer image source
Layers require image source that is used for the rendering. In order to achieve maximum performance and to avoid extra texture copies, the image sources might be implemented as direct compositor swapchains under-the-hood. The proposed image sources are as follows:
* `XRLayerImageSource` and `XRLayerImageSourceInit` - the base types;
* `XRLayerTextureImage` - the WebGLTexure is exposed, so the content can be copied or rendered into it. This image source can be created using `XRLayerTextureImageInit` object. For `XRCubeLayer` the `cube` flag should be set to `true` at the creation time of the image source.
* `XRLayerTextureArrayImage` - the WebGLTexture, that represents texture array is exposed, so the content can be copied or rendered into layers of it. Layer 0 represents the left eye image, 1 - the right eye image. The `XRLayerTextureArrayImageInit` object is used for creation of this image source.
* `XRLayerFramebufferImage` - the opaque WebGLFramebuffer is exposed, see 'Anti-aliasing' below. The `XRLayerFramebufferImageInit` is used for creation of this image source.

Each image source could be referenced many times from different layers. The `XRLayerSubImage` can be used to specify which area of the image source should be used by the layer.

> **TODO** Verify necessity of all of these image sources, or do we need more?

> **TODO** Document all the image sources here

> **TODO** Add all necessary methods to each image source.

> **TODO** Add `XRLayerDOMImage` and `XRLayerVideoImage`

#### Anti-aliasing

Unfortunately, even WebGL 2 has limited functionality in terms of supporting multisampling rendering into a texture. There is no way to render directly into a texture with implicit multi-sampling (there is no WebGL analog of the `GL_EXT_multisampled_render_to_texture` GL extension). Using multi-sampled renderbuffers is possible in WebGL 2.0, but it involves extra copying (blitting from the renderbuffer to a texture to explicitly resolve). But it is still impossible to render into a texture array with anti-aliasing, even with the new `OVR_multiview2` extension.

To address this performance and compatibility issue, I think to introduce an `XRLayerFramebufferImage`, that will create an opaque framebuffer with multi-sampling support, similarly to what is used for `XRWebGLLayer`.
> **TODO** Verify with WebGL folks

It also may have the multiview flag.

> **TODO** What are we going to do with multiview? Multiview has the same issue, `OVR_multiview2` has no way to render into the texture array with anti-aliasing.

#### Stereo vs mono
The Quad, Cylinder, Equirect and Cube layers may be used for rendering either as stereo (when the image is different for each eye) or as mono (when both eyes use the same image). For simplicity reasons, I propose to use similar approach to the OpenXR API, where the layer has `XRLayerEyeVisibility` attribute that can have values `both`, `left` and `right`. This attributes controls which of the viewer's eyes to display the layer to. For mono rendering the `both` should be used. This approach provides 1:1 ratio between the layers and image sources, i.e. there is only one image source per layer, regardless whether it is the "stereo" or "mono" layer.

For rendering stereo content it would be necessary to create two layers, one with `left` eye visibility attribute and another one with the `right` one. Both layers may reference to the same `XRLayerImageSource`, but most likely they should use different `XRLayerSubImage` with different texture rectangle or layer index; the `XRLayerSubImage` type defines which part of the image source should be used for the rendering of the particular eye. It is also possible to use completely different `XRLayerImageSource` per eye: for example, the `XRCubeLayer` should use different image sources for left and right eye, in the case when stereo cube map rendering is wanted.

```webidl
[ SecureContext, Exposed=Window ] interface XRLayerSubImage {
  readonly attribute XRLayerImageSource imageSource;
  readonly attribute FrozenArray<float> imageRectUV; // 2D rect in UV space
  readonly attribute long imageArrayIndex;
};
```
### Proposed types of layers
Not all layers are going to be supported by all hardware/browsers. We would need to figure out the bare minimum of layer types to be supported. I have the following ones in mind: the transparent or opaque quadrilateral, cubemap, cylindrical and equirect layers. Additionally, we might want to replace the `XRWebGLLayer` by the `XRLayerProjection` one.

## IDL (excerpts)

```webidl
typedef (WebGLRenderingContext or WebGL2RenderingContext) XRWebGLRenderingContext;

dictionary XRRenderStateInit {
  double depthNear;
  double depthFar;
  double inlineVerticalFieldOfView;
  XRPresentationContext? outputContext;

  sequence<XRLayer>? layers;
};

[SecureContext, Exposed=Window] interface XRRenderState {
  readonly attribute double depthNear;
  readonly attribute double depthFar;
  readonly attribute double? inlineVerticalFieldOfView;
  readonly attribute XRPresentationContext? outputContext;

  readonly attribute FrozenArray<XRLayer>? layers;
};

dictionary XRLayerInit {
  boolean chromaticAberrationCorrection = false;
  boolean blendTextureSourceAlpha = false;
};

[ SecureContext, Exposed=Window] interface XRLayer {
  readonly attribute boolean chromaticAberrationCorrection;
  readonly attribute boolean blendTextureSourceAlpha;
  
  void requestUpdate();
};

enum XRLayerEyeVisibility {
  "both",
  "left",
  "right" 
};

[ SecureContext, Exposed=Window ] interface XRLayerImageSource {
};

/////////////////////////
dictionary XRLayerTextureImageInit {
  unsigned long textureWidth;
  unsigned long textureHeight;
  boolean alpha = true;
  boolean cube = false;
};

[ SecureContext, Exposed=Window] interface XRLayerTextureImage : XRLayerImageSource {
  readonly attribute XRWebGLRenderingContext context;
  readonly attribute unsigned long textureWidth;
  readonly attribute unsigned long textureHeight;
  readonly attribute unsigned long textureInternalFormat;
  readonly attribute WebGLTexture texture;
  readonly attribute boolean cube;
};

/////////////////////////
dictionary XRLayerTextureArrayImageInit {
  boolean antialias = true;
  unsigned long arrayTextureWidth;
  unsigned long arrayTextureHeight;
  unsigned long arrayTextureDepth;
  boolean alpha = true;
};

[ SecureContext, Exposed=Window ] interface XRLayerTextureArrayImage : XRLayerImageSource {
  readonly attribute XRWebGLRenderingContext context;
  readonly attribute unsigned long arrayTextureWidth;
  readonly attribute unsigned long arrayTextureHeight;
  readonly attribute unsigned long arrayTextureDepth;
  readonly attribute unsigned long arrayTextureInternalFormat;
  readonly attribute WebGLTexture arrayTexture;
};

/////////////////////////
dictionary XRLayerFramebufferImageInit {
  boolean antialias = true;
  boolean depth = true;
  boolean stencil = false;
  boolean alpha = true;
  boolean ignoreDepthValues = false;
  unsigned long framebufferWidth;
  unsigned long framebufferHeight;
};

[ SecureContext, Exposed=Window ] interface XRLayerFramebufferImage : XRLayerImageSource {
  readonly attribute XRWebGLRenderingContext context;
  readonly attribute boolean antialias;
  readonly attribute boolean depth;
  readonly attribute boolean stencil;
  readonly attribute boolean alpha;
  readonly attribute boolean ignoreDepthValues;

  readonly attribute unsigned long framebufferWidth;
  readonly attribute unsigned long framebufferHeight;
  readonly attribute WebGLFramebuffer framebuffer;
};

//////////////////////////
[ SecureContext, Exposed=Window ] interface XRLayerSubImage {
  readonly attribute XRLayerImageSource imageSource;
  readonly attribute FrozenArray<float> imageRectUV; // 2D rect in UV space
  readonly attribute long imageArrayIndex;
};

dictionary XRWebGLLayerInit {
  boolean antialias = true;
  boolean depth = true;
  boolean stencil = false;
  boolean alpha = true;
  boolean ignoreDepthValues = false;
  double framebufferScaleFactor = 1.0;
};

[ SecureContext, Exposed=Window ] interface XRWebGLLayer : XRLayer {
  readonly attribute XRWebGLRenderingContext context;
  readonly attribute XRLayerSourceImage imageSource;

  XRViewport? getViewport(XRView view);

  static double getNativeFramebufferScaleFactor(XRSession session);
};
```

#### TO DO
This is a Work-In-Progress document and the following topics are not covered in details here. The topics which will be touched in separate documents:
* Specify each layer type (quad, cylinder, equirect, cubemap), provide details for properties / methods for each layer;
* DOM layers details; 
* Video layer details; 
* Hit-testable layers.
* Provide full IDL.

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






