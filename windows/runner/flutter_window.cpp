#include "flutter_window.h"

#include <dwmapi.h>
#include <flutter/standard_method_codec.h>

#include <cstdint>
#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

std::optional<int64_t> GetWindowsAccentColor() {
  DWORD abgr = 0;
  DWORD value_size = sizeof(abgr);
  if (RegGetValueW(
          HKEY_CURRENT_USER,
          L"Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Accent",
          L"AccentColorMenu", RRF_RT_REG_DWORD, nullptr, &abgr,
          &value_size) == ERROR_SUCCESS) {
    const DWORD argb = (abgr & 0xFF00FF00) | ((abgr & 0xFF) << 16) |
                       ((abgr & 0xFF0000) >> 16);
    return static_cast<int64_t>(argb);
  }

  DWORD argb = 0;
  BOOL opaque = FALSE;
  if (SUCCEEDED(DwmGetColorizationColor(&argb, &opaque))) {
    return static_cast<int64_t>(argb);
  }
  return std::nullopt;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  dynamic_color_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "pve_manager/dynamic_color",
          &flutter::StandardMethodCodec::GetInstance());
  dynamic_color_channel_->SetMethodCallHandler(
      [](const auto& call, auto result) {
        if (call.method_name() != "getAccentColor") {
          result->NotImplemented();
          return;
        }
        const auto accent = GetWindowsAccentColor();
        if (accent.has_value()) {
          result->Success(flutter::EncodableValue(accent.value()));
        } else {
          result->Success(flutter::EncodableValue());
        }
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  dynamic_color_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
