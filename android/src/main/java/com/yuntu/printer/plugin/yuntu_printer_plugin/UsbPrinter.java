package com.yuntu.printer.plugin.yuntu_printer_plugin;

import static android.content.Context.USB_SERVICE;

import android.annotation.SuppressLint;
import android.content.Context;
import android.content.Intent;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbManager;
import android.os.Build;
import io.flutter.plugin.common.EventChannel;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

import android.content.BroadcastReceiver;
import android.content.IntentFilter;
import android.util.Log;

public class UsbPrinter implements EventChannel.StreamHandler {
    @SuppressLint("StaticFieldLeak")
    private static Context context;

    private static final String ACTION_USB_ATTACHED = "android.hardware.usb.action.USB_DEVICE_ATTACHED";
    private static final String ACTION_USB_DETACHED = "android.hardware.usb.action.USB_DEVICE_DETACHED";
    private static final String TAG = "FPP";

    private EventChannel.EventSink events;
    private BroadcastReceiver usbStateChangeReceiver;
    private final UsbPermissionManager permissionManager;
    private final UsbDeviceValidator deviceValidator;
    private final UsbConnectionManager connectionManager;
    private UsbManager m;

    public UsbPrinter(Context context) {
        UsbPrinter.context = context;
        this.permissionManager = new UsbPermissionManager(context);
        this.deviceValidator = new UsbDeviceValidator();
        m = (UsbManager) context.getSystemService(USB_SERVICE);
        this.connectionManager = new UsbConnectionManager(m, permissionManager);
    }


    //是否正在进行单个设备的连接
    boolean isConnectingDevice = false;

    private void createUsbStateChangeReceiver() {
        usbStateChangeReceiver =  new BroadcastReceiver() {
            @SuppressLint("LongLogTag")
            @Override
            public void onReceive(Context context, Intent intent) {
                String action = intent.getAction();
                Log.d(TAG, "onReceive: " + action);
                if (Objects.equals(intent.getAction(), ACTION_USB_ATTACHED)) {
                    UsbDevice device = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE);
                    Log.d(TAG, "ACTION_USB_ATTACHED");
                    sendDevice(device,false);
                    permissionManager.deviceRequestPermission(device);
                } else if (Objects.equals(intent.getAction(), ACTION_USB_DETACHED)) {
                    UsbDevice device = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE);
                    Log.d(TAG, "ACTION_USB_DETACHED");
                    if (device != null) {
                        connectionManager.closeConnection(device);
                    }
                    sendDevice(device,true);
                }
                Log.d(TAG, "ACTION_USB_PERMISSION " + (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)));
                if (Objects.equals(intent.getAction(), UsbPermissionManager.getPermissionAction())) {
                    synchronized (this) {
                        String vendorId = intent.getStringExtra("vendor_id");
                        String productId = intent.getStringExtra("product_id");
                        String deviceName = intent.getStringExtra("device_name");
                        UsbDevice device = permissionManager.findUsbDevice(vendorId, productId, deviceName);
                        permissionManager.incrementPermissionRequestCount(device);
                        if(isConnectingDevice){
                            isConnectingDevice = false;
                        }else{
                            permissionManager.requestPermission();
                        }
                        sendDevice(device, false);
                    }
                }
            }
        };
    }

    @SuppressLint("UnspecifiedRegisterReceiverFlag")
    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        this.events = events;
        IntentFilter filter = new IntentFilter();
        filter.addAction(ACTION_USB_ATTACHED);
        filter.addAction(ACTION_USB_DETACHED);
        filter.addAction(UsbPermissionManager.getPermissionAction());
        createUsbStateChangeReceiver();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(usbStateChangeReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            context.registerReceiver(usbStateChangeReceiver, filter);
        }
        // 启动连接清理任务
        connectionManager.startConnectionCleanupTask();
    }

    @Override
    public void onCancel(Object arguments) {
        if (events != null) {
            context.unregisterReceiver(usbStateChangeReceiver);
            // 关闭所有连接
            connectionManager.cleanupAllConnections();
            events = null;
        }
    }
    

    private void sendDevice(UsbDevice device,boolean detached ) {
        if (device == null) {
            Log.d(TAG, "Device is not a printer.");
            return;
        }
        HashMap<String, Object> deviceData = createDeviceData(device);
        if (detached) deviceData.put("detached", true);
        Log.d(TAG, "Sending device data: " + deviceData);
        if (events != null) events.success(deviceData);
    }

    private boolean isUsbPrinter(UsbDevice device) {
        return deviceValidator.isUsbPrinter(device);
    }

    private HashMap<String, Object> createDeviceData(UsbDevice device) {
        HashMap<String, Object> deviceData = new HashMap<>();
        deviceData.put("name", device.getProductName());
        try {
            deviceData.put("serialNumber", String.valueOf(device.getSerialNumber()));
        } catch (SecurityException e) {
            deviceData.put("serialNumber", null);
        }
        deviceData.put("deviceId", String.valueOf(device.getDeviceId()));
        deviceData.put("deviceName", device.getDeviceName());
        deviceData.put("vendorId", String.valueOf(device.getVendorId()));
        deviceData.put("productId", String.valueOf(device.getProductId()));
        deviceData.put("connected",isConnectedByUsbPrinter(device));
        deviceData.put("manufacturer", device.getManufacturerName());
        return deviceData;
    }


    public boolean isConnectedByUsbPrinter(UsbDevice device) {
        return permissionManager.isDeviceHasPermission(device);
    }


    public List<Map<String, Object>> getUsbDevicesList() {
        HashMap<String, UsbDevice> usbDevices = m.getDeviceList();
        List<Map<String, Object>> data = new ArrayList<Map<String, Object>>();
        for (Map.Entry<String, UsbDevice> entry : usbDevices.entrySet()) {
            UsbDevice device = entry.getValue();
            if (isUsbPrinter(device)) {
                data.add(createDeviceData(device));
            }
        }
        permissionManager.clearPermissionRequestCounts();
        permissionManager.requestPermission();
        return data;
    }

    //    Connect using VendorId and ProductId
    public void connect(String vendorId, String productId,String deviceName) {
        isConnectingDevice = true;
        UsbDevice device = permissionManager.findUsbDevice(vendorId, productId, deviceName);
        if (device == null) {
            Log.d(TAG, "Device not found.");
            return;
        }
        permissionManager.updatePermissionRequestCount(device, 0);
        if (permissionManager.isDeviceHasPermission(device)) {
            Log.d(TAG, "Device already has permission.");
            return;
        }
        permissionManager.deviceRequestPermission(device);
    }

    public UsbDevice findUsbDeviceBySerial(String serialNumber){
        return permissionManager.findUsbDeviceBySerial(serialNumber);
    }

    //    Print text on the printer
    public void printText(String serialNumber, List<Integer> bytes) {
        UsbDevice printerDevice = findUsbDeviceBySerial(serialNumber);
        if(printerDevice == null){
            Log.e(TAG, "Printer device not found for serial: " + serialNumber);
            return;
        }

        // 使用更大的块大小
        List<List<Integer>> batches = new ArrayList<>();
        for (int i = 0; i < bytes.size(); i += UsbConnectionManager.getMaxChunkSize()) {
            int end = Math.min(bytes.size(), i + UsbConnectionManager.getMaxChunkSize());
            batches.add(bytes.subList(i, end));
        }
        connectionManager.submitPrintExecutor(printerDevice, batches);
    }

    
    public boolean isConnected(String vendorId, String productId,String deviceName) {
        HashMap<String, UsbDevice> usbDevices = m.getDeviceList();
        UsbDevice device = null;
        for (Map.Entry<String, UsbDevice> entry : usbDevices.entrySet()) {
            if (isSameDevice(entry.getValue(), permissionManager.findUsbDevice(vendorId, productId, deviceName))) {
                device = entry.getValue();
                break;
            }
        }
        if (device == null) {
            return false;
        }
        return permissionManager.isDeviceHasPermission(device);
    }

    

    public boolean disconnect(String vendorId, String productId,String serialNumber) {
        HashMap<String, UsbDevice> usbDevices = m.getDeviceList();
        UsbDevice device = null;
        for (Map.Entry<String, UsbDevice> entry : usbDevices.entrySet()) {
            if (isSameDevice(entry.getValue(), permissionManager.findUsbDevice(vendorId, productId, serialNumber))) {
                device = entry.getValue();
                break;
            }
        }
        if (device == null) {
            return false;
        }

        // 从连接池中移除并关闭连接
        connectionManager.closeConnection(device);

        HashMap<String, Object> deviceData = createDeviceData(device);
        Log.d(TAG, "Sending device data: " + deviceData);
        if (events != null) events.success(deviceData);
        return true;
    }

    // 判断两个设备是否相同
    public boolean isSameDevice(UsbDevice device1, UsbDevice device2) {
        if (device1 == null || device2 == null) {
            return false;
        }
        
        return device1.getVendorId() == device2.getVendorId() &&
               device1.getProductId() == device2.getProductId() &&
               device1.getDeviceName().equals(device2.getDeviceName());
    }

}
