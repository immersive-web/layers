### Quad Layer
The quad layer describe a posable planar rectangle in the virtual world for displaying two-dimensional content. The quad layer occupies a certain portion of the display's FOV and allows better match between the resolution of the image source and the footprint of that image in the final composition. This allows optimal sampling and improves clarity of the image, which is important for rendering text or UI elements.

The constructor should initialize the `XRQuadLayer` instance accordingly to attributes set in layerInit.

Only front face of the quad layer is visible; the back face is not visible and **must** not be rendered by the browser. A quad layer has no thickness; it is a 2D object positioned and oriented in 3D space.

The position of the quad refers to the center of the quad within the given `XRSpace`. The orientation of the quad refers to the orientation of the normal vector form the front face.

The dimensions of the quad refer to the quad's size in the xy-plane of the given `XRSpace`'s coordinate system. For example, the quad with the orientation {0,0,0,1}, position {0,0,0}, and dimensions {1,1} refers to 1 meter by 1 meter quad centered at {0,0,0} with its front face normal vector congruent to Z+ axis.

> **TODO** Hittestable / interactive layers with using `XRLayerDOMImage`?

> **TODO** Define proper methods for `XRQuadLayer`, if any

> **TODO** Describe how positioning works for each XRSpace

