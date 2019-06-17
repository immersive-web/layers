# Multiple layers support
> Work in progress.
## Goals of the document
The purpose of this document is to unlock the ability for User Agents to experiment with multiple layers. 
* Introduce a concept of layers into WebXR spec and the way how layers should be provided from user's code to Browser;
* Define ways to get layers capabilities, such as maximum number of supported layers, supported types of layers, etc;
* Make sure the layers' part of the WebXR spec is extensible for any future additions and minimizing need for breaking changes in future. The modified API should be compatible with all User Agents whether they support multiple layers or not. 

## Non-goals
* This document doesn't provide definitions for any specific layer types.
* Particular details of implementation will be provided in a different [document](layers-core.md)


## Proposed changes

Current WebXR spec is written with layers in mind (see [XRLayer interface](https://immersive-web.github.io/webxr/#xrlayer-interface)), however, only a single layer ([baseLayer](https://immersive-web.github.io/webxr/#dom-xrrenderstate-baselayer)) is currently supported.

To support multiple layers the following changes are proposed:
* Make the [XRRenderStateInit and XRRenderState](https://immersive-web.github.io/webxr/#xrrenderstate-interface)'s [baseLayer](https://immersive-web.github.io/webxr/#dom-xrrenderstate-baselayer) optional; add another optional member which will be the sequence of [XRLayer](https://immersive-web.github.io/webxr/#xrlayer-interface)s (let say we call it `layers`). Only one of the members should be used, either `baseLayer` or `layer`; if both are specified then `layers` takes precedence over the `baseLayer` (if supported).
* The maximum number of supported layers could be requested from [XRSession](https://immersive-web.github.io/webxr/#xrsession) by using `getMaxLayerCount()` method; if the `getMaxLayerCount()` returns 0 then only the `baseLayer` is supported; if `getMaxLayerCount()` returns non-zero positive value, then `layers` can be used; 
* Only `XRWebGLLayer` can be set to the `baseLayer`; only new layer types (`XRLayerProjection`, `XRLayerQuad`, etc) can be set as elements of `layers`.
* The types of supported layers could be asked from [XRSession](https://immersive-web.github.io/webxr/#xrsession) by using `isLayerSupported(layer_class_name)` method;
* Layers are drawn in the same order as they are specified in via `XRSession/updateRenderState`, with the 0th layer drawn first. Layers are drawn with a "painter’s algorithm," with each successive layer potentially overwriting the destination layers whether or not the new layers are virtually closer to the viewer. There is no depth testing between the layers. Layer's visibility is controlled by presence (or absence) of the layer in the sequence. To hide or show a layer - call [updateRenderState](https://immersive-web.github.io/webxr/#dom-xrsession-updaterenderstate) and provide a new sequence of layers.

* Add common properties to [XRLayer](https://immersive-web.github.io/webxr/#xrlayer-interface) (such as chromatic aberration or alpha blending flags):
* * `chromaticAberrationCorrection` - boolean, enables optical chromatic aberration correction for the layer when not done by default; chromatic aberration correction improves visual fidelity of the layer's rendering, but it might be computationally expensive; this flag may be ignored by the browser, if this feature is not supported.
* * `blendTextureSourceAlpha` - boolean, enables the layer’s texture alpha channel. If enabled, then the layer composition uses the alpha channel to modulate the blending of the layer's texture against the destination.  The texture color channels must be encoded with premultiplied alpha. If the bit is not enabled, then each texel is treated as if alpha channel has value 1.0.
This feature must be supported if multiple layers are supported; otherwise, it is ignored.
* * `void requestUpdate()` - the method that should be called to indicate the layer's content changed; by default, browser should assume that the content of the layers (image source) is not updated.

> **TODO** Verify with WebGL folks the alpha-premultiply stuff.

See the Appendix for the proposed IDL.


## Code examples

### Checking layers' types and maximum amount of layers supported and creating layers:
```javascript
// session is already created
let maxLayerCount = session.getMaxLayerCount();
let newRenderState = new Object;
if (maxLayerCount == 0) {
  // we use baseLayer
  newRenderState.baseLayer = new XRWebGLLayer(session, gl);
} else {
  newRenderState.layers = new Array();
  newRenderState.layers[0] = new XRLayerProjection(session, gl);
  if (maxLayerCount > 1 && session.isLayerSupported("XRLayerQuad"))
    newRenderState.layers[1] = new XRLayerQuad(session, gl);
  }
}
session.updateRenderState(newRenderState);

```

### Setting common layers properties
```javascript
  if (maxLayerCount > 1 && session.isLayerSupported("XRLayerQuad"))
    let quadLayer = new XRLayerQuad(session, gl);
    quadLayer.chromaticAberrationCorrection = true;
    quadLayer.blendTextureSourceAlpha = true;
    newRenderState.layers[1] = quadLayer;
  }
```

## Appendices 

### IDL (excerpts)

```webidl
typedef (WebGLRenderingContext or WebGL2RenderingContext) XRWebGLRenderingContext;

partial dictionary XRRenderStateInit {
  XRLayer? baseLayer;

  sequence<XRLayer>? layers;
};

[SecureContext, Exposed=Window] partial interface XRRenderState {
  readonly attribute XRLayer? baseLayer;
  readonly attribute FrozenArray<XRLayer>? layers;
};

[SecureContext, Exposed=Window] partial interface XRSession : EventTarget {
  long getMaxLayerCount();
  boolean isLayerSupported(DOMString layer_class_name);
};

partial dictionary XRLayerInit {
  boolean chromaticAberrationCorrection = false;
  boolean blendTextureSourceAlpha = false;
};

[ SecureContext, Exposed=Window] partial interface XRLayer {
  readonly attribute boolean chromaticAberrationCorrection;
  readonly attribute boolean blendTextureSourceAlpha;
  
  void requestUpdate();
};

```

### TO DO
This is a Work-In-Progress document and the following topics are not covered in details here. The topics which will be touched in separate documents:
* Specify each layer type (quad, cylinder, equirect, cubemap), provide details for properties / methods for each layer;
* DOM layers details; 
* Video layer details; 
* Hit-testable layers.
* Provide full IDL.
* Based on the foundation described in this document, a next set of functionality is being explored [here](details.md) that goes into more details about common parts of a multilayer system and enumerates potential layer types.```


### References
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






