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

  1. Creating, positioning, and sizing the layers to be shown.
  1. Creating graphics API resources to back the layers.
  1. Rendering to the graphics API resources during the frame loop.

### Layer creation

Layers are created by the `XRSession`, using the `requestLayer()` series of fuctions, patterned after the `requestReferenceSpace()` method. Unlike other `request...` methods this function does not return a `Promise`, since it's expected that layer construction will be fairly lightweight. It may return `null`, however, if the `XRSession` does not support the requested layer type. The only layer type that _must_ be supported is `"projection"`. The returned instance depends on the requested type, with each layer type corresponding to it's own interfaces which extends `XRLayer`.

```js
// Returns an XRProjectionLayer instance
const projectionLayer = xrSesssion.requestLayer('projection');
```

This explainer will not cover the details of every possible layer. For additional details please see the separate explainers for each layer type:

  - XRProjectionLayer
  - [XRQuadLayer](./quad.md)
  - [XRCylinderLayer](./cylinder.md)
  - [XREquirectLayer](./equirect.md)
  - [XRCubeLayer](./cubemap.md)

Layers are not presented to the XR device until they have been added to the `layers` `XRRenderState` property with the `updateRenderState()` method. Setting the `layers` array will override the `baseLayer` if one is present, with `baseLayer` reporting the first element in the `layers` array. Layers will be presented in the order they are given in the `layers` array, with each layers being given in "back-to-front" order. Layers may have alpha blending applied if the layer's `blendSourceAlpha` attribute is `true`, but no depth testing may be performed between layers.

```js
const projectionLayer = xrSesssion.requestLayer('projection');
const quadLayer = xrSesssion.requestLayer('quad');

xrSession.updateRenderState({ layers: [projectionLayer, quadLayer] });
```

`updateRenderState()` _may_ throw an exception if more layers are specified than the `XRSession` supports simultaneously.

### Graphics API binding

On their own, layers have no visual data, and will be ignored during compositing until provided with a backing `XRLayerSource`. A layer source is typically a GPU resource, like a texture, provided by one of the Web platform's graphics APIs. In order to specify which API is providing the layer sources an `XRGraphicsBinding` instance for the API in question must be created. For example, creating a graphics binding fow WebGL would function like this:

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

## Layer source allocation

Once an `XRGraphicsBinding` instance has been acquired, it can be used to create backing `XRLayerSource`s for each layer. What form this takes depends on the API being used, but is generally expected to be a texture or other render target expressed using the APIs native interfaces.

In all cases a `set____LayerSource` method will be called with the layer that the layer source is being created for, as well as any additional information needed to create the appropriate graphics resources. The method will return a promise that will resolve to the associated `XRLayerSource` type once the graphics resources have been created and the layer is ready to begin presenting images provided by the new layer source.

```js
const xrGfx = new XRWebGLGraphicsBinding(xrSession, gl);

const layer = xrSession.requestLayer('projection');
const source = await xrGfx.setFramebufferLayerSource(layer, { alpha: false });
```

If a layer source had previously been created for the passed layer it will become detached and the associated graphics resources discarded once the new layer source has been resolved. Creationg of new layer sources must not resolve until any pending `XRFrame` has been processed.

Depending on the layer type that the layer source is being created for, additional data may need to be provided in order to allocate graphics resources appropriately. For instance, layer types other than `"projection"` must be given an explicit pixel width and height, as well as whether or not the image should be stereo or mono. This is because those properties cannot be inferred from the hardware or layer type as they can with a `"projection"` layer.

```js
const xrGfx = new XRWebGLGraphicsBinding(xrSession, gl);

const layer = xrSession.requestLayer('quad');
const isStereo = true;
const source = await xrGfx.setFramebufferLayerSource(layer, 1024, 768, { stereo: true });
```

Passing `true` for stereo here indicates that you are able to provide stereo imagery for this layer source, but if the XR device is unable to display stereo imagery it may automatically force the layer to be created as mono instead to reduce memory and rendering overhead. Layers that are created as mono will never be automatically changed to stereo, regardless of hardware capabilities.

## Rendering

During `XRFrame` processing each layer source can be updated with new imagery. Calling `getViewSubImage()` with a view from the `XRFrame` will return an `XRSubImage` indicating what section of the associated graphics resources will be presented to the view's associated physical display. If a layer source has not yet been set for the layer `getSubImage()` with return an `XRSubImage` with all values set to zero or false.

Every layer source will also have a `getCurrent_____()` method that retrieves the graphics resources that should be rendered to for the current `XRFrame`. Calling this method indicates that the imagery should be updated, otherwise any previous rendering will be displayed again, reprojected if necessary.

```js
// Render Loop for a projection layer with a WebGL framebuffer source.
const xrGfx = new XRWebGLGraphicsBinding(xrSession, gl);

const layer = xrSession.requestLayer('projection');
const source = await xrGfx.setFramebufferLayerSource(layer);

xrSession.updateRenderState({ layers: [layer] });
xrSession.requestAnimationFrame(onXRFrame);

function onXRFrame(time, xrFrame) {
  xrSession.requestAnimationFrame(onXRFrame);

  gl.bindFramebuffer(gl.FRAMEBUFFER, source.getCurrentFramebuffer());
  for (let view in xrViewerPose.views) {
    let viewport = layer.getViewSubImage(view).viewport;
    gl.viewport(viewport.x, viewport.y, viewport.width, viewport.height);
    
    // Render from the viewpoint of xrView
  }
}
```

In some cases, such as a mono `XRQuadLayer` being shown on a stereo device, multiple `XRView`s may return the same `XRSubImage` values. To avoid rendering the same view multiple times in these scenarios the `primary` attribute of the `XRSubImage` will be be set to `false` for all but one of the overlapping views. (It should be noted that `XRProjectionLayer`s will never return `XRSubImage`s with `primary` set to false.)

```js
// Render Loop for a projection layer with a WebGL framebuffer source.
const xrGfx = new XRWebGLGraphicsBinding(xrSession, gl);

const quadLayer = xrSession.requestLayer('quad');
// Position 2 meters away from the origin with a width and height of 1.5 meters
quadLayer.transform = new XRRigidTransform({z: -2});
quadLayer.width = 1.5;
quadLayer.height = 1.5;

const quadSource = await xrGfx.setFramebufferLayerSource(quadLayer, 512, 512, { stereo: false });

xrSession.updateRenderState({ layers: [quadLayer] });
xrSession.requestAnimationFrame(onXRFrame);

function onXRFrame(time, xrFrame) {
  xrSession.requestAnimationFrame(onXRFrame);

  gl.bindFramebuffer(gl.FRAMEBUFFER, quadSource.getCurrentFramebuffer());
  for (let view in xrViewerPose.views) {
    let subImage = quadLayer.getViewSubImage(view);

    if (subImage.primary) {
      gl.viewport(viewport.x, viewport.y, viewport.width, viewport.height);
      
      // Render content for view.eye
    }
  }
}
```

## Appendix A: Proposed IDL

```webidl
//
// Session extensions
//

partial interface XRSession {
  [NewObject] XRLayer? requestLayer(XRLayerType type);
}

//
// Layer interface
//

enum XRLayerType {
  "projection",
  "quad",
  "cylinder",
  "equirect",
  "cube"
}

interface XRLayer {
  XRSubImage? getViewSubImage(XRView view);

  XRReferenceSpace referenceSpace;
  boolean blendTextureSourceAlpha = false;
  boolean chromaticAberrationCorrection = false;
}

interface XRSubImage {
  readonly attribute XRViewport viewport;
  readonly attribute unsigned long imageIndex;
  readonly attribute boolean primary;
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
  attribute XRRigidTransform transform;
  attribute float radius = 1;
  attribute float centralAngle = Math.PI * 0.5;
  attribute float aspectRatio = 1;
}

interface XREquirectLayer extends XRLayer {
  attribute XRRigidTransform transform;
  attribute float radius = 1;
  attribute float scaleX = 1;
  attribute float scaleY = 1;
  attribute float biasX = 0;
  attribute float biasY = 0;
}

interface XRCubeLayer extends XRLayer {
  attribute DOMPoint orientation;
}

typedef (XRQuadLayer or XRCylinderLayer or XREquirectLayer or XRCubeLayer)
        XRNonProjectionLayer; // Would love a better term for this!

//
// Graphics Bindings
//

dictionary XRWebGLLayerSourceInit {
  boolean stereo = false;
  boolean depth = true;
  boolean stencil = false;
  boolean alpha = true;
  boolean ignoreDepthValues = false;
}

interface XRWebGLGraphicsBinding {
  constructor(XRSession session, WebGLRenderingContext context);

  double getNativeProjectionScaleFactor();

  Promise<XRWebGLFramebufferLayerSource> setFramebufferLayerSource(
      XRProjectionLayer layer, XRWebGLLayerInit init);
  Promise<XRWebGLFramebufferLayerSource> setFramebufferLayerSource(
      XRNonProjectionLayer layer, int pixelWidth, int pixelHeight, XRWebGLLayerSourceInit init);
}

interface XRWebGL2GraphicsBinding extends XRWebGLGraphicsBinding {
  constructor(XRSession session, WebGL2RenderingContext context);

  Promise<XRWebGLTextureLayerSource> setTextureLayerSource(
      XRProjectionLayer layer, XRWebGLLayerInit init);
  Promise<XRWebGLTextureLayerSource> setTextureLayerSource(
      XRNonProjectionLayer layer, int pixelWidth, int pixelHeight, XRWebGLLayerSourceInit init);
}

//
// Layer Sources
//

interface XRLayerSource {
  readonly attribute unsigned long width;
  readonly attribute unsigned long height;
  readonly attribute unsigned long arraySize;

  readonly attribute boolean ignoreDepthValues;
}

interface XRWebGLFramebufferLayerSource extends XRLayerSource {
  // Getter function serves as flag that layer will be written to this frame.
  WebGLFramebuffer? getCurrentFramebuffer();

  readonly attribute boolean antialias;
}

interface XRWebGLTextureLayerSource extends XRLayerSource {
  WebGLTexture? getCurrentColorTexture();
  WebGLTexture? getCurrentDepthStencilTexture();
}
```

## Appendix B: Open Questions

  - Sensible defaults of all the layer values.
  - Do we need an attribte to communicate max number of supported layers?
  - Do we need to report on the layer source whether or not it's mono/stereo, since the XR device may force a downgrade?
  - Depth: Should we consider allowing a separate layer for this like OpenXR does, or continue pattern of allowing it's use by default (implies most layer types need to be able to allocate both a color and depth/stencil buffer)
