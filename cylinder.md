### Cylinder Layer
The cylinder layer is similar to quad layer: it is an object in the world with image mapped onto the inside of a cylinder section. It can be imagined the same way a curved TV set display looks to a viewer. Only the internal surface of the layer **must** be rendered; the exterior of the cylinder is not visible and **must not** be rendered by the browser.

See `XRQuadLayer` for common attributes' description.

The cylinder-specific attributes are as follows:
* `pose` - the `XRRigidTransform`, defines position and orientation of the center point of the view of the cylinder in the reference space of the `space`;
* `radius` - the radius of the cylinder.
* `centralAngle` - is the angle of the visible section of the cylinder, in radians, from 0 (inclusive) to 2 x PI (exclusive). It grows symmetrically around the 0 radian angle.
* `aspectRatio` - is the aspect ratio of the visible cylinder section, width / height. The height of the cylinder height is calculated as follows: `height = radius * centralAngle) / aspectRatio`.

![](images/cylinder_layer_params.png)
> **TODO** Update the drawing

> **TODO** Define proper methods for `XRCylinderLayer`, if any

> **TODO** Hittestable / interactive layers with using `XRLayerDOMImage`?

## IDL
```webidl
dictionary XRCylinderLayerInit {
  (XRLayerSubImage or XRLayerImageSource) image;
  XRLayerEyeVisibility eyeVisibility = "both";
  XRSpace              space;
  XRRigidTransform?    pose;
  float                radius;
  float                centralAngle;
  float                aspectRatio;
};

[
    SecureContext,
    Exposed=Window,
    Constructor(XRSession session, XRWebGLRenderingContext context, optional XRCylinderLayerInit layerInit)
] interface XRCylinderLayer : XRLayer {

  readonly attribute XRLayerSubImage      subImage;

  readonly attribute XRLayerEyeVisibility eyeVisibility;
  readonly attribute XRSpace              space;
  readonly attribute XRRigidTransform?    pose;
  readonly attribute float                radius;
  readonly attribute float                centralAngle;
  readonly attribute float                aspectRatio;

  XRViewport? getViewport(XRView view);
};
```
