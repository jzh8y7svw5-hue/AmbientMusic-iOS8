# AmbientMusic (iOS 8.4.1 / iPad 4)

A landscape music-player display for jailbroken 32-bit iPads, built with Theos.

## Features

- Landscape-first, full-screen music display.
- Album artwork with a dark blurred background (`UIBlurEffect`, available since iOS 8).
- Track title, artist, album, progress and elapsed/total time.
- Previous, play/pause, next, and seek controls.
- Theos/GitHub Actions package build.

## Important compatibility note

This first version uses `MPMusicPlayerController.systemMusicPlayer` and `MPMediaItem` metadata. It is intended to control and display tracks exposed through Apple's system Music/iPod media player and media library. It does **not** promise to read or control arbitrary third-party apps' global Now Playing state (for example, every version of Spotify or other players). That requires private MediaRemote APIs or a separate integration, which is a distinct compatibility/reliability problem on iOS 8.

The app does not bundle music or bypass Apple Music/DRM. Test with locally synced music available in the system Music app.

## Build

Use a Linux Theos setup with the iPhoneOS 9.3 SDK available under `$THEOS/sdks/iPhoneOS9.3.sdk`.

```sh
make package
```

The package should appear under `packages/`. GitHub Actions builds it and uploads the `.deb` as an artifact.

## Install

Transfer the generated `.deb` to the jailbroken iPad and install with a package manager or:

```sh
dpkg -i com.jzh8y7svw5.ambientmusic_1.0.0-1+debug_iphoneos-arm.deb
```

The exact package filename can vary by Theos version/build settings. Respring is normally not required for an app package; launch AmbientMusic from the Home Screen.

## Notes

- Target: `armv7`, deployment target iOS 8.0; intended test device iPad 4 on iOS 8.4.1.
- SDK used for compilation: iPhoneOS 9.3 SDK.
- This is a starter implementation and should be built and tested on the actual target. UI layout and media-library behavior may need adjustment based on the exact iOS 8.4.1 environment.
