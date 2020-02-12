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

When a layers is created it is typically backed a GPU resource, like a texture, provided by one of the Web platform's graphics APIs. In order to specify which API is providing the layer's GPU resources an `XRGraphicsBinding` instance for the API in question must be created. For example, creating a graphics binding for WebGL would function like this:

```js
const canvas = document.createElement('canvas');
const gl = canvas.getContext('webgl', { xrCompatible: true });
const xrGfx = new XRWebGLGraphicsBinding(xrSession, gl);
```

A session that wanted to take advantage of WebGL 2.0 techniques would alternatively create a `XRWebGL2GraphicsBinding` like so:

```js
const canvas = document.createElement('canvas');
const gl = canvas.getContext('webgl2', { xrCompatible: true });
const xrGfx = new XRWebGL2GraphicsBinding(xrSession, gl);
```

And a theoretical WebGPU graphics binding (which is not being proposed at this time and is offered only for illustrative purposes) may look like this:

```js
const gpuAdapter = await navigator.gpu.requestAdapter({ xrCompatible: true });
const gpuDevice = await gpuAdapter.requestDevice();
const xrGfx = new XRWebGPUGraphicsBinding(xrSession, gpuDevice);
```

Each graphics API may have unique requirements that must be satisfied before a context can be used in the creation of an `XRGraphicsBinding`. For example, a `WebGLRenderingContext` must have its `xrCompatible` flag set prior to being passed to the constructor of the `XRWebGLGraphicsBinding` instance.

Any interaction between the `XRSession` the graphics API, such as allocating or retrieving textures, will go through this `XRGraphicsBinding` instance, and the exact mechanics of the interaction will typically be API specific. This allows the rest of the WebXR API to be graphics API agnostic and more easily adapt to future advances in rendering techniques.

## Layer creation

Once an `XRGraphicsBinding` instance has been acquired, it can be used to create a variety of `XRLayer`s. Any layers created by that graphics binding will then be able to query associated GPU resources each frame, generally expected to be a texture or other render target expressed using the APIs native interfaces.

The various layer types are created with the  `request____Layer` series of methods on the `XRGraphicsBinding` instance. Information about the graphics resources required, such as whether or not to allocate a depth buffer or alpha channel, are passed in at layer creation time and will be immutable for the lifetime of the layer. The method will return a promise that will resolve to the associated `XRLayer` type once the graphics resources have been created and the layer is ready to be displayed.

```js
const xrGfx = new XRWebGLGraphicsBinding(xrSession, gl);
const layer = await xrGfx.requestProjectionLayer({ alpha: false });
```

Layer types other than an `XRProjectionLayer` must be given an explicit pixel width and height, as well as whether or not the image should be stereo or mono. This is because those properties cannot be inferred from the hardware or layer type as they can with an `XRProjectionLayer`.

```js
const xrGfx = new XRWebGLGraphicsBinding(xrSession, gl);
const layer = xrGfx.requestQuadLayer({ pixelWidth: 1024, pixelHeight: 768, stereo: true });
```

Passing `true` for stereo here indicates that you are able to provide stereo imagery for this layer source, but if the XR device is unable to display stereo imagery it may automatically force the layer to be created as mono instead to reduce memory and rendering overhead. Layers that are created as mono will never be automatically changed to stereo, regardless of hardware capabilities.

Some layer types may not be supported by either the `XRGraphicsBinding` or the `XRSession`. If the `XRGraphicsBinding` doesn't support a layer type it will simply lack a method for creating that layer type. If the `XRSession` doesn't support a layer type the returned Promise will reject. `XRProjectionLayer` _must_ be supported by all `XRSession`s and `XRGraphicsBinding`s.

## Layer positioning and shape

Non projection layers each have attributes that control where the layer is shown and how it's shaped. For example, the positioning of an `XRQuadLayer` is handled like so:

```js
const quadLayer = xrGfx.requestQuadLayer({ pixelWidth: 512, pixelHeight: 512, stereo: false });
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

```js
const projectionLayer = xrGfx.requestProjectionLayer();
const quadLayer = xrGfx.requestQuadLayer({ pixelWidth: 1024, pixelHeight: 1024 });

xrSession.updateRenderState({ layers: [projectionLayer, quadLayer] });
```

`updateRenderState()` _may_ throw an exception if more layers are specified than the `XRSession` supports simultaneously.

## Rendering

During `XRFrame` processing each layer can be updated with new imagery. Calling `getViewSubImage()` with a view from the `XRFrame` will return an `XRSubImage` indicating what section of the associated graphics resources will be presented to the view's associated physical display. If a layer source has not yet been set for the layer `getSubImage()` with return an `XRSubImage` with all values set to zero or false.

Every `XRGraphicsBinding` instance will also have a `getCurrent_____()` method that retrieves the graphics resources associated with a particular layer that should be rendered to for the current `XRFrame`. Calling this method indicates that the imagery should be updated, otherwise any previous rendering will be displayed again, reprojected if necessary.

```js
// Render Loop for a projection layer with a WebGL framebuffer source.
const xrGfx = new XRWebGLGraphicsBinding(xrSession, gl);
const layer = xrGfx.requestProjectionLayer();

xrSession.updateRenderState({ layers: [layer] });
xrSession.requestAnimationFrame(onXRFrame);

function onXRFrame(time, xrFrame) {
  xrSession.requestAnimationFrame(onXRFrame);

  for (let view in xrViewerPose.views) {
    let subImage = xrGfx.getViewSubImage(layer, view)
    gl.bindFramebuffer(gl.FRAMEBUFFER, subImage.frameBuffer);
    let viewport = subImage.viewport;
    gl.viewport(viewport.x, viewport.y, viewport.width, viewport.height);
    
    // Render from the viewpoint of xrView
  }
}
```

In some cases, such as a mono `XRQuadLayer` being shown on a stereo device, multiple `XRView`s may return the same `XRSubImage` values. To avoid rendering the same view multiple times in these scenarios the `primary` attribute of the `XRSubImage` will be be set to `false` for all but one of the overlapping views. (It should be noted that `XRProjectionLayer`s will never return `XRSubImage`s with `primary` set to false.)

```js
// Render Loop for a projection layer with a WebGL framebuffer source.
const xrGfx = new XRWebGLGraphicsBinding(xrSession, gl);

const quadLayer = xrGfx.requestQuadLayer({ pixelWidth: 512, pixelHeight: 512, stereo: false });
// Position 2 meters away from the origin with a width and height of 1.5 meters
quadLayer.referenceSpace = xrReferenceSpace;
quadLayer.transform = new XRRigidTransform({z: -2});
quadLayer.width = 1.5;
quadLayer.height = 1.5;

xrSession.updateRenderState({ layers: [quadLayer] });
xrSession.requestAnimationFrame(onXRFrame);

function onXRFrame(time, xrFrame) {
  xrSession.requestAnimationFrame(onXRFrame);

  for (let view in xrViewerPose.views) {
    let subImage = xrGfx.getViewSubImage(quadLayer, view);

    if (subImage.primary) {
      gl.bindFramebuffer(gl.FRAMEBUFFER, subImage.framebuffer);
      let viewport = subImage.viewport;
      gl.viewport(viewport.x, viewport.y, viewport.width, viewport.height);
      
      // Render content for view.eye
    }
  }
}
```

## Appendix A: Proposed IDL

```webidl
//
// Layer interface
//

interface XRSubImage {
  XRViewport viewport;
  boolean primary; // ??
  WebGLTexture? colorTexture;
  WebGLTexture? depthStencilTexture;
  WebGLFramebuffer? framebuffer;
}

interface XRLayer {
  readonly attribute unsigned long pixelWidth;
  readonly attribute unsigned long pixelHeight;
  readonly attribute boolean ignoreDepthValues;

  boolean blendTextureSourceAlpha = false;
  boolean chromaticAberrationCorrection = false;
}

//
// Layer types
//

interface XRProjectionLayer extends XRLayer {
}

interface XRQuadLayer extends XRLayer {
  attribute XRRigidTransform transform;
  attribute float width = 1;
  attribute float height = 1;
}

interface XRCylinderLayer extends XRLayer {
  XRReferenceSpace referenceSpace;
  attribute XRRigidTransform transform;
  attribute float radius = 1;
  attribute float centralAngle = Math.PI * 0.5;
  attribute float aspectRatio = 1;
}

interface XREquirectLayer extends XRLayer {
  XRReferenceSpace referenceSpace;
  attribute XRRigidTransform transform;
  attribute float radius = 1;
  attribute float scaleX = 1;
  attribute float scaleY = 1;
  attribute float biasX = 0;
  attribute float biasY = 0;
}

interface XRCubeLayer extends XRLayer {
  XRReferenceSpace referenceSpace;
  attribute DOMPoint orientation;
}

//
// Graphics Bindings
//

dictionary XRLayerInit {
  required unsigned int pixelWidth;
  required unsigned int pixelHeight;
  boolean framebuffer = true; // should it be false?
  boolean stereo = false;
  boolean depth = true;
  boolean stencil = false;
  boolean alpha = true;
  boolean ignoreDepthValues = false;
}

interface XRWebGLGraphicsBinding {
  constructor(XRSession session, WebGLRenderingContext context);

  double getNativeProjectionScaleFactor();

  Promise<XRProjectionLayer> requestProjectionLayer(XRWebGLLayerInit init); // Note different dictionary
  Promise<XRQuadLayer> requestQuadLayer(XRLayerInit init);
  Promise<XRCylinderLayer> requestCylinderLayer(XRLayerInit init);
  Promise<XREquirectLayer> requestEquirectLayer(XRLayerInit init);
  
  XRSubImage? getViewSubImage(XRLayer layer, XRView view);
}

interface XRWebGL2GraphicsBinding {
  constructor(XRSession session, WebGL2RenderingContext context);

  Promise<XRProjectionLayer> requestProjectionLayer(XRWebGLLayerInit init);
  Promise<XRQuadLayer> requestQuadLayer(XRLayerInit init);
  Promise<XRCylinderLayer> requestCylinderLayer(XRLayerInit init);
  Promise<XREquirectLayer> requestEquirectLayer(XRLayerInit init);
  Promise<XRCubeLayer> requestCubeLayer(XRLayerInit init); // Note only available with WebGL 2
  
  XRSubImage? getViewSubImage(XRLayer layer);
}
```

## Appendix B: Open Questions

  - Sensible defaults of all the layer values.
  - Do we need an attribte to communicate max number of supported layers?
  - Do we need to report on the layer source whether or not it's mono/stereo, since the XR device may force a downgrade?
  - Depth: Should we consider allowing a separate layer for this like OpenXR does, or continue pattern of allowing it's use by default (implies most layer types need to be able to allocate both a color and depth/stencil buffer)-
  - Should there be a way to explicitly dispose of a layer?
