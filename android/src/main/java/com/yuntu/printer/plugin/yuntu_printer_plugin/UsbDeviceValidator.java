package com.yuntu.printer.plugin.yuntu_printer_plugin;

import android.hardware.usb.UsbConstants;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbManager;

public class UsbDeviceValidator {
    
    /**
     * 检查设备是否为USB打印机
     */
    public boolean isUsbPrinter(UsbDevice device) {
        if (device == null) {
            return false;
        }
        
        return device.getInterface(0).getInterfaceClass() == UsbConstants.USB_CLASS_PRINTER;
    }
    
    /**
     * 检查设备是否已连接（有权限）
     */
    public boolean isConnected(UsbDevice device, UsbManager usbManager) {
        if (device == null || usbManager == null) {
            return false;
        }
        
        return usbManager.hasPermission(device);
    }
}
