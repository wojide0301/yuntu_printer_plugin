package com.yuntu.printer.plugin.yuntu_printer_plugin;

import android.hardware.usb.UsbConstants;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbDeviceConnection;
import android.hardware.usb.UsbEndpoint;
import android.hardware.usb.UsbInterface;
import android.hardware.usb.UsbManager;
import android.util.Log;
import android.os.Handler;
import android.os.Looper;
import io.flutter.plugin.common.MethodChannel.Result;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

public class UsbConnectionManager {
    private static final String TAG = "UsbConnectionManager";
    private static final long CONNECTION_TIMEOUT_MS = 50000; // 50秒连接超时
    private static final int MAX_CHUNK_SIZE = 4096; // 增大块大小
    private static final int MAX_QUEUE_SIZE = 100; // 新增：最大队列长度
    
    private final UsbManager usbManager;
    private final UsbPermissionManager permissionManager;
    private final Map<String, PrinterConnection> connectionPool;
    private final ExecutorService printExecutor;
    private final ScheduledExecutorService cleanupExecutor;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    
    public UsbConnectionManager(UsbManager usbManager, UsbPermissionManager permissionManager) {
        this.usbManager = usbManager;
        this.permissionManager = permissionManager;
        this.connectionPool = new ConcurrentHashMap<>();
        
        // 创建有界队列的线程池
        this.printExecutor = new ThreadPoolExecutor(
                3, // 核心线程数
                3, // 最大线程数
                60L, TimeUnit.SECONDS, // 空闲线程存活时间
                new LinkedBlockingQueue<Runnable>(MAX_QUEUE_SIZE), // 有界队列
                new ThreadPoolExecutor.AbortPolicy()
        );
        
        this.cleanupExecutor = Executors.newSingleThreadScheduledExecutor();
    }
    
    /**
     * 打印机连接信息类
     */
    public static class PrinterConnection {
        UsbDeviceConnection connection;
        UsbInterface usbInterface;
        UsbEndpoint bulkEndpoint;
        volatile long lastUsed;
        volatile boolean isValid;
        final String deviceKey;
        
        PrinterConnection(String deviceKey) {
            this.deviceKey = deviceKey;
            this.lastUsed = System.currentTimeMillis();
            this.isValid = false;
        }
    }
    
    /**
     * 启动连接清理任务
     */
    public void startConnectionCleanupTask() {
        cleanupExecutor.scheduleWithFixedDelay(() -> {
            try {
                cleanupIdleConnections();
            } catch (Exception e) {
                Log.e(TAG, "Error in connection cleanup task: " + e.getMessage());
            }
        }, 1, 1, TimeUnit.MINUTES); // 每分钟检查一次
    }
    
    /**
     * 清理空闲连接
     */
    private void cleanupIdleConnections() {
        long now = System.currentTimeMillis();
        List<String> toRemove = new ArrayList<>();
        
        for (Map.Entry<String, PrinterConnection> entry : connectionPool.entrySet()) {
            PrinterConnection conn = entry.getValue();
            if (now - conn.lastUsed > CONNECTION_TIMEOUT_MS) {
                toRemove.add(entry.getKey());
            }
        }
        
        for (String key : toRemove) {
            Log.d(TAG, "Cleaning up idle connection: " + key);
            closeConnection(key);
        }
    }
    
    /**
     * 清理所有连接
     */
    public void cleanupAllConnections() {
        for (String key : connectionPool.keySet()) {
            closeConnection(key);
        }
        connectionPool.clear();
    }
    
    /**
     * 关闭设备连接
     */
    public void closeConnection(UsbDevice device) {
        closeConnection(permissionManager.getDeviceKey(device));
    }
    
    /**
     * 关闭指定key的连接
     */
    public void closeConnection(String deviceKey) {
        PrinterConnection conn = connectionPool.remove(deviceKey);
        closeConnection(conn);
    }
    
    /**
     * 关闭连接对象
     */
    public void closeConnection(PrinterConnection conn) {
        if (conn != null) {
            synchronized (conn) {
                conn.isValid = false;
                try {
                    if (conn.connection != null) {
                        if (conn.usbInterface != null) {
                            conn.connection.releaseInterface(conn.usbInterface);
                        }
                        conn.connection.close();
                    }
                    Log.d(TAG, "USB connection closed: " + (conn.deviceKey != null ? conn.deviceKey : "unknown"));
                } catch (Exception e) {
                    Log.e(TAG, "Error closing USB connection: " + e.getMessage());
                }
            }
        }
    }
    
    /**
     * 获取或创建连接
     */
    public synchronized PrinterConnection getOrCreateConnection(UsbDevice device) {
        String deviceKey = permissionManager.getDeviceKey(device);
        PrinterConnection conn = connectionPool.get(deviceKey);
        
        if (conn != null) {
            // 检查连接是否仍然有效
            if (isConnectionValid(conn)) {
                conn.lastUsed = System.currentTimeMillis();
                return conn;
            } else {
                // 连接无效，关闭并重新创建
                Log.d(TAG, "Connection invalid, recreating: " + deviceKey);
                closeConnection(deviceKey);
            }
        }
        
        // 创建新连接
        conn = createNewConnection(device);
        if (conn != null) {
            connectionPool.put(deviceKey, conn);
        }
        
        return conn;
    }
    
    /**
     * 创建新连接
     */
    private PrinterConnection createNewConnection(UsbDevice device) {
        PrinterConnection conn = new PrinterConnection(permissionManager.getDeviceKey(device));
        
        try {
            conn.connection = usbManager.openDevice(device);
            if (conn.connection == null) {
                Log.e(TAG, "Failed to open USB device");
                return null;
            }
            
            for (int i = 0; i < device.getInterfaceCount(); i++) {
                UsbInterface candidate = device.getInterface(i);
                if (candidate.getInterfaceClass() == UsbConstants.USB_CLASS_PRINTER &&
                    findBulkEndpoint(candidate) != null) {
                    conn.usbInterface = candidate;
                    break;
                }
            }
            if (conn.usbInterface == null) {
                conn.connection.close();
                return null;
            }
            if (!conn.connection.claimInterface(conn.usbInterface, true)) {
                Log.e(TAG, "Failed to claim USB interface");
                conn.connection.close();
                return null;
            }
            
            // 查找批量输出端点
            conn.bulkEndpoint = findBulkEndpoint(conn.usbInterface);
            if (conn.bulkEndpoint == null) {
                Log.e(TAG, "No bulk endpoint found");
                conn.connection.releaseInterface(conn.usbInterface);
                conn.connection.close();
                return null;
            }
            
            conn.isValid = true;
            conn.lastUsed = System.currentTimeMillis();
            Log.d(TAG, "Successfully created new USB connection: " + conn.deviceKey);
            
        } catch (Exception e) {
            Log.e(TAG, "Error creating USB connection: " + e.getMessage());
            closeConnection(conn);
            return null;
        }
        
        return conn;
    }
    
    /**
     * 查找批量输出端点
     */
    private UsbEndpoint findBulkEndpoint(UsbInterface usbInterface) {
        for (int i = 0; i < usbInterface.getEndpointCount(); i++) {
            UsbEndpoint endpoint = usbInterface.getEndpoint(i);
            if (endpoint.getType() == UsbConstants.USB_ENDPOINT_XFER_BULK &&
                    endpoint.getDirection() == UsbConstants.USB_DIR_OUT) {
                return endpoint;
            }
        }
        return null;
    }
    
    /**
     * 检查连接有效性
     */
    private boolean isConnectionValid(PrinterConnection conn) {
        // 原始字节通道不能额外注入 ESC/POS 指令，实际写入失败时再标记连接失效。
        return conn != null && conn.isValid && conn.connection != null;
    }
    
    /**
     * 优化的打印执行方法 - 添加队列满异常处理
     */
    public void submitPrintExecutor(UsbDevice device, List<List<Integer>> batches, Result result) {
        try {
            printExecutor.submit(() -> {
                PrinterConnection conn = getOrCreateConnection(device);
                if (conn == null || !conn.isValid) {
                    mainHandler.post(() -> result.error("USB_CONNECT_FAILED", "Failed to establish printer connection", null));
                    return;
                }
                
                try {
                    long startTime = System.currentTimeMillis();
                    int totalBytes = 0;
                    
                    synchronized (conn) {
                        if (!conn.isValid) throw new IllegalStateException("USB connection is closed");
                        for (List<Integer> batch : batches) {
                            byte[] data = convertToByteArray(batch);
                            int offset = 0;
                            while (offset < data.length) {
                                int written = conn.connection.bulkTransfer(conn.bulkEndpoint, data, offset, data.length - offset, 5000);
                                if (written <= 0) {
                                    throw new IllegalStateException("USB bulk transfer failed: " + written);
                                }
                                offset += written;
                                totalBytes += written;
                            }
                        }
                        conn.lastUsed = System.currentTimeMillis();
                    }
                    
                    long endTime = System.currentTimeMillis();
                    Log.d(TAG, "Print completed: " + totalBytes + " bytes in " + (endTime - startTime) + "ms");
                    mainHandler.post(() -> result.success(true));
                    
                } catch (Exception e) {
                    Log.e(TAG, "Error printing: " + e.getMessage());
                    conn.isValid = false; // 出错时标记连接无效
                    mainHandler.post(() -> result.error("USB_PRINT_FAILED", e.getMessage(), null));
                }
            });
        } catch (Exception e) {
            Log.w(TAG, "Print task rejected, queue is full: " + e.getMessage());
            mainHandler.post(() -> result.error("USB_QUEUE_FULL", e.getMessage(), null));
        }
    }
    
    /**
     * 转换整数列表到字节数组
     */
    private byte[] convertToByteArray(List<Integer> integerList) {
        byte[] data = new byte[integerList.size()];
        for (int i = 0; i < integerList.size(); i++) {
            data[i] = integerList.get(i).byteValue();
        }
        return data;
    }
    
    /**
     * 获取最大块大小
     */
    public static int getMaxChunkSize() {
        return MAX_CHUNK_SIZE;
    }
    
    /**
     * 获取连接池大小
     */
    public int getConnectionPoolSize() {
        return connectionPool.size();
    }
    
    /**
     * 关闭资源
     */
    public void shutdown() {
        cleanupAllConnections();
        if (printExecutor != null && !printExecutor.isShutdown()) {
            printExecutor.shutdown();
        }
        if (cleanupExecutor != null && !cleanupExecutor.isShutdown()) {
            cleanupExecutor.shutdown();
        }
    }
}
