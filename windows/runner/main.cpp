#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"
#include "app_links/app_links_plugin_c_api.h"

#include <string>


void RegisterLinsyProtocol() {
  HKEY protocol_key = nullptr;

  const wchar_t* protocol_path = L"Software\\Classes\\linsy";

  if (RegCreateKeyExW(
          HKEY_CURRENT_USER,
          protocol_path,
          0,
          nullptr,
          0,
          KEY_WRITE,
          nullptr,
          &protocol_key,
          nullptr) != ERROR_SUCCESS) {
    return;
  }

  // Marks "linsy" as a URL protocol.
  const wchar_t* url_protocol_value = L"";

  RegSetValueExW(
      protocol_key,
      L"URL Protocol",
      0,
      REG_SZ,
      reinterpret_cast<const BYTE*>(url_protocol_value),
      static_cast<DWORD>(
          (wcslen(url_protocol_value) + 1) * sizeof(wchar_t)));

  RegCloseKey(protocol_key);

  HKEY command_key = nullptr;

  const wchar_t* command_path =
      L"Software\\Classes\\linsy\\shell\\open\\command";

  if (RegCreateKeyExW(
          HKEY_CURRENT_USER,
          command_path,
          0,
          nullptr,
          0,
          KEY_WRITE,
          nullptr,
          &command_key,
          nullptr) != ERROR_SUCCESS) {
    return;
  }

  wchar_t executable_path[MAX_PATH];

  const DWORD path_length = GetModuleFileNameW(
      nullptr,
      executable_path,
      MAX_PATH);

  if (path_length == 0 || path_length >= MAX_PATH) {
    RegCloseKey(command_key);
    return;
  }

  std::wstring command =
      L"\"" +
      std::wstring(executable_path, path_length) +
      L"\" \"%1\"";

  RegSetValueExW(
      command_key,
      nullptr,
      0,
      REG_SZ,
      reinterpret_cast<const BYTE*>(command.c_str()),
      static_cast<DWORD>(
          (command.size() + 1) * sizeof(wchar_t)));

  RegCloseKey(command_key);
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {

  RegisterLinsyProtocol();

  if (SendAppLinkToInstance()) {
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"linsy", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}