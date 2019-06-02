### Equirect Layer

> **TODO** Document this layer

> **TODO** Define proper methods for `XREquirectLayer`, if any

## IDL
```webidl
dictionary XREquirectLayerInit {
  (XRLayerSubImage or XRLayerImageSource) image;
  XRLayerEyeVisibility eyeVisibility = "both";
  XRSpace              space;
  XRRigidTransform?    pose;

  DOMPoint             scale;  // x,y
  DOMPoint             biasUV; // x,y
};

[
    SecureContext,
    Exposed=Window,
    Constructor(XRSession session, XRWebGLRenderingContext context, optional XREquirectLayerInit layerInit)
] interface XREquirectLayer : XRLayer {

  readonly attribute XRLayerSubImage   subImage;

  readonly attribute XRLayerEyeVisibility eyeVisibility;
  readonly attribute XRSpace           space;
  readonly attribute XRRigidTransform? pose;
  readonly attribute DOMPointReadOnly  scale;  //2f
  readonly attribute DOMPointReadOnly  biasUV; //2f

  XRViewport? getViewport(XRView view);
};
```