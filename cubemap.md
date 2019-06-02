### Cubemap Layer

Only `XRLayerTextureImage` with `cube` attribute set to `true` is supported as image source for the `XRCubeLayer`.
> **TODO** Document this layer

> **TODO** Define proper methods for `XRCubeLayer`, if any

## IDL
```webidl
dictionary XRCubeLayerInit {
  XRLayerImageSource   image;
  XRLayerEyeVisibility eyeVisibility = "both";
  XRSpace              space;
  DOMPoint             orientation; 
  DOMPoint             offset; 
};

[
    SecureContext,
    Exposed=Window,
    Constructor(XRSession session, XRWebGLRenderingContext context, optional XRCubeLayerInit layerInit)
] interface XRCubeLayer : XRLayer {

  readonly attribute XRLayerImageSource   image;

  readonly attribute XRLayerEyeVisibility eyeVisibility;
  readonly attribute XRSpace              space;

  readonly attribute DOMPointReadOnly     orientation; 
  readonly attribute DOMPointReadOnly     offset; 

  XRViewport? getViewport(XRView view);
};
```
