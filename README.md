# MiddleClickMagic

Tool Swift nhỏ cho macOS để biến click vật lý ở vùng giữa Magic Mouse thành middle-click (`mouse button 2`).

## Cách chạy

```sh
swift build
.build/debug/MiddleClickMagic
```

Tool sẽ hiện icon trên thanh menu. Menu chỉ có:

- `Wide area middle click`: vùng nhận middle-click rộng hơn.
- `Run at Login`: tự chạy khi đăng nhập macOS.
- `Quit`: thoát app.

Lần chạy đầu macOS sẽ hỏi quyền Accessibility. Cấp quyền cho binary/Terminal trong:

`System Settings -> Privacy & Security -> Accessibility`

Sau khi cấp quyền, chạy lại:

```sh
.build/debug/MiddleClickMagic
```

Sau khi chạy, có thể đóng terminal bằng cách thoát tool từ menu icon -> `Quit`.

## Tạo bản build `.app`

```sh
scripts/build_app.sh
open dist/MiddleClickMagic.app
```

Script ưu tiên ký app bằng Apple Development certificate có sẵn trên máy. Việc này giúp quyền Accessibility ổn định hơn giữa các lần build. Nếu vừa đổi từ bản ad-hoc cũ sang bản signed mới, hãy cấp lại quyền cho `dist/MiddleClickMagic.app` trong `System Settings -> Privacy & Security -> Accessibility`.

Build output:

- `dist/MiddleClickMagic.app`
- `dist/MiddleClickMagic.zip`

Icon source:

- `Assets/AppIcon.png`
- `Assets/AppIcon.icns`

## Cách dùng

Đặt ngón tay ở vùng giữa bề ngang của Magic Mouse rồi bấm click vật lý. Tool sẽ chuyển click đó thành middle-click. Các click lệch trái/phải vẫn đi qua như bình thường.

Tùy chọn hữu ích:

```sh
.build/debug/MiddleClickMagic --wide-area
.build/debug/MiddleClickMagic --center-width 0.30
.build/debug/MiddleClickMagic --include-built-in
```

`--center-width` tăng/giảm vùng nhận middle-click. Mặc định là `0.24`; `--wide-area` dùng `0.38`. Nếu đã copy app sang thư mục khác, thoát bản cũ trước khi chạy bản build mới.

## Chạy khi khởi động máy

Bật từ menu icon -> `Run at Login`, hoặc dùng terminal:

```sh
.build/debug/MiddleClickMagic --install-launch-agent
.build/debug/MiddleClickMagic --launch-agent-status
.build/debug/MiddleClickMagic --uninstall-launch-agent
```

Tool tạo LaunchAgent ở:

`~/Library/LaunchAgents/com.middleclickmagic.agent.plist`

## Lưu ý

macOS không có public API hoàn chỉnh để đọc touch surface của Magic Mouse. Tool này dùng private `MultitouchSupport.framework`, nên có thể bị ảnh hưởng bởi update macOS. Phần inject/chặn mouse event dùng Accessibility event tap của macOS.
