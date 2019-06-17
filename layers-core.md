# Core of layers

> Work in progress.

## Goals of the document
The purpose of this document is to provide some implementation details for User Agents to experiment with multiple layers. 
* Introduce a concept of "image sources" and the way how user's code provides layers with rendering to be composed into HMD screen(s);
* Explain why `XRWebGLLayer` must be replaced with new `XRLayerProjection` layer;
* Provide with some code samples to explain how new concepts should be used;
* Provide with partial IDL for the related types. 
* Anything else?

## Non-goals
* This document doesn't provide details for any specific layer types.
* General information about layers and the proposal is provided in different [document](multi-layer.md).
* Anything else?

## Why layer image source
Layers require image source that is used for the rendering. In order to achieve maximum performance and to avoid extra texture copies, the image sources might be implemented as direct compositor swapchains under-the-hood. See [here](details.md) for more details. 

## Why XRWebGLLayer has to be changed?
Once image source concept is introduced, shouldn't we modify XRWebGLLayer to use it instead of explicit reference to framebuffer or texture array (for the XRWebGLArrayLayer)? By doing this, we could avoid introducing an extra XRWebGLArrayLayer type for multiview support in this case. Alternatively, we can introduce a new layer type.


## Layer image source
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

### Anti-aliasing

Unfortunately, even WebGL 2 has limited functionality in terms of supporting multisampling rendering into a texture. There is no way to render directly into a texture with implicit multi-sampling (there is no WebGL analog of the `GL_EXT_multisampled_render_to_texture` GL extension). Using multi-sampled renderbuffers is possible in WebGL 2.0, but it involves extra copying (blitting from the renderbuffer to a texture to explicitly resolve). But it is still impossible to render into a texture array with anti-aliasing, even with the new `OVR_multiview2` extension.

To address this performance and compatibility issue, I think to introduce an `XRLayerFramebufferImage`, that will create an opaque framebuffer with multi-sampling support, similarly to what is used for `XRWebGLLayer`.
> **TODO** Verify with WebGL folks

It also may have the multiview flag.

> **TODO** What are we going to do with multiview? Multiview has the same issue, `OVR_multiview2` has no way to render into the texture array with anti-aliasing.

### Stereo vs mono
The Quad, Cylinder, Equirect and Cube layers may be used for rendering either as stereo (when the image is different for each eye) or as mono (when both eyes use the same image). For simplicity reasons, I propose to use similar approach to the OpenXR API, where the layer has `XRLayerEyeVisibility` attribute that can have values `both`, `left` and `right`. This attributes controls which of the viewer's eyes to display the layer to. For mono rendering the `both` should be used. This approach provides 1:1 ratio between the layers and image sources, i.e. there is only one image source per layer, regardless whether it is the "stereo" or "mono" layer.

For rendering stereo content it would be necessary to create two layers, one with `left` eye visibility attribute and another one with the `right` one. Both layers may reference to the same `XRLayerImageSource`, but most likely they should use different `XRLayerSubImage` with different texture rectangle or layer index; the `XRLayerSubImage` type defines which part of the image source should be used for the rendering of the particular eye. It is also possible to use completely different `XRLayerImageSource` per eye: for example, the `XRCubeLayer` should use different image sources for left and right eye, in the case when stereo cube map rendering is wanted.

```webidl
[ SecureContext, Exposed=Window ] interface XRLayerSubImage {
  readonly attribute XRLayerImageSource imageSource;
  readonly attribute FrozenArray<float> imageRectUV; // 2D rect in UV space
  readonly attribute long imageArrayIndex;
};
```

## Appendices

### IDL (excerpts)

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

dictionary XRLayerInit {
  boolean chromaticAberrationCorrection = false;
  boolean blendTextureSourceAlpha = false;
};

[ SecureContext, Exposed=Window] partial interface XRLayer {
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
