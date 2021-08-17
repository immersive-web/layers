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

The capabilities of the WebXR Layers API closely mirrors what [OpenXR](https://www.khronos.org/registry/OpenXR/specs/1.0/html/xrspec.html#composition-layer-types) supports.

### Examples of use cases

Composition layers are useful for displaying information, text, video, or textures that are intended to be focal objects in your scene. Composition layers could also be useful for displaying simple environments and backgrounds to your scene.

One of the very common use cases of WebXR is 180 and/or 360 photos or videos, both - equirect and cubemaps. Usual implementation involves a lot of CPU and GPU power and the result is usually pretty poor in terms of visual quality, latency and power consumption (the latter is especially critical for mobile / standalone devices, such as Oculus Go, Quest, Vive Focus, ML1, HoloLens, etc).

Another example where composition layers are going to shine is displaying text or high resolution textures in the virtual world. Since composition layers allow to sample source texture at full resolution without multiple re-samplings the readability of the text is going to be significantly improved.

In addition to layers that are anchored to spaces, it also offers projection layers. These layers closely mirror WebXR's [XRWebGLLayer](https://immersive-web.github.io/webxr/#xrwebgllayer-interface) in that they cover the entire field of view.
Generally, authors will draw content in these layers where the 3D effect is calculated by the scene itself. (ie controllers)
Projection layers are implemented more efficiently than XRWebGLLayer and their use is more flexible so authors should use them instead.

## Goals
 1. Provide a new API that exposes composition layers to the web.
 1. Provide the ability to draw to those layers with WebGL 1 or 2.
 1. Provide the ability to draw video directly to a subset of these layers.
 1. Provide backward compatibility for content that draws with WebXR's XRWebGLLayer.
 1. Provide ability to have layers on any device that supports WebXR.

## Non-goals
 1. Create a new mechanism for immersive sessions. Everything defined in the WebXR spec should still apply.
 1. Design a new hit test API.
 1. Require that every device supports all types of layers.

## Other potential solutions considered
We briefly considered exposing the more low-level [swapchain mechanism](https://www.khronos.org/registry/OpenXR/specs/1.0/html/xrspec.html#swapchain-image-management) which is how OpenXR defines layers.
We decided not to go down that path because it doesn't mesh well with the current WebXR API and it would be harder to use for authors.
Instead, we provided higher level objects that hide this complexity behind the scenes.

This also allows implementations to support layers if they have no swapchain support.

## Usage

Using the Layers API consists of three primary steps:

  1. Creating the layers with a given graphics API.
  1. For non-projection layers, positioning the layers and adding them to the session's layers array.
  1. Rendering to the graphics API resources during the frame loop.

### Graphics API binding

At its most basic, each layer is represented by an ["opaque" texture](https://immersive-web.github.io/layers/#xropaquetextures). These textures have special behavior that is defined by the spec. They are also special in that they are composited by the system compositor, not the UA.

When a layer is created it is backed by a GPU resource (= ["opaque" texture](https://immersive-web.github.io/layers/#xropaquetextures)) provided by one of the Web platform's graphics APIs. In order to specify which API is providing the layer's GPU resources a Layer Factory for the API in question must be created. For example, creating a layer factory for WebGL would function like this:

```js
const canvas = document.createElement('canvas');
const gl = canvas.getContext('webgl', { xrCompatible: true });
const xrGlBinding = new XRWebGLBinding(xrSession, gl);
```

The same layer factory could also accept WebGL 2.0 contexts.

Future graphics APIs will interface with WebXR in the same way. A theoretical WebGPU graphics binding (which is not being proposed at this time and is offered only for illustrative purposes) may look like this:

```js
const gpuAdapter = await navigator.gpu.requestAdapter({ xrCompatible: true });
const gpuDevice = await gpuAdapter.requestDevice();
const xrGpuBinding = new XRWebGPUBinding(xrSession, gpuDevice);
```

Each graphics API may have unique requirements that must be satisfied before a context can be used in the creation of a layer factory. For example, a `WebGLRenderingContext` must have its `xrCompatible` flag set prior to being passed to the constructor of the `XRWebGLBinding` instance.

Any interaction between the `XRSession` the graphics API, such as allocating or retrieving textures, will go through this `XRWebGLBinding` instance, and the exact mechanics of the interaction will typically be API specific. This allows the rest of the WebXR API to be graphics API agnostic and more easily adapt to future advances in rendering techniques.

## Enabling layer creation

By default, authors can create a single projection layer and add it to the layers array.
To request more layers or layer types, they have to request ["layers"](https://immersive-web.github.io/layers/#feature-descriptor-layers) support using the feature descriptor in the [`requestSession`](https://immersive-web.github.io/webxr/#dom-xrsystem-requestsession) call.

## Layer creation

Once a layer factory instance has been acquired, it can be used to create a variety of `XRLayer`s. Any layers created by that layer factory will then be able to query the associated GPU resources each frame, generally expected to be the native API's texture interface.

The various layer types are created with the  `create____Layer` series of methods on the layer factory instance. Information about the graphics resources required, such as whether or not to allocate a depth buffer or alpha channel, are passed in at layer creation time and will be immutable for the lifetime of the layer. The method will return a the associated `XRLayer`.

The graphics API the layer factory was created with may also require API-specific information be provided. For instance, the `XRWebGLBinding` requires that the texture target desired be specified.

```js
const canvas = document.createElement('canvas');
const gl = canvas.getContext('webgl', { xrCompatible: true });
const xrGlBinding = new XRWebGLBinding(xrSession, gl);
const layer = xrGlBinding.createProjectionLayer("texture", { alpha: false });
```

This will allocate a layer that supplies a 2D texture as it's output surface, which will then be subdivided into viewports for each `XRView`. If the context passed into the `XRWebGLBinding` was a WebGL 2.0 the developer could optionally choose to allocate a texture array instead, in which every `XRView` will be rendered into a separate level of the array. This allows for some rendering optimizations, such as the use of the `OVR_multiview` extension, to be used.

```js
const canvas = document.createElement('canvas');
const gl = canvas.getContext('webgl2', { xrCompatible: true });
const xrGlBinding = new XRWebGLBinding(xrSession, gl);
const layer = xrGlBinding.createProjectionLayer("texture-array", { alpha: false });
```

Layer types other than an `XRProjectionLayer` must be given an explicit pixel width and height, as well as whether or not the image should be stereo or mono. This is because those properties cannot be inferred from the hardware or layer type as they can with an `XRProjectionLayer`.

```js
const layer = xrGlBinding.createQuadLayer("texture", { pixelWidth: 1024, pixelHeight: 768, layout: "stereo" });
```

Passing `true` for stereo here indicates that you are able to provide stereo imagery for this layer, but if the XR device is unable to display stereo imagery it may automatically force the layer to be created as mono instead to reduce memory and rendering overhead. Layers that are created as mono will never be automatically changed to stereo, regardless of hardware capabilities. Developers can check the `stereo` attribte of the resulting layer to determine if the layer was allocated with resources for stereo or mono rendering.

Some layer types may not be supported by the `XRSession`. If a layer type isn't supported the method will throw a ` NotSupportedError` exception. `XRProjectionLayer` _must_ be supported by all `XRSession`s.

The `XRLayerLayout` attribute determines how the GPU resources of the layers are allocated.
* mono: a single texture is allocated and presented to both eyes.
* stereo: the UA decides how it allocates the texture (1 or 2) and the layout (top/bottom or left/right) This is the required layout for texture arrays
* stereo-left-to-right: a single texture is allocated. Left eye gets the left area of the texture, right eye the right
* stereo-top-bottom: a single texture is allocated. Left eye gets the top area of the texture, right eye the bottom

## Layer positioning and shape

Non-projection layers each have attributes that control where the layer is shown and how it's shaped. For example, the positioning of an `XRQuadLayer` is handled like so:

```js
const quadLayer = xrGlBinding.createQuadLayer("texture", { pixelWidth: 512, pixelHeight: 512 });
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

Layers are not presented to the XR device until they have been added to the `layers` `XRRenderState` property with the `updateRenderState()` method. Setting the `layers` array will override the `baseLayer` if one is present, with `baseLayer` reporting `null`. Layers will be presented in the order they are given in the `layers` array, with layers being given in "back-to-front" order. Layers may have alpha blending applied if the layer's `blendSourceAlpha` attribute is `true`, but no depth testing may be performed between layers.
Setting both the `baselayer` and populating the `layers` array will be rejected.

In addition to the `XRLayer`-derived types, the existing `XRWebGLLayer` may be passed to the layers array as well. This layer type remains useful as a mechanism for rendering antialiased content with WebGL 1.0 contexts. `XRWebGLLayer` functions as an `XRProjectionLayer`, but they are kept as distinct types for better forwards compatibility.

```js
const projectionLayer = new XRWebGLLayer(xrSession, gl);
const quadLayer = xrGlBinding.createQuadLayer("texture", { pixelWidth: 1024, pixelHeight: 1024 });

xrSession.updateRenderState({ layers: [projectionLayer, quadLayer] });
```

`updateRenderState()` _may_ throw an exception if more layers are specified than the `XRSession` supports simultaneously.

`updateRenderState()` _must_ throw an exception if both `layers` and `baseLayer` are specified.

## Rendering

During `XRFrame` processing each layer can be updated with new imagery. Calling `getViewSubImage()` with a view from the `XRFrame` will return an `XRSubImage` indicating the textures to use as the render target and what portion of the texture will be presented to the `XRView`'s associated physical display.

WebGL layers allocated with the `TEXTURE_2D` target will provide sub images with a `viewport` and an `imageIndex` of `0` for each `XRView`. Note that the `colorTexture` and `depthStencilTexture` can be different between the views.

```js
// Render Loop for a projection layer with a WebGL framebuffer source.
const xrGlBinding = new XRWebGLBinding(xrSession, gl);
const layer = xrGlBinding.createProjectionLayer("texture");
const framebuffer = gl.createFramebuffer();

xrSession.updateRenderState({ layers: [layer] });
xrSession.requestAnimationFrame(onXRFrame);

function onXRFrame(time, xrFrame) {
  xrSession.requestAnimationFrame(onXRFrame);

  gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);

  for (let view in xrViewerPose.views) {
    let subImage = xrGlBinding.getViewSubImage(layer, view);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0,
      gl.TEXTURE_2D, subImage.colorTexture, 0);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT,
      gl.TEXTURE_2D, subImage.depthStencilTexture, 0);
    let viewport = subImage.viewport;
    gl.viewport(viewport.x, viewport.y, viewport.width, viewport.height);

    // Render from the viewpoint of xrView
  }
}
```

WebGL layers allocated with the `TEXTURE_2D_ARRAY` target will provide sub images with the same `viewport` and a unique `imageIndex` indicating the texture layer to render to for each `XRView`. Note that the `colorTexture` and `depthStencilTexture` are the same between views, just the `imageIndex` is different.

```js
// Render Loop for a projection layer with a WebGL framebuffer source.
const xrGlBinding = new XRWebGLBinding(xrSession, gl);
const layer = xrGlBinding.createProjectionLayer("texture-array");
const framebuffer = gl.createFramebuffer();

xrSession.updateRenderState({ layers: [layer] });
xrSession.requestAnimationFrame(onXRFrame);

function onXRFrame(time, xrFrame) {
  xrSession.requestAnimationFrame(onXRFrame);

  gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
  let viewport = xrGlBinding.getSubImage(layer, xrFrame).viewport;
  gl.viewport(viewport.x, viewport.y, viewport.width, viewport.height);

  for (let view in xrViewerPose.views) {
    let subImage = xrGlBinding.getViewSubImage(layer, view);
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
const xrGlBinding = new XRWebGLBinding(xrSession, gl);
const quadLayer = xrGlBinding.createQuadLayer("texture", {
  pixelWidth: 512, pixelHeight: 512
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
  let subImage = xrGlBinding.getSubImage(quadLayer, xrFrame);
  gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0,
    subImage.colorTexture, 0);
  let viewport = subImage.viewport;
  gl.viewport(viewport.x, viewport.y, viewport.width, viewport.height);

  // Render content for the quad layer
}
```

The textures that are returned from `getSubImage` and `getViewSubImage` are specially defined `opaque` textures.
The layers specification has more details on their exact behavior but of note is that you can't access their pixel data at any point and they are only valid during an `XRSession`'s [requestAnimationFrame](https://immersive-web.github.io/webxr/#dom-xrsession-requestanimationframe) call and after a call to getSubImage/getViewSubImage. If you use the textures outside these constraints, they are considered invalid.

Composition of these layers must also be independant of their pixel content. For instance, an partially transparent pixel should composite in the same time as a fully opaque pixel.

## Video layers

Video playback is a very common use case in VR, especially with 180, 360, and stereo videos. While videos can be displayed by copying the video output frame-by-frame over to WebGL textures this has several downsides, including introducing extra copies, introducing stutter or becoming de-synced from the audio due to limits on when you can copy the texture, and inability to display encrypted media. As a result having a method for presenting videos directly as a layer offers an opportunity to make video playback easier, faster, and higher quality.

To create video layers, an `XRMediaBinding` must be created, similar to the `XRWebGLBinding`.

```js
const xrMediaBinding = new XRMediaBinding(xrSession);
```

The `XRMediaBinding` can then be used to create `XRQuadLayer`s, `XRCylinderLayer`s, and `XREquirectLayer`s that display a given video element. (`XRProjectionLayer`s cannot be created with an `XRMediaBinding`, given the requirements for how they must respond to the viewer's movement. `XRCubeLayer`s cannot be created with an `XRMediaBinding` since the ideal layout isn't clear, but may be added at a later time.)

```js
const video = document.createElement('video');
video.src = 'never-gonna-give-you-up.mp4';
const layer = xrMediaBinding.createQuadLayer(video);
```

That layer can then be added to the layers list like any of the WebGL layers above, and even intermixed with layers created by an `XRWebGLBinding`. Once the video layer has been added to the session's layer list it will continuously display the current frame of the video element with no additional interaction from the API. Playback is controlled via the standard `HTMLVideoElement` controls.

Videos may also contain stereo data, typically encoded with both eye's video information embedded in a single video frame either side-by-side or one on top of the other. In order to display these properly the layout of the stereo streams needs to be specified, like so:

```js
const layer = xrMediaBinding.createQuadLayer(video, { layout: 'stereo-top-bottom' });
```

This will then cause only the top half of the video to show to the left eye and the bottom half of the video to show to the right eye. If more complex layouts are required than are described by the `XRLayerLayout` enum then the video must be manually rendered using an `XRWebGLBinding` layer instead.
