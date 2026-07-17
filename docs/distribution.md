# Distribution

ShotCapture uses App Sandbox and asks the user to select Xcode, then stores that
access as a security-scoped bookmark. This lets the app invoke Xcode's
`xcrun simctl` tooling while remaining eligible for Mac App Store review.

The existing GitHub workflow remains available for optional direct distribution.
Those builds must be signed with a **Developer ID Application** certificate, use
Hardened Runtime, and be notarized by Apple.

## GitHub release setup

Create a private GitHub repository and push this project first; this checkout
does not currently have a Git remote configured. Keeping the repository private
also prevents source and release artifacts from becoming public accidentally.

Create a protected GitHub environment named `release`, then add these secrets:

- `DEVELOPER_ID_APPLICATION_CERT_BASE64`: base64-encoded `.p12` export
- `DEVELOPER_ID_APPLICATION_CERT_PASSWORD`: password used for the export
- `KEYCHAIN_PASSWORD`: a generated password for the temporary CI keychain
- `APPLE_ID`: Apple Developer account email
- `APPLE_APP_SPECIFIC_PASSWORD`: app-specific password for notarization
- `APPLE_TEAM_ID`: Apple Developer Team ID (`TWUTEK8LCV` for this project)

Run **Build signed release** manually or push a tag such as `v1.0.0`. The
workflow archives a universal app with the bundled product-bezel resources,
signs and notarizes it, and uploads `ShotCapture-<version>.zip` plus its SHA-256
checksum as a private Actions artifact. It does not run tests.

## Website and download delivery

Gumroad is not part of the distribution plan. The current workflow deliberately
keeps the signed ZIP in a private Actions artifact until the customer-download
model is selected.

GitHub Pages supports static sites and custom domains, but GitHub's Pages limits
do not allow it to be used primarily as free hosting for an online business or
e-commerce site. It is suitable for public documentation or a free-download
project, not the paid ShotCapture storefront. A commercial static host can serve
the same HTML with a custom domain and connect to a payment and download service.

The website should include:

- Home: value proposition, product demo, screenshots, and purchase CTA
- Features and pricing: supported workflows, system requirements, and license
- Changelog and documentation: installation, permissions, capture, and export
- Privacy, terms, refund policy, and support contact

Do not host the paid ZIP at a public URL. Keep it private until the chosen sales
flow can authenticate buyers or deliver expiring download links.

The release includes the product-bezel PNGs from `ShotCapture/ProductBezels/`.
It also keeps **Import Bezels…** and the Apple resources link for adding future
devices and finishes.

The current deployment target is macOS 26.5. State that requirement prominently
on the pricing and download pages unless the target is lowered after a source
compatibility review.
