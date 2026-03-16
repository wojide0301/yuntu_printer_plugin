package com.yuntu.printer.plugin.yuntu_printer_plugin;

import android.content.Context;

import androidx.annotation.NonNull;

import java.util.List;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.EventChannel;


/** YuntuPrinterPlugin */
public class YuntuPrinterPlugin implements FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private MethodChannel channel;

  private EventChannel eventChannel;
  private Context context;
  private UsbPrinter usbPrinter;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "yuntu_printer_plugin");
    eventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), "yuntu_printer_plugin/events");
    channel.setMethodCallHandler(this);
    context = flutterPluginBinding.getApplicationContext();
    usbPrinter = new UsbPrinter(context);
    eventChannel.setStreamHandler(usbPrinter);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {
      case "getPlatformVersion":
        result.success("Android " + android.os.Build.VERSION.RELEASE);
        break;
      case "getUsbDevicesList":
        result.success(usbPrinter.getUsbDevicesList());
        break;
      case "connect": {
        String vendorId = call.argument("vendorId");
        String productId = call.argument("productId");
        String deviceName = call.argument("deviceName");
        usbPrinter.connect(vendorId, productId,deviceName);
        result.success(false);
        break;
      }
      case "disconnect": {
        String vendorId = call.argument("vendorId");
        String productId = call.argument("productId");
        String deviceName = call.argument("deviceName");
        result.success(usbPrinter.disconnect(vendorId, productId,deviceName));
        break;
      }
      case "printText": {
        String serialNumber = call.argument("serialNumber");
        List<Integer> data = call.argument("data");
        usbPrinter.printText(serialNumber, data);
        result.success(true);
        break;
      }
      case "isConnected": {
        String vendorId = call.argument("vendorId");
        String productId = call.argument("productId");
        String deviceName = call.argument("deviceName");
        result.success(usbPrinter.isConnected(vendorId, productId,deviceName));
        break;
      }
      default:
        result.notImplemented();
        break;
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }
}
