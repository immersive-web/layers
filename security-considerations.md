# security & privacy considerations
This document contains answers to the questions that are listed in the [Security and Privacy](https://www.w3.org/TR/security-privacy-questionnaire) document.

## What information might this feature expose to Web sites or other parties, and for what purposes is that exposure necessary?
This specification does not expose new information to web sites apart from showing that it is available for use.

## Is this specification exposing the minimum amount of information necessary to power the feature?
Yes. We tried to minimize the number of APIs so we only expose the bare minimum to what is needed to support the feature set. No duplicate or unneeded API were added.

## How does this specification deal with personal information or personally-identifiable information or information derived thereof?
No new personal information is exposed by this specification.

## How does this specification deal with sensitive information?
No sensitive information is exposed by this specification. Layers are just new surfaces that can be rendered using WebGL or HTML Video.
It doesn't expose new hit testing features or sensor data, nor does it require new permissions.

## Does this specification introduce new state for an origin that persists across browsing sessions?
No.
This specification builds on top of WebXR for its state management. It doesn't introduce new concepts.

## What information from the underlying platform, e.g. configuration data, is exposed by this specification to an origin?
No additional information (apart from support for the API) is exposed.

## Does this specification allow an origin access to sensors on a user’s device
No. No new sensor data is requested for this feature.

## What data does this specification expose to an origin? Please also document what data is identical to data exposed by other features, in the same or different contexts.
This specification gives access to new WebGL color and depth textures. This isn't any different from how WebGL works today.

## Does this specification enable new script execution/loading mechanisms?
No

## Does this specification allow an origin to access other devices?
No

## Does this specification allow an origin some measure of control over a user agent’s native UI?
No

## What temporary identifiers might this specification create or expose to the web?
None apart of support for this feature (once the user is in immersive mode).

## How does this specification distinguish between behavior in first-party and third-party contexts?
WebXR Layers does not introduce new behavior with respect to first-party or third-party contexts. Please refer to the WebXR spec which deals with this problem.

## How does this specification work in the context of a user agent’s Private Browsing or "incognito" mode?
It behaves identical.

## Does this specification have a "Security Considerations" and "Privacy Considerations" section?
Yes

## Does this specification allow downgrading default security characteristics?
No
