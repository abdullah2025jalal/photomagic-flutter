/// Native (Android/iOS/Python-desktop) stubs — the install rectangle is a
/// browser concern only, so every check resolves to "already fine here".
library;

const bool pmIsWebBrowser = false;

bool pmStandalone() => false;

bool pmInstalled() => false;

bool pmInstallAvailable() => false;

bool pmIsSecureContext() => true;

bool pmIsOnline() => true;

bool pmPromptInstall() => false;

bool pmIsIos() => false;
