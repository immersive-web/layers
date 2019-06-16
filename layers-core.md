### Additional changes
* Introduce a concept of "image source" for layers and a way to create / request image sources from the UA;
* Optionally, change [XRWebGLLayer](https://immersive-web.github.io/webxr/#xrwebgllayer-interface) to comply with the new concepts of XRLayer and image source. Or, we can leave it as is and replace it with a different layer once we are ready.

#### Additions to XRLayer / XRLayerInit
Some common properties and methods could be added to XRLayer / XRLayerInit. See [here](details.md) for more details.

#### Layer image source
Layers require image source that is used for the rendering. In order to achieve maximum performance and to avoid extra texture copies, the image sources might be implemented as direct compositor swapchains under-the-hood. See [here](details.md) for more details. 

#### Optional changes to XRWebGLLayer
Once image source concept is introduced, shouldn't we modify XRWebGLLayer to use it instead of explicit reference to framebuffer or texture array (for the XRWebGLArrayLayer)? By doing this, we could avoid introducing an extra XRWebGLArrayLayer type for multiview support in this case. Alternatively, we can introduce a new layer type.


### Proposed types of layers
Not all layers are going to be supported by all hardware/browsers. We would need to figure out the bare minimum of layer types to be supported. I have the following ones in mind: the transparent or opaque quadrilateral, cubemap, cylindrical and equirect layers. Additionally, we might want to replace the `XRWebGLLayer` by the another layer that uses image source instead of an opaque framebuffer.

 
* Introduce different subtypes to [XRLayer](https://immersive-web.github.io/webxr/#xrlayer-interface) which will have all the necessary attributes for each layer.


* Define ways to provide image source to layers; such image sources should be able to wrap internal high-efficient zero-copying render targets (such as "compositor swapchains");

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

#### Additions to XRLayer / XRLayerInit
```webidl
partial dictionary XRLayerInit {
  boolean chromaticAberrationCorrection = false;
  boolean blendTextureSourceAlpha = false;
};

[ SecureContext, Exposed=Window ] partial interface XRLayer {
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
