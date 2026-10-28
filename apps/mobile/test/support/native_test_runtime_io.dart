import 'dart:ffi';
import 'dart:io';

void initializeNativeTestRuntime() {
  // The package probes a Windows debug DLL first, which needs the debug CRT.
  // Preload the existing release build for direct test runs without changing
  // the machine PATH, the package cache, the app or its animation assets.
  if (!Platform.isWindows) {
    return;
  }
  final library = File(
    'build/rive_native/native/build/windows/bin/lib/release/rive_native.dll',
  );
  if (library.existsSync()) {
    DynamicLibrary.open(library.absolute.path);
  }
}
