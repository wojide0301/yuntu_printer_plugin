# yuntu_printer_plugin

打印插件

## TSPL 标签打印

`TsplGenerator` 从 `yuntu_printer_plugin.dart` 导出，可生成 TSPL 位图标签指令。
适用于处于 TSPL 模式的芯烨和兼容打印机，不适用于仅支持 CPCL、ZPL 或专有协议的设备。
图像使用打印机原生分辨率：203 DPI 为 8 点/mm，300 DPI 通常为 12 点/mm。

```dart
final data = TsplGenerator.image(
  labelImage, // image 包的 Image，50×30mm、203 DPI 时应为 400×240 像素
  widthMm: 50,
  heightMm: 30,
  gapMm: 2,
  rotation: 0, // 0 或 180
  offsetX: 0, // 点，支持负值，超出标签的内容裁切
  offsetY: 0,
  density: 6, // 0～15，具体效果依机型
  speed: 6, // 英寸/秒，必须使用机型支持的正数
);
await YuntuPrinterPlugin.instance.printData(usbPrinter, data);
// 网口使用 FlutterThermalPrinterNetwork(ip).printTicket(data)，检查返回状态。
```

输出一张标签；位图包含中文，不依赖打印机内置字库。
USB 不注入 ESC/POS 初始化指令；Android 等待实际字节写入并报告错误，Windows 使用 RAW 打印任务。
发送成功表示数据已交给设备或系统队列，不等于设备已实际出纸。

### Windows 7 分支

`win7` 固定使用 Flutter 3.19.6 / Dart 3.3.4 和 `win32: 5.4.0`，不依赖 BLE。
[Flutter 官方维护记录](https://github.com/flutter/flutter/issues/140830#issuecomment-1936397549)
确认 3.19 / Dart 3.3 是最后保留 Win7 支持的版本线，请勿随主分支升级 SDK。
TSPL 使用的 [Windows RAW 打印接口](https://learn.microsoft.com/en-us/windows/win32/printdocs/writeprinter)
支持 Win7；示例程序的 Windows 清单与 Flutter 3.19.6 模板保持一致。

本地验证命令：`fvm flutter pub get`、`fvm flutter test`、
`fvm flutter analyze --no-fatal-infos`（旧代码仍有样式提示）。
测试覆盖 TSPL 位图、参数校验、TCP 字节完整性和 USB 方法通道。
发布前仍需在 Windows 开发机运行 `cd example`、`fvm flutter build windows --release`，
将整个 Release 目录复制到 Win7 机器，验证示例程序启动。
另在安装了打印机驱动、调用上述 TSPL 接口的业务应用中验证 USB/网口标签出纸、
旋转/偏移、连续打印以及断线错误提示。
macOS 上的自动化测试不代表 Win7 真机验收通过。

## Getting Started

This project is a starting point for a Flutter
[plug-in package](https://flutter.dev/to/develop-plugins),
a specialized package that includes platform-specific implementation code for
Android and/or iOS.

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

