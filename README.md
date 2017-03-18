# Kryptonite
__Kryptonite__ generates and stores an SSH key pair on a mobile phone. The
Kryptonite app is paired with one or more workstations by scanning a QR code
presented in the terminal. When using SSH from a paired workstation, the
workstation requests a private key signature from the phone. The user then
receives a notification and chooses whether to allow the SSH login. For more
information, check out [krypt.co](https://krypt.co).

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
