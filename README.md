[![Build Status](https://travis-ci.org/kryptco/krypton-ios.svg?branch=master)](https://travis-ci.org/kryptco/krypton-ios)

<div style="text-align:center">
    <a href="https://krypt.co"><img src="https://krypt.co/static/dist/img/krypton_core_logo.svg" width="150"/> </a>
</div>


__Krypton__  turns your iOS device into a WebAuthn/U2F Authenticator: strong, unphishable 2FA. 

Krypton implements the standardized FIDO Universal 2nd Factor (U2F) protocol to provide secure, unphishable two-factor authentication on the web, now in the convenient form factor that is your phone.

- No more mistyping, missing 30 second windows, or waiting endlessly for that SMS.
- Instant Sign-in: Krypton securely pairs with your computer so that you don't have to touch your phone for each sign-in. Optionally, enable One tap sign-ins for enhanced security.
- Stops Phishing: SMS and authenticator app codes can easily be phished. Don't let that happen to you. Krypton protects you from phishing.
- Works with the sites you love: Google, Facebook, Twitter, Dropbox, GitHub and [many more](https://krypt.co/start/?noredirect=true).
- Quickly protect your accounts: Setting up two-factor can be time consuming and repetitive. Just scan once with Krypton.

 Install our companion browser extension at: https://krypt.co/start.


## Krypton for Developers
Krypton supports developer mode so you can use Krypton as a security key for SSH and PGP private keys in addition to U2F.

Download our command line utility `curl https://krypt.co/kr | sh` and type `kr pair` to securely pair Krypton with your computer. Krypton integrates with the `ssh` command to send signature requests right to your phone. Krypton also makes signing Git commits and tags with PGP easy: run `kr codesign` to get started.

## Zero trust infrastructure 

Krypton is built on top of an end-to-end verified and encrypted architecture. This means zero trust. We, Krypt.co, have zero information about keys or where you're authenticating. The keys only live in the Krypton app on your phone.

Learn more about [Krypton's security architecture](https://krypt.co/blog/posts/krypton-our-zero-trust-infrastructure.html).
For more information, check out [krypt.co](https://krypt.co).


## Build Krypton
*Instructions below only work for macOS*

1. rust
```sh
curl https://sh.rustup.rs -sSf | sh
rustup target add aarch64-apple-ios
rustup target add armv7-apple-ios
rustup target add armv7s-apple-ios
rustup target add x86_64-apple-ios
rustup target add i386-apple-ios
rustup update
cargo install cargo-lipo
```

2. libtool, autoconf, automake:
```sh
brew install libtool
brew install autoconf
brew install automake
```

## Have an Android phone?
The Android implementation is located [here](https://github.com/kryptco/kryptonite-android).


## Security Disclosure Policy
__krypt.co__ follows a 7-day disclosure policy. If you find a security flaw,
please send it to `disclose@krypt.co` encrypted to the PGP key with fingerprint
`B873685251A928262210E094A70D71BE0646732C` ([grab the full key here](https://krypt.co/docs/security/disclosure-policy.html)). We ask that you
delay publication of the flaw until we have published a fix, or seven days have
passed. 

## LICENSE
We are currently working on a new license for Krypton. For now, the code
is released under All Rights Reserved.

