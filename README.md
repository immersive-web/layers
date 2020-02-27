# Layers in WebXR
> Work in progress.
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

Another example where composition layers are going to shine is displaying text or high resolution textures in the virtual world. Since composition layers allow to sample source texture at full resolution without multiple re-samplings the readability of the text is going to be significantly improved.

## Usage

Using the Layers API consists of three primary steps:

  1. Creating the layers with a given graphics API.
  1. Positioning the layers and adding them to the session's layers array.
  1. Rendering to the graphics API resources during the frame loop.

### Graphics API binding

When a layer is created it is backed by a GPU resource, typically a texture, provided by one of the Web platform's graphics APIs. In order to specify which API is providing the layer's GPU resources an Layer Factory for the API in question must be created. For example, creating a layer factory for WebGL would function like this:

```js
const canvas = document.createElement('canvas');
const gl = canvas.getContext('webgl', { xrCompatible: true });
const glLayerFactory = new XRWebGLLayerFactory(xrSession, gl);
```

The same layer factory could also accept WebGL 2.0 contexts.

Future graphics APIs will interface with WebXR in the same way. A theoretical WebGPU graphics binding (which is not being proposed at this time and is offered only for illustrative purposes) may look like this:

```js
const gpuAdapter = await navigator.gpu.requestAdapter({ xrCompatible: true });
const gpuDevice = await gpuAdapter.requestDevice();
const glLayerFactory = new XRWebGPULayerFactory(xrSession, gpuDevice);
```

Each graphics API may have unique requirements that must be satisfied before a context can be used in the creation of a layer factory. For example, a `WebGLRenderingContext` must have its `xrCompatible` flag set prior to being passed to the constructor of the `XRWebGLLayerFactory` instance.

Any interaction between the `XRSession` the graphics API, such as allocating or retrieving textures, will go through this `XRWebGLLayerFactory` instance, and the exact mechanics of the interaction will typically be API specific. This allows the rest of the WebXR API to be graphics API agnostic and more easily adapt to future advances in rendering techniques.

## Layer creation

Once a layer factory instance has been acquired, it can be used to create a variety of `XRLayer`s. Any layers created by that layer factory will then be able to query the associated GPU resources each frame, generally expected to be the native API's texture interface.

The various layer types are created with the  `request____Layer` series of methods on the layer factory instance. Information about the graphics resources required, such as whether or not to allocate a depth buffer or alpha channel, are passed in at layer creation time and will be immutable for the lifetime of the layer. The method will return a promise that will resolve to the associated `XRLayer` type once the graphics resources have been created and the layer is ready to be displayed.

The graphics API the layer factory was created with may also require API-specific information be provided. For instance, the `XRWebGLLayerFactory` requires that the texture target desired be specified.

```js
const canvas = document.createElement('canvas');
const gl = canvas.getContext('webgl', { xrCompatible: true });
const glLayerFactory = new XRWebGLLayerFactory(xrSession, gl);
const layer = await glLayerFactory.requestProjectionLayer(gl.TEXTURE_2D, { alpha: false });
```

This will allocate a layer that supplies a 2D texture as it's output surface, which will then be subdivided into viewports for each `XRView`. If the context passed into the `XRWebGLLayerFactory` was a WebGL 2.0 the developer could optionally choose to allocate a texture array instead, in which every `XRView` will be rendered into a separate level of the array. This allows for some rendering optimizations, such as the use of the `OVR_multiview` extension, to be used.

```js
const canvas = document.createElement('canvas');
const gl = canvas.getContext('webgl2', { xrCompatible: true });
const glLayerFactory = new XRWebGLLayerFactory(xrSession, gl);
const layer = await glLayerFactory.requestProjectionLayer(gl.TEXTURE_2D_ARRAY, { alpha: false });
```

Layer types other than an `XRProjectionLayer` must be given an explicit pixel width and height, as well as whether or not the image should be stereo or mono. This is because those properties cannot be inferred from the hardware or layer type as they can with an `XRProjectionLayer`.

```js
const layer = await glLayerFactory.requestQuadLayer(gl.TEXTURE_2D, { pixelWidth: 1024, pixelHeight: 768, stereo: true });
```

Passing `true` for stereo here indicates that you are able to provide stereo imagery for this layer, but if the XR device is unable to display stereo imagery it may automatically force the layer to be created as mono instead to reduce memory and rendering overhead. Layers that are created as mono will never be automatically changed to stereo, regardless of hardware capabilities. Developers can check the `stereo` attribte of the resulting layer to determine if the layer was allocated with resources for stereo or mono rendering.

Some layer types may not be supported by the `XRSession`. If a layer type isn't supported the returned `Promise` will reject. `XRProjectionLayer` _must_ be supported by all `XRSession`s.

## Layer positioning and shape

Non-projection layers each have attributes that control where the layer is shown and how it's shaped. For example, the positioning of an `XRQuadLayer` is handled like so:

```js
const quadLayer = await glLayerFactory.requestQuadLayer(gl.TEXTURE_2D, { pixelWidth: 512, pixelHeight: 512 });
// Position 2 meters away from the origin of xrReferenceSpace with a width and height of 1.5 meters
quadLayer.referenceSpace = xrReferenceSpace;
quadLayer.transform = new XRRigidTransform({z: -2});
quadLayer.width = 1.5;
quadLayer.height = 1.5;
```

This explainer will not cover the details of positioning and shaping every possible layer. For additional details please see the separate explainers for each layer type:

  - [XRQuadLayer](./quad.md)
  - [XRCylinderLayer](./cylinder.md)
  - [XREquirectLayer](./equirect.md)
  - [XRCubeLayer](./cubemap.md)

## Setting the layers array

Layers are not presented to the XR device until they have been added to the `layers` `XRRenderState` property with the `updateRenderState()` method. Setting the `layers` array will override the `baseLayer` if one is present, with `baseLayer` reporting the first element in the `layers` array. Layers will be presented in the order they are given in the `layers` array, with layers being given in "back-to-front" order. Layers may have alpha blending applied if the layer's `blendSourceAlpha` attribute is `true`, but no depth testing may be performed between layers.

In addition to the `XRLayer`-derived types, the existing `XRWebGLLayer` may be passed to the layers array as well. This layer type remains useful as a mechanism for rendering antialiased content with WebGL 1.0 contexts. `XRWebGLLayer` functions as an `XRProjectionLayer`, but they are kept as distinct types for better forwards compatibility.

```js
const projectionLayer = new XRWebGLLayer(xrSession, gl);
const quadLayer = await glLayerFactory.requestQuadLayer(gl.TEXTURE_2D, { pixelWidth: 1024, pixelHeight: 1024 });

xrSession.updateRenderState({ layers: [projectionLayer, quadLayer] });
```

`updateRenderState()` _may_ throw an exception if more layers are specified than the `XRSession` supports simultaneously.

## Rendering

During `XRFrame` processing each layer can be updated with new imagery. Calling `getViewSubImage()` with a view from the `XRFrame` will return an `XRSubImage` indicating the textures to use as the render target and what portion of the texture will be presented to the `XRView`'s associated physical display.

WebGL layers allocated with the `TEXTURE_2D` target will provide sub images with a unique, non-overlapping `viewport` and `imageIndex` of `0` for each `XRView`.

```js
// Render Loop for a projection layer with a WebGL framebuffer source.
const glLayerFactory = new XRWebGLLayerFactory(xrSession, gl);
const layer = await glLayerFactory.requestProjectionLayer(gl.TEXTURE_2D);
const framebuffer = gl.createFramebuffer();

xrSession.updateRenderState({ layers: [layer] });
xrSession.requestAnimationFrame(onXRFrame);

function onXRFrame(time, xrFrame) {
  xrSession.requestAnimationFrame(onXRFrame);

  gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);

  let subImage = glLayerFactory.getSubImage(layer);
  gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0,
    subImage.colorTexture, 0);
  gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT,
    subImage.depthStencilTexture, 0);

  for (let view in xrViewerPose.views) {
    let viewport = glLayerFactory.getViewSubImage(layer, view).viewport;
    gl.viewport(viewport.x, viewport.y, viewport.width, viewport.height);

    // Render from the viewpoint of xrView
  }
}
```

WebGL layers allocated with the `TEXTURE_2D_ARRAY` target will provide sub images with the same `viewport` and a unique `imageIndex` indicating the texture layer to render to for each `XRView`.

```js
// Render Loop for a projection layer with a WebGL framebuffer source.
const glLayerFactory = new XRWebGLLayerFactory(xrSession, gl);
const layer = await glLayerFactory.requestProjectionLayer(gl.TEXTURE_2D_ARRAY);
const framebuffer = gl.createFramebuffer();

xrSession.updateRenderState({ layers: [layer] });
xrSession.requestAnimationFrame(onXRFrame);

function onXRFrame(time, xrFrame) {
  xrSession.requestAnimationFrame(onXRFrame);

  gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
  let viewport = glLayerFactory.getSubImage(layer).viewport;
  gl.viewport(viewport.x, viewport.y, viewport.width, viewport.height);

  for (let view in xrViewerPose.views) {
    let subImage = glLayerFactory.getViewSubImage(layer, view);
    gl.framebufferTextureLayer(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0,
      subImage.colorTexture, 0, subImage.imageIndex);
    gl.framebufferTextureLayer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT,
      subImage.depthStencilTexture, 0, subImage.imageIndex);

    // Render from the viewpoint of xrView
  }
}
```

For some non-projection layers, such as a mono `XRQuadLayer` being shown on a stereo device, multiple `XRView`s may return the same `XRSubImage` values. To avoid rendering the same view multiple times in these scenarios mono layers can be rendered just once using the `XRSubImage` provided by the the layer factory's `getSubImage()` method.

```js
// Render Loop for a projection layer with a WebGL framebuffer source.
const glLayerFactory = new XRWebGLLayerFactory(xrSession, gl);
const quadLayer = await glLayerFactory.requestQuadLayer(gl.TEXTURE_2D, {
  pixelWidth: 512, pixelHeight: 512, stereo: false
});
// Position 2 meters away from the origin with a width and height of 1.5 meters
quadLayer.referenceSpace = xrReferenceSpace;
quadLayer.transform = new XRRigidTransform({z: -2});
quadLayer.width = 1.5;
quadLayer.height = 1.5;

const framebuffer = gl.createFramebuffer();

xrSession.updateRenderState({ layers: [quadLayer] });
xrSession.requestAnimationFrame(onXRFrame);

function onXRFrame(time, xrFrame) {
  xrSession.requestAnimationFrame(onXRFrame);

  gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
  let subImage = glLayerFactory.getSubImage(quadLayer);
  gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0,
    subImage.colorTexture, 0);
  let viewport = subImage.viewport;
  gl.viewport(viewport.x, viewport.y, viewport.width, viewport.height);

  // Render content for the quad layer
}
```

## Appendix A: Proposed IDL

```webidl
//
// Layer interface
//

interface XRSubImage {
  readonly attribute XRViewport viewport;
  readonly attribute unsigned long imageIndex;
};

interface XRWebGLSubImage : XRSubImage {
  readonly attribute WebGLTexture colorTexture;
  readonly attribute WebGLTexture? depthStencilTexture;
};

interface XRLayer {
  readonly attribute unsigned long pixelWidth;
  readonly attribute unsigned long pixelHeight;

  attribute boolean blendTextureSourceAlpha;
  attribute boolean chromaticAberrationCorrection;

  void destroy();
};

//
// Layer types
//

interface XRProjectionLayer : XRLayer {
  readonly attribute boolean ignoreDepthValues;
}

interface XRQuadLayer : XRLayer {
  readonly attribute boolean stereo;
  attribute XRRigidTransform transform;

  attribute float width;
  attribute float height;
};

interface XRCylinderLayer : XRLayer {
  readonly attribute boolean stereo;
  attribute XRReferenceSpace referenceSpace;

  attribute XRRigidTransform transform;
  attribute float radius;
  attribute float centralAngle;
  attribute float aspectRatio;
};

interface XREquirectLayer : XRLayer {
  readonly attribute boolean stereo;
  attribute XRReferenceSpace referenceSpace;

  attribute XRRigidTransform transform;
  attribute float radius = 1;
  attribute float scaleX = 1;
  attribute float scaleY = 1;
  attribute float biasX = 0;
  attribute float biasY = 0;
};

interface XRCubeLayer : XRLayer {
  readonly attribute boolean stereo;
  attribute XRReferenceSpace referenceSpace;

  attribute DOMPoint orientation;
};

//
// Graphics Bindings
//

dictionary XRProjectionLayerInit {
  boolean depth = true;
  boolean stencil = false;
  boolean alpha = true;
  double scaleFactor = 1.0;
};

dictionary XRLayerInit {
  required unsigned long pixelWidth;
  required unsigned long pixelHeight;
  boolean stereo = false;
  boolean depth = false; // This is a change from typical WebGL initialization, but feels approrpriate.
  boolean stencil = false;
  boolean alpha = true;
};

interface XRWebGLLayerFactory {
  constructor(XRSession session, XRWebGLRenderingContext context);

  readonly attribute double nativeProjectionScaleFactor;

  Promise<XRProjectionLayer> requestProjectionLayer(GLenum textureTarget, XRProjectionLayerInit init);
  Promise<XRQuadLayer> requestQuadLayer(GLenum textureTarget, XRLayerInit init);
  Promise<XRCylinderLayer> requestCylinderLayer(GLenum textureTarget, XRLayerInit init);
  Promise<XREquirectLayer> requestEquirectLayer(GLenum textureTarget, XRLayerInit init);
  Promise<XRCubeLayer> requestCubeLayer(XRLayerInit init);

  XRWebGLSubImage? getSubImage(XRLayer layer); // for mono layers
  XRWebGLSubImage? getViewSubImage(XRLayer layer, XRView view); // for stereo layers
};
```

## Appendix B: Open Questions

  - Sensible defaults of all the layer values.
  - Do we need an attribte to communicate max number of supported layers?
