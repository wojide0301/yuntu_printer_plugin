package com.yuntu.printer.plugin.yuntu_printer_plugin;

import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbManager;
import android.util.Log;

import java.util.HashMap;
import java.util.Map;
import java.util.Objects;

public class UsbPermissionManager {
    private static final String TAG = "UsbPermissionManager";
    private static final String ACTION_USB_PERMISSION = "com.yuntu.printer.plugin.yuntu_printer_plugin.USB_PERMISSION";
    private static final int MAX_REQUEST_PERMISSION_COUNT = 1;
    
    private final Context context;
    private final UsbManager usbManager;
    private final Map<String, Integer> devicePermissionRequestCounts;
    private final UsbDeviceValidator deviceValidator;
    
    public UsbPermissionManager(Context context) {
        this.context = context;
        this.usbManager = (UsbManager) context.getSystemService(Context.USB_SERVICE);
        this.devicePermissionRequestCounts = new HashMap<>();
        this.deviceValidator = new UsbDeviceValidator();
    }
    
    /**
     * 请求所有未授权的打印机设备权限
     */
    public void requestPermission() {
        HashMap<String, UsbDevice> usbDevices = usbManager.getDeviceList();
        for (Map.Entry<String, UsbDevice> entry : usbDevices.entrySet()) {
            UsbDevice device = entry.getValue();
            if (usbManager.hasPermission(device) || !deviceValidator.isUsbPrinter(device)) {
                continue;
            }
            if (!usbManager.hasPermission(device)) {
                deviceRequestPermission(device);
                break;
            }
        }
    }
    
    /**
     * 请求特定设备的权限
     */
    public void deviceRequestPermission(UsbDevice device) {
        if (!deviceValidator.isUsbPrinter(device)) {
            return;
        }
        
        int permissionRequestCount = getPermissionRequestCount(device);
        Log.d(TAG, "Device permission request count: " + permissionRequestCount);
        
        if (permissionRequestCount < MAX_REQUEST_PERMISSION_COUNT) {
            // 创建包含设备信息的 Intent
            Intent permissionIntent = new Intent(ACTION_USB_PERMISSION);
            String vendorId = String.valueOf(device.getVendorId());
            String productId = String.valueOf(device.getProductId());
            String deviceName = device.getDeviceName();
            
            permissionIntent.putExtra("vendor_id", vendorId);
            permissionIntent.putExtra("product_id", productId);
            permissionIntent.putExtra("device_name", deviceName);
            
            int requestCode = Objects.hash(vendorId, productId, deviceName);
            PendingIntent pendingIntent = PendingIntent.getBroadcast(
                    context,
                    requestCode,
                    permissionIntent,
                    PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
            );
            
            usbManager.requestPermission(device, pendingIntent);
        } else {
            updatePermissionRequestCount(device, 0);
        }
    }
    
    /**
     * 根据 vendorId, productId, deviceName 查找设备
     */
    public UsbDevice findUsbDevice(String vendorId, String productId, String deviceName) {
        HashMap<String, UsbDevice> usbDevices = usbManager.getDeviceList();
        for (Map.Entry<String, UsbDevice> entry : usbDevices.entrySet()) {
            UsbDevice device = entry.getValue();
            if (String.valueOf(device.getVendorId()).equals(vendorId) && 
                String.valueOf(device.getProductId()).equals(productId) && 
                device.getDeviceName().equals(deviceName)) {
                return device;
            }
        }
        return null;
    }
    
    /**
     * 根据序列号查找设备
     */
    public UsbDevice findUsbDeviceBySerial(String serialNumber) {
        try {
            HashMap<String, UsbDevice> usbDevices = usbManager.getDeviceList();
            for (Map.Entry<String, UsbDevice> entry : usbDevices.entrySet()) {
                UsbDevice device = entry.getValue();
                if (deviceValidator.isUsbPrinter(device) && 
                    usbManager.hasPermission(device) && 
                    serialNumber.equals(device.getSerialNumber())) {
                    return device;
                }
            }
            return null;
        } catch (SecurityException e) {
            Log.e(TAG, "SecurityException: " + e.getMessage());
            return null;
        }
    }
    
    /**
     * 检查设备是否有权限
     */
    public boolean isDeviceHasPermission(UsbDevice device) {
        return usbManager.hasPermission(device);
    }
    
    /**
     * 获取设备请求权限次数
     */
    public int getPermissionRequestCount(UsbDevice device) {
        String key = getDeviceKey(device);
        return devicePermissionRequestCounts.containsKey(key) ? 
               devicePermissionRequestCounts.get(key) : 0;
    }
    
    /**
     * 增加设备请求权限次数
     */
    public void incrementPermissionRequestCount(UsbDevice device) {
        String key = getDeviceKey(device);
        int count = devicePermissionRequestCounts.containsKey(key) ? 
                   devicePermissionRequestCounts.get(key) : 0;
        devicePermissionRequestCounts.put(key, count + 1);
    }
    
    /**
     * 更新设备请求权限次数
     */
    public void updatePermissionRequestCount(UsbDevice device, int count) {
        String key = getDeviceKey(device);
        devicePermissionRequestCounts.put(key, count);
    }
    
    /**
     * 清空所有权限请求计数
     */
    public void clearPermissionRequestCounts() {
        devicePermissionRequestCounts.clear();
    }
    
    /**
     * 获取设备唯一标识符
     */
    public String getDeviceKey(UsbDevice device) {
        return device.getVendorId() + ":" + device.getProductId() + ":" + device.getDeviceName();
    }
    
    /**
     * 获取权限 Action 字符串
     */
    public static String getPermissionAction() {
        return ACTION_USB_PERMISSION;
    }
    
    /**
     * 获取最大请求权限次数
     */
    public static int getMaxRequestPermissionCount() {
        return MAX_REQUEST_PERMISSION_COUNT;
    }
}
