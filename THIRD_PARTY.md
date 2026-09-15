# Third-party notices

XM6 Studio is independent software, unaffiliated with Sony.

## xm6-control

Source: https://github.com/ruimartins23/xm6-control

Pinned commit: `af6d89b26f33ca607c0a2d1abe2e5d8dac630a9e`

Copyright (c) 2026 Rui Martins. MIT license in `ThirdParty/xm6-control-LICENSE.txt`.

Adapted protocol framing, payload builders, event decoders, model types, and RFCOMM service discovery. Local changes include stricter payload validation, stream resynchronization, a new non-optimistic session controller, dedicated Bluetooth run-loop execution, audio routing, UI, and tests. Upstream connect-time setting changes are not included. Upstream's comments describing hardware verification refer to that project's tests, not validation of this build on the user's headphones.

## SonyHeadphonesClient

Source: https://github.com/mos9527/SonyHeadphonesClient

Pinned commit: `0d892d1f87891d97f6ae51975a748563ac30fd96`

MIT license in `ThirdParty/SonyHeadphonesClient-LICENSE.txt`.

`src/ProtocolV2T1.h` was used as the reference for model/firmware read requests, DSEE Auto/Off payloads, and modern noise-control subtype 0x19 with preserved adaptive-ambient fields. The original copyright and permission notice accompanies this app.

## Further acknowledgements

Upstream xm6-control credits Gadgetbridge and SonyHeadphonesClient for protocol research. Sony and WH-1000XM6 are Sony trademarks. Apple frameworks and SF Symbols are provided by macOS. The icon background and layout are drawn in AppKit; the headphone photograph is credited below.

## Sony WH-1000XM6 product artwork

The unmodified product photograph in `Sources/XM6Companion/Assets/WH1000XM6.png` is from Sony's official WH-1000XM6 product page:

https://www.sony.com.hk/en/headphones/products/wh-1000xm6

Asset URL: https://sony.scene7.com/is/image/sonyglobalsolutions/WH1000XM6_Primary_image_Black?fmt=png-alpha&wid=1600

Retrieved 15 September 2026. Product imagery and Sony trademarks belong to Sony. This photograph is separate from the MIT-licensed protocol source; those licenses do not grant rights to Sony's artwork. Its presence identifies supported headphones and does not indicate Sony sponsorship or affiliation.
