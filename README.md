<a href="https://krypt.co"><img src="https://krypt.co/static/dist/img/apple-touch-icon.png" width="400"/> </a>
[![Build Status](https://travis-ci.org/kryptco/kryptonite-ios.svg?branch=master)](https://travis-ci.org/kryptco/kryptonite-ios)

__Krypton__ generates and stores an SSH key pair on a mobile phone. The
Krypton app is paired with one or more workstations by scanning a QR code
presented in the terminal. When using SSH from a paired workstation, the
workstation requests a private key signature from the phone. The user then
receives a notification and chooses whether to allow the SSH login. 

For more information, check out [krypt.co](https://krypt.co).


# Build Instructions
- Install dependencies (OSX)
  ```sh 
  curl https://sh.rustup.rs -sSf | sh
  rustup target add aarch64-apple-ios
  rustup target add armv7-apple-ios
  rustup target add armv7s-apple-ios
  rustup target add x86_64-apple-ios
  rustup target add i386-apple-ios
  rustup update
  cargo install cargo-lipo

  cd ssh-wire
  ./build.sh
  ```

# Have an Android phone?
The Android implementation is located [here](https://github.com/kryptco/kryptonite-android).

# Workstation SSH Integration
To use an SSH key stored in Krypton, install __kr__
```sh
curl https://krypt.co/kr | sh
```
or build it [from source](https://github.com/kryptco/kr).

# Security Disclosure Policy
__krypt.co__ follows a 7-day disclosure policy. If you find a security flaw,
please send it to `disclose@krypt.co` encrypted to the PGP key with fingerprint
`B873685251A928262210E094A70D71BE0646732C` (full key below). We ask that you
delay publication of the flaw until we have published a fix, or seven days have
passed.

```
disclose@krypt.co
-----BEGIN PGP PUBLIC KEY BLOCK-----

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
=e0wj
-----END PGP PUBLIC KEY BLOCK-----
```

# LICENSE
We are currently working on a new license for Krypton. For now, the code
is released under All Rights Reserved.
