# Verification — 2026-10-27

- CocoaPods 1.16.2 / AFNetworking Serialization 4.0.1 / Xcode 27.1.
- Desktop Demo built from a fresh DerivedData directory, including explicit cross-project Pods dependencies.
- iOS 18.5 and iOS 27.0 simulators: 39 tests passed on each, zero failures. Includes a real URLSession multipart upload to a randomly assigned loopback HTTP port, upload progress, cancellation isolation, deadline competition, encoded request snapshots and logger redaction.
- Separate local business compatibility harness: 5 tests passed. Covers existing common-parameter precedence, userId special case, Query+JSON separation, legacy error domain/metadata, cancellation and total timeout classification.
- Complete Pod library build/link/import validation passed through Scripts/validate-pod.rb. The script raises old dependency targets to iOS 15 in the validation project, matching the Demo Podfile. Plain pod lib lint fails on SDKs that reject AFNetworking's iOS 9 target; this requirement is documented.
- Business app targets compile the same XBNetwork sources as the public component; CXNetworkClient delegates to an isolated XBNetwork instance. Legacy business source and its fixture harness are not distributed in this repository.
- This report does not claim a complete build or production-server regression of the host business apps, real-device performance verification, or a remotely completed GitHub Actions run.
